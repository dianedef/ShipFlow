#!/usr/bin/env python3
"""Validate ShipFlow artifact frontmatter.

The linter intentionally uses only Python's standard library so it can run in
fresh projects before dependencies are installed.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_TARGETS = (
    "specs",
    "docs",
    "AGENT.md",
    "CONTEXT.md",
    "CONTEXT-FUNCTION-TREE.md",
    "BUSINESS.md",
    "BRANDING.md",
    "GUIDELINES.md",
)
VALID_STATUSES = {"draft", "reviewed", "ready", "active", "stale", "superseded"}
VALID_CONFIDENCE = {"low", "medium", "high", "unknown"}
VALID_RISK = {"low", "medium", "high", "critical", "unknown"}

COMMON_REQUIRED = {
    "artifact",
    "metadata_schema_version",
    "artifact_version",
    "project",
    "created",
    "updated",
    "status",
    "source_skill",
    "scope",
    "owner",
    "confidence",
    "risk_level",
    "security_impact",
    "docs_impact",
    "evidence",
    "depends_on",
    "supersedes",
    "next_step",
}

ARTIFACT_REQUIRED = {
    "spec": {"user_story", "linked_systems"},
    "business_context": {"target_audience", "value_proposition", "business_model", "market", "next_review"},
    "brand_context": {"brand_voice", "trust_posture", "next_review"},
    "technical_guidelines": {"linked_systems", "next_review"},
    "audit_report": {"domains", "issue_counts"},
    "verification_report": {"verified_outcomes", "assumptions"},
    "readiness_report": {"user_story", "verified_outcomes", "assumptions"},
    "review_report": {"period", "verified_outcomes", "assumptions"},
    "research_report": {"source_count", "primary_sources", "recommendation"},
    "decision_record": {"decision", "rationale", "consequences"},
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="*",
        help="Files or directories to lint. Defaults to specs/, docs/, AGENT.md, CONTEXT.md, CONTEXT-FUNCTION-TREE.md, BUSINESS.md, BRANDING.md, GUIDELINES.md.",
    )
    parser.add_argument(
        "--all-markdown",
        action="store_true",
        help="Lint every markdown file under the provided paths, including files without ShipFlow artifact markers.",
    )
    return parser.parse_args()


def iter_markdown(paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for raw in paths or list(DEFAULT_TARGETS):
        path = Path(raw)
        if not path.exists():
            continue
        if path.is_dir():
            files.extend(
                p
                for p in path.rglob("*.md")
                if ".git" not in p.parts and "archive" not in p.parts
            )
        elif path.suffix.lower() in {".md", ".mdx"}:
            files.append(path)
    return sorted(set(files))


def read_frontmatter(path: Path) -> tuple[dict[str, str], list[str]]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return {}, ["missing YAML frontmatter"]
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, ["missing closing YAML frontmatter delimiter"]

    fields: dict[str, str] = {}
    errors: list[str] = []
    for line in text[4:end].splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith("-"):
            continue
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):(?:\s*(.*))?$", line)
        if not match:
            continue
        key, value = match.groups()
        fields[key] = (value or "").strip().strip("\"'")
    return fields, errors


def should_lint(path: Path, fields: dict[str, str], all_markdown: bool) -> bool:
    if all_markdown:
        return True
    if fields.get("metadata_schema_version") or fields.get("artifact_version"):
        return True
    if path.name in {"BUSINESS.md", "BRANDING.md", "GUIDELINES.md"}:
        return True
    if "specs" in path.parts:
        return True
    return False


def validate(path: Path, fields: dict[str, str], initial_errors: list[str]) -> list[str]:
    errors = list(initial_errors)
    if errors:
        return errors

    missing = sorted(key for key in COMMON_REQUIRED if key not in fields)
    if missing:
        errors.append("missing required fields: " + ", ".join(missing))

    artifact = fields.get("artifact", "")
    extra_required = ARTIFACT_REQUIRED.get(artifact, set())
    missing_extra = sorted(key for key in extra_required if key not in fields)
    if missing_extra:
        errors.append(f"missing {artifact} fields: " + ", ".join(missing_extra))

    if fields.get("metadata_schema_version") != "1.0":
        errors.append("metadata_schema_version must be \"1.0\"")

    artifact_version = fields.get("artifact_version", "")
    if artifact_version and not re.match(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$", artifact_version):
        errors.append("artifact_version must use semantic versioning, for example 0.1.0 or 1.0.0")

    status = fields.get("status")
    if status and status not in VALID_STATUSES:
        errors.append("status must be one of: " + ", ".join(sorted(VALID_STATUSES)))

    confidence = fields.get("confidence")
    if confidence and confidence not in VALID_CONFIDENCE:
        errors.append("confidence must be one of: " + ", ".join(sorted(VALID_CONFIDENCE)))

    risk_level = fields.get("risk_level")
    if risk_level and risk_level not in VALID_RISK:
        errors.append("risk_level must be one of: " + ", ".join(sorted(VALID_RISK)))

    if fields.get("status") in {"reviewed", "ready", "active"} and artifact_version.startswith("0."):
        errors.append("reviewed/ready/active artifacts should use artifact_version >= 1.0.0")

    if fields.get("status") == "superseded" and not fields.get("superseded_by"):
        errors.append("superseded artifacts must set superseded_by")

    return errors


def main() -> int:
    args = parse_args()
    files = iter_markdown(args.paths)
    checked = 0
    failures: list[tuple[Path, list[str]]] = []

    for path in files:
        fields, initial_errors = read_frontmatter(path)
        if not should_lint(path, fields, args.all_markdown):
            continue
        checked += 1
        errors = validate(path, fields, initial_errors)
        if errors:
            failures.append((path, errors))

    if failures:
        for path, errors in failures:
            print(f"{path}:")
            for error in errors:
                print(f"  - {error}")
        print(f"\nShipFlow metadata lint failed: {len(failures)} file(s) invalid, {checked} checked.")
        return 1

    print(f"ShipFlow metadata lint passed: {checked} file(s) checked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
