#!/usr/bin/env python3
"""Validate generated Codex skills without third-party dependencies."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SKILLS_DIR = ROOT / "skills"
ALLOWED_FRONTMATTER_KEYS = {"name", "description", "license", "metadata"}
MAX_SKILL_NAME_LENGTH = 64
MAX_DESCRIPTION_LENGTH = 1024


@dataclass
class ValidationResult:
    path: Path
    errors: list[str]

    @property
    def valid(self) -> bool:
        return not self.errors


def extract_frontmatter(path: Path) -> tuple[str | None, str | None]:
    content = path.read_text(encoding="utf-8")
    if not content.startswith("---\n"):
        return None, "No YAML frontmatter found"
    end = content.find("\n---", 4)
    if end == -1:
        return None, "Invalid frontmatter format"
    return content[4:end], None


def parse_frontmatter(frontmatter: str) -> dict[str, str]:
    values: dict[str, str] = {}
    current_key: str | None = None
    current_lines: list[str] = []

    def flush() -> None:
        nonlocal current_key, current_lines
        if current_key is None:
            return
        values[current_key] = "\n".join(current_lines).strip()
        current_key = None
        current_lines = []

    for raw_line in frontmatter.splitlines():
        if raw_line and not raw_line.startswith((" ", "\t")) and ":" in raw_line:
            flush()
            key, raw_value = raw_line.split(":", 1)
            current_key = key.strip()
            value = raw_value.strip()
            current_lines = [] if value in {">", "|"} else [value]
        elif current_key is not None:
            current_lines.append(raw_line.strip())
    flush()

    return values


def validate_skill(skill_dir: Path) -> ValidationResult:
    skill_md = skill_dir / "SKILL.md"
    errors: list[str] = []

    if not skill_md.is_file():
        return ValidationResult(skill_md, ["SKILL.md not found"])

    frontmatter, extraction_error = extract_frontmatter(skill_md)
    if extraction_error:
        return ValidationResult(skill_md, [extraction_error])

    assert frontmatter is not None
    values = parse_frontmatter(frontmatter)

    unexpected_keys = set(values) - ALLOWED_FRONTMATTER_KEYS
    if unexpected_keys:
        allowed = ", ".join(sorted(ALLOWED_FRONTMATTER_KEYS))
        unexpected = ", ".join(sorted(unexpected_keys))
        errors.append(
            f"Unexpected frontmatter key(s): {unexpected}. Allowed keys: {allowed}"
        )

    name = values.get("name", "").strip().strip('"').strip("'")
    if not name:
        errors.append("Missing 'name' in frontmatter")
    elif not re.fullmatch(r"[a-z0-9-]+", name):
        errors.append(
            f"Name '{name}' should be hyphen-case (lowercase letters, digits, and hyphens only)"
        )
    elif name.startswith("-") or name.endswith("-") or "--" in name:
        errors.append(
            f"Name '{name}' cannot start/end with hyphen or contain consecutive hyphens"
        )
    elif len(name) > MAX_SKILL_NAME_LENGTH:
        errors.append(
            f"Name is too long ({len(name)} characters). Maximum is {MAX_SKILL_NAME_LENGTH}"
        )

    description = values.get("description", "").strip().strip('"').strip("'")
    if not description:
        errors.append("Missing 'description' in frontmatter")
    else:
        if "<" in description or ">" in description:
            errors.append("Description cannot contain angle brackets (< or >)")
        if len(description) > MAX_DESCRIPTION_LENGTH:
            errors.append(
                f"Description is too long ({len(description)} characters). "
                f"Maximum is {MAX_DESCRIPTION_LENGTH}"
            )

    return ValidationResult(skill_md, errors)


def discover_skill_dirs(skills_dir: Path) -> list[Path]:
    if not skills_dir.is_dir():
        return []
    return sorted(path for path in skills_dir.iterdir() if path.is_dir())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "skills",
        nargs="*",
        help="Skill directories or names. Defaults to all skills under ./skills.",
    )
    parser.add_argument(
        "--skills-dir",
        default=str(DEFAULT_SKILLS_DIR),
        help="Directory containing generated Codex skills. Defaults to ./skills.",
    )
    return parser.parse_args()


def resolve_targets(skills_dir: Path, requested: list[str]) -> list[Path]:
    if not requested:
        return discover_skill_dirs(skills_dir)

    targets: list[Path] = []
    for item in requested:
        path = Path(item)
        if path.is_dir():
            targets.append(path)
            continue
        targets.append(skills_dir / item)
    return targets


def main() -> int:
    args = parse_args()
    skills_dir = Path(args.skills_dir)
    if not skills_dir.is_absolute():
        skills_dir = ROOT / skills_dir

    targets = resolve_targets(skills_dir, args.skills)
    if not targets:
        print(f"No skills found under {skills_dir.relative_to(ROOT)}")
        return 0

    has_errors = False
    for skill_dir in targets:
        result = validate_skill(skill_dir)
        rel = result.path.relative_to(ROOT) if result.path.is_absolute() else result.path
        if result.valid:
            print(f"OK       {rel}")
            continue
        has_errors = True
        for error in result.errors:
            print(f"ERROR    {rel}: {error}")

    return 1 if has_errors else 0


if __name__ == "__main__":
    sys.exit(main())
