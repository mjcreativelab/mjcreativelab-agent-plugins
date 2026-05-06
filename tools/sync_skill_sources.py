#!/usr/bin/env python3
"""Mirror skill directories from skills-sources/<package>/<skill>/ to distribution targets.

配布先:
- claude: packages/<package>/skills/<skill>/  （package 階層を保持）
- codex:  .codex-plugin/skills/<skill>/       （package を平坦化）

各配布先は source skill ディレクトリの完全ミラー:
- SKILL.md / assets/ / references/ など全ファイルを source から実体コピー
- target に存在し source に無いファイルは削除（orphan 削除）
- skills-sources/ が唯一の正本（packages/<pkg>/skills/<skill>/ の中身は generated）
"""

from __future__ import annotations

import argparse
import filecmp
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCES_DIR = ROOT / "skills-sources"
PACKAGES_DIR = ROOT / "packages"
CODEX_PLUGIN_DIR = ROOT / ".codex-plugin"


def discover_skills() -> list[tuple[str, str]]:
    """skills-sources/<package>/<skill>/SKILL.md を走査して (package, skill) のリストを返す。

    codex 側はフラット配置のため、skill 名がリポジトリ全体で一意であることを検証する。
    """
    if not SOURCES_DIR.is_dir():
        return []
    result: list[tuple[str, str]] = []
    seen: dict[str, str] = {}
    for pkg_dir in sorted(SOURCES_DIR.iterdir()):
        if not pkg_dir.is_dir():
            continue
        for skill_dir in sorted(pkg_dir.iterdir()):
            if not skill_dir.is_dir():
                continue
            if not (skill_dir / "SKILL.md").is_file():
                continue
            name = skill_dir.name
            if name in seen:
                raise SystemExit(
                    f"Duplicate skill name '{name}' in "
                    f"{seen[name]}/ and {pkg_dir.name}/. "
                    f"Skill names must be globally unique (codex flattens packages)."
                )
            seen[name] = pkg_dir.name
            result.append((pkg_dir.name, name))
    return result


def source_dir(package: str, skill: str) -> Path:
    return SOURCES_DIR / package / skill


def target_dirs(package: str, skill: str) -> list[Path]:
    """ミラー先ディレクトリのリスト。.codex-plugin/ が存在する時のみ codex 側を含める。"""
    paths = [PACKAGES_DIR / package / "skills" / skill]
    if CODEX_PLUGIN_DIR.is_dir():
        paths.append(CODEX_PLUGIN_DIR / "skills" / skill)
    return paths


def list_files(root: Path) -> set[Path]:
    """root 配下の通常ファイルを relative path のセットで返す（symlink は無視）。"""
    if not root.is_dir():
        return set()
    return {
        p.relative_to(root)
        for p in root.rglob("*")
        if p.is_file() and not p.is_symlink()
    }


def remove_empty_dirs(root: Path) -> None:
    """root 配下の空ディレクトリを深い順に削除（root 自体は残す）。"""
    if not root.is_dir():
        return
    subs = sorted(
        (p for p in root.rglob("*") if p.is_dir()),
        key=lambda p: len(p.parts),
        reverse=True,
    )
    for sub in subs:
        try:
            sub.rmdir()
        except OSError:
            pass  # 空でないディレクトリはスキップ


def mirror_dir(src: Path, dst: Path, check: bool) -> bool:
    """src の内容を dst に完全ミラーする（orphan 削除あり）。差分があれば True を返す。"""
    src_files = list_files(src)
    dst_files = list_files(dst)
    has_changes = False

    # 1. source → target: 新規・更新ファイルをコピー
    for rel in sorted(src_files):
        sf = src / rel
        df = dst / rel
        if df.is_symlink():
            raise SystemExit(f"Refusing to write symlink target: {df.relative_to(ROOT)}")
        differs = not df.is_file() or not filecmp.cmp(sf, df, shallow=False)
        if differs:
            has_changes = True
            if check:
                print(f"OUTDATED {df.relative_to(ROOT)}")
                continue
            df.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(sf, df)
            print(f"COPIED   {df.relative_to(ROOT)}")
        else:
            print(f"OK       {df.relative_to(ROOT)}")

    # 2. target にあって source に無い orphan ファイルを削除
    for rel in sorted(dst_files - src_files):
        df = dst / rel
        has_changes = True
        if check:
            print(f"ORPHAN   {df.relative_to(ROOT)}")
            continue
        df.unlink()
        print(f"REMOVED  {df.relative_to(ROOT)}")

    # 3. orphan 削除で空になったディレクトリを掃除
    if not check:
        remove_empty_dirs(dst)

    return has_changes


def sync_skill(package: str, skill: str, check: bool) -> bool:
    src = source_dir(package, skill)
    if not (src / "SKILL.md").is_file():
        raise SystemExit(f"Missing source SKILL.md: {(src / 'SKILL.md').relative_to(ROOT)}")

    has_changes = False
    for dst in target_dirs(package, skill):
        if mirror_dir(src, dst, check):
            has_changes = True
    return has_changes


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "skills",
        nargs="*",
        help="Skill names to sync. Defaults to all skills found in skills-sources/.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Report targets that differ; do not write.",
    )
    return parser.parse_args()


def filter_skills(
    available: list[tuple[str, str]], requested: list[str]
) -> list[tuple[str, str]]:
    if not requested:
        return available
    by_skill: dict[str, list[tuple[str, str]]] = {}
    for pkg, skill in available:
        by_skill.setdefault(skill, []).append((pkg, skill))
    selected: list[tuple[str, str]] = []
    unknown: list[str] = []
    for name in requested:
        matches = by_skill.get(name)
        if not matches:
            unknown.append(name)
            continue
        selected.extend(matches)
    if unknown:
        valid = ", ".join(sorted(by_skill)) or "(none)"
        raise SystemExit(
            f"Unknown skill(s): {', '.join(unknown)}\nAvailable: {valid}"
        )
    return selected


def main() -> int:
    args = parse_args()
    available = discover_skills()
    targets = filter_skills(available, args.skills)

    has_changes = False
    for package, skill in targets:
        has_changes = sync_skill(package, skill, args.check) or has_changes

    if args.check and has_changes:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
