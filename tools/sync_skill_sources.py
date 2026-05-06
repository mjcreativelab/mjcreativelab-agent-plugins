#!/usr/bin/env python3
"""Render skill directories from skill-sources/<package>/<skill>/ to distribution targets.

配布先:
- claude: packages/<package>/skills/<skill>/  （package 階層を保持）
- codex:  skills/<skill>/                     （package を平坦化、ルート直下）

codex の skill 配置はルート `skills/` 直下（`.codex-plugin/plugin.json` の `"skills": "./skills/"` 参照先）。
`.codex-plugin/` 自体は plugin metadata 専用で skill 本体は置かない。

各配布先は source skill ディレクトリから target 別に render される:
- 共通ファイルを基準にしつつ、claude/ または codex/ 配下の override を root に重ねる
- skill-sync.yaml / skill-sync.json で target の有効/無効、除外ファイルを制御できる
- Codex 向け SKILL.md は Codex validator に合わせて frontmatter を正規化する
- target に存在し render 結果に無いファイルは削除（orphan 削除）
- skill-sources/ が唯一の正本（配布先の中身は generated）
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCES_DIR = ROOT / "skill-sources"
PACKAGES_DIR = ROOT / "packages"
CODEX_PLUGIN_DIR = ROOT / ".codex-plugin"  # plugin.json の有無で codex 配布対象かを判定
CODEX_SKILLS_DIR = ROOT / "skills"          # 実際の codex skill 配置先（ルート直下）
TARGET_NAMES = ("claude", "codex")
CONFIG_NAMES = ("skill-sync.json", "skill-sync.yaml", "skill-sync.yml")
CODEX_ALLOWED_FRONTMATTER = {"name", "description", "license", "metadata"}


@dataclass
class TargetConfig:
    enabled: bool = True
    exclude: list[str] = field(default_factory=list)
    include_readme: bool | None = None


@dataclass
class TargetSpec:
    name: str
    dst: Path
    config: TargetConfig


def discover_skills() -> list[tuple[str, str]]:
    """skill-sources/<package>/<skill>/SKILL.md を走査して (package, skill) のリストを返す。

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


def target_specs(package: str, skill: str, config: dict[str, TargetConfig]) -> list[TargetSpec]:
    """Render 先ディレクトリのリスト。.codex-plugin/plugin.json が存在する時のみ codex 側を含める。"""
    specs = [
        TargetSpec(
            name="claude",
            dst=PACKAGES_DIR / package / "skills" / skill,
            config=config.get("claude", TargetConfig()),
        )
    ]
    if (CODEX_PLUGIN_DIR / "plugin.json").is_file():
        specs.append(
            TargetSpec(
                name="codex",
                dst=CODEX_SKILLS_DIR / skill,
                config=config.get("codex", TargetConfig()),
            )
        )
    return specs


def list_files(root: Path) -> set[Path]:
    """root 配下の通常ファイルを relative path のセットで返す（symlink は無視）。"""
    if not root.is_dir():
        return set()
    return {
        p.relative_to(root)
        for p in root.rglob("*")
        if p.is_file() and not p.is_symlink()
    }


def parse_scalar(raw: str) -> object:
    value = raw.strip()
    if value.lower() == "true":
        return True
    if value.lower() == "false":
        return False
    if value in {"[]", ""}:
        return [] if value == "[]" else ""
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [item.strip().strip('"').strip("'") for item in inner.split(",")]
    return value.strip('"').strip("'")


def load_simple_yaml(path: Path) -> dict[str, object]:
    """skill-sync.yaml 用の最小 YAML parser。

    外部依存を避けるため、運用で使う subset のみ扱う:
    targets:
      codex:
        enabled: false
        include_readme: true
        exclude:
          - README.md
    """
    result: dict[str, object] = {"targets": {}}
    current_target: str | None = None
    current_list_key: str | None = None

    for lineno, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        if indent == 0:
            if stripped != "targets:":
                raise SystemExit(f"Unsupported key in {path.relative_to(ROOT)}:{lineno}: {stripped}")
            continue

        if indent == 2 and stripped.endswith(":"):
            current_target = stripped[:-1]
            if current_target not in TARGET_NAMES:
                raise SystemExit(
                    f"Unknown target in {path.relative_to(ROOT)}:{lineno}: {current_target}"
                )
            targets = result["targets"]
            assert isinstance(targets, dict)
            targets.setdefault(current_target, {})
            current_list_key = None
            continue

        if current_target is None:
            raise SystemExit(f"Missing target in {path.relative_to(ROOT)}:{lineno}")

        targets = result["targets"]
        assert isinstance(targets, dict)
        target_config = targets.setdefault(current_target, {})
        assert isinstance(target_config, dict)

        if indent == 4 and ":" in stripped:
            key, raw_value = stripped.split(":", 1)
            key = key.strip()
            if raw_value.strip():
                target_config[key] = parse_scalar(raw_value)
                current_list_key = None
            else:
                target_config[key] = []
                current_list_key = key
            continue

        if indent == 6 and stripped.startswith("- ") and current_list_key:
            value = stripped[2:].strip().strip('"').strip("'")
            current_list = target_config.setdefault(current_list_key, [])
            if not isinstance(current_list, list):
                raise SystemExit(
                    f"Expected list in {path.relative_to(ROOT)}:{lineno}: {current_list_key}"
                )
            current_list.append(value)
            continue

        raise SystemExit(f"Unsupported YAML in {path.relative_to(ROOT)}:{lineno}: {raw_line}")

    return result


def load_skill_config(src: Path) -> dict[str, TargetConfig]:
    raw: dict[str, object] = {}
    for name in CONFIG_NAMES:
        config_path = src / name
        if not config_path.is_file():
            continue
        if config_path.suffix == ".json":
            raw = json.loads(config_path.read_text(encoding="utf-8"))
        else:
            raw = load_simple_yaml(config_path)
        break

    targets_raw = raw.get("targets", {}) if raw else {}
    if not isinstance(targets_raw, dict):
        raise SystemExit("skill-sync config 'targets' must be a dictionary")

    result: dict[str, TargetConfig] = {}
    for target, value in targets_raw.items():
        if target not in TARGET_NAMES:
            raise SystemExit(f"Unknown target in skill-sync config: {target}")
        if not isinstance(value, dict):
            raise SystemExit(f"Target config must be a dictionary: {target}")
        exclude = value.get("exclude", [])
        if isinstance(exclude, str):
            exclude = [exclude]
        if not isinstance(exclude, list) or not all(isinstance(item, str) for item in exclude):
            raise SystemExit(f"Target exclude must be a string list: {target}")
        include_readme = value.get("include_readme")
        if include_readme is not None and not isinstance(include_readme, bool):
            raise SystemExit(f"Target include_readme must be a boolean: {target}")
        enabled = value.get("enabled", True)
        if not isinstance(enabled, bool):
            raise SystemExit(f"Target enabled must be a boolean: {target}")
        result[target] = TargetConfig(
            enabled=enabled,
            exclude=exclude,
            include_readme=include_readme,
        )
    return result


def remove_empty_dirs(root: Path, remove_root: bool = False) -> None:
    """root 配下の空ディレクトリを深い順に削除する。"""
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
    if remove_root:
        try:
            root.rmdir()
        except OSError:
            pass  # 空でない root はスキップ


def is_under_target_overlay(rel: Path) -> bool:
    return bool(rel.parts) and rel.parts[0] in TARGET_NAMES


def is_config_file(rel: Path) -> bool:
    return len(rel.parts) == 1 and rel.name in CONFIG_NAMES


def matches_exclude(rel: Path, patterns: list[str]) -> bool:
    text = rel.as_posix()
    for pattern in patterns:
        normalized = pattern.strip().rstrip("/")
        if not normalized:
            continue
        if text == normalized or text.startswith(f"{normalized}/"):
            return True
    return False


def sanitize_codex_frontmatter(content: bytes) -> bytes:
    text = content.decode("utf-8")
    if not text.startswith("---\n"):
        return content
    end = text.find("\n---", 4)
    if end == -1:
        return content

    frontmatter = text[4:end].splitlines()
    body = text[end:]
    entries: list[tuple[str, list[str]]] = []
    current_key: str | None = None
    current_lines: list[str] = []

    for line in frontmatter:
        if line and not line.startswith((" ", "\t")) and ":" in line:
            if current_key is not None:
                entries.append((current_key, current_lines))
            current_key = line.split(":", 1)[0]
            current_lines = [line]
        elif current_key is not None:
            current_lines.append(line)
    if current_key is not None:
        entries.append((current_key, current_lines))

    filtered: list[str] = []
    for key, lines in entries:
        if key not in CODEX_ALLOWED_FRONTMATTER:
            continue
        if key == "description":
            first, *rest = lines
            if first.strip() in {"description: >", "description: |"}:
                lines = [first, *[line.replace("<", "").replace(">", "") for line in rest]]
            else:
                prefix, raw_value = first.split(":", 1)
                first = f"{prefix}:{raw_value.replace('<', '').replace('>', '')}"
                lines = [first, *[line.replace("<", "").replace(">", "") for line in rest]]
        filtered.extend(lines)

    rendered = "---\n" + "\n".join(filtered).rstrip() + body
    return rendered.encode("utf-8")


def render_files(src: Path, spec: TargetSpec) -> dict[Path, bytes | Path]:
    if not spec.config.enabled:
        return {}

    files: dict[Path, bytes | Path] = {}
    common_excludes = {Path(part) for part in CONFIG_NAMES}
    target_excludes = list(spec.config.exclude)
    if spec.name == "codex" and spec.config.include_readme is not True:
        target_excludes.append("README.md")

    for rel in sorted(list_files(src)):
        if is_config_file(rel) or is_under_target_overlay(rel):
            continue
        if rel in common_excludes or matches_exclude(rel, target_excludes):
            continue
        files[rel] = src / rel

    overlay_dir = src / spec.name
    if overlay_dir.is_dir():
        for rel in sorted(list_files(overlay_dir)):
            if matches_exclude(rel, target_excludes):
                continue
            files[rel] = overlay_dir / rel

    if spec.name == "codex" and Path("SKILL.md") in files:
        source_or_bytes = files[Path("SKILL.md")]
        if isinstance(source_or_bytes, Path):
            raw = source_or_bytes.read_bytes()
        else:
            raw = source_or_bytes
        files[Path("SKILL.md")] = sanitize_codex_frontmatter(raw)

    return files


def file_bytes(value: bytes | Path) -> bytes:
    if isinstance(value, bytes):
        return value
    return value.read_bytes()


def sync_rendered_files(files: dict[Path, bytes | Path], dst: Path, check: bool) -> bool:
    """render 結果を dst に同期する（orphan 削除あり）。差分があれば True を返す。"""
    dst_files = list_files(dst)
    src_files = set(files)
    has_changes = False

    # 1. render result → target: 新規・更新ファイルを書き込む
    for rel in sorted(src_files):
        df = dst / rel
        if df.is_symlink():
            raise SystemExit(f"Refusing to write symlink target: {df.relative_to(ROOT)}")
        rendered_bytes = file_bytes(files[rel])
        differs = not df.is_file() or df.read_bytes() != rendered_bytes
        if differs:
            has_changes = True
            if check:
                print(f"OUTDATED {df.relative_to(ROOT)}")
                continue
            df.parent.mkdir(parents=True, exist_ok=True)
            source_or_bytes = files[rel]
            if isinstance(source_or_bytes, Path):
                shutil.copy2(source_or_bytes, df)
            else:
                df.write_bytes(source_or_bytes)
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
        remove_empty_dirs(dst, remove_root=not files)

    return has_changes


def sync_skill(package: str, skill: str, check: bool, target_filter: set[str]) -> bool:
    src = source_dir(package, skill)
    if not (src / "SKILL.md").is_file():
        raise SystemExit(f"Missing source SKILL.md: {(src / 'SKILL.md').relative_to(ROOT)}")

    config = load_skill_config(src)
    has_changes = False
    for spec in target_specs(package, skill, config):
        if target_filter and spec.name not in target_filter:
            continue
        rendered = render_files(src, spec)
        if not spec.config.enabled:
            print(f"DISABLED {spec.dst.relative_to(ROOT)}")
        if sync_rendered_files(rendered, spec.dst, check):
            has_changes = True
    return has_changes


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "skills",
        nargs="*",
        help="Skill names to sync. Defaults to all skills found in skill-sources/.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Report targets that differ; do not write.",
    )
    parser.add_argument(
        "--target",
        choices=TARGET_NAMES,
        action="append",
        help="Limit sync/check to a target. Can be passed multiple times.",
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
    target_filter = set(args.target or [])

    has_changes = False
    for package, skill in targets:
        has_changes = sync_skill(package, skill, args.check, target_filter) or has_changes

    if args.check and has_changes:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
