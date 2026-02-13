#!/usr/bin/env python3
"""Check required prompt frontmatter/body contract for mini pipeline prompts.

Deterministic gate only:
- no rewriting
- no LLM decisions
- exits non-zero on contract drift
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml


REQUIRED_BODY_HEADINGS = [
    "## Scope",
    "## Affects",
    "## Steps",
    "## Acceptance Proofs",
    "## Guardrails",
    "## Done Criteria",
    "## Operator Checkpoint",
]

REQUIRED_TOP_LEVEL = [
    "chatgpt_scoping_kind",
    "chatgpt_scoping_scope",
    "chatgpt_scoping_targets_root",
    "chatgpt_scoping_targets",
]

REQUIRED_POLICY = [
    "codex_preflight_autocommit",
    "codex_preflight_autopush",
    "codex_preflight_move_to_completed",
]


def split_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    if not text.startswith("---\n"):
        return {}, text
    m = re.match(r"\A---\n(.*?)\n---\n", text, flags=re.S)
    if not m:
        return {}, text
    raw = yaml.safe_load(m.group(1))
    fm = raw if isinstance(raw, dict) else {}
    body = text[m.end() :]
    return fm, body


def list_prompts(root: Path) -> list[Path]:
    prompts = sorted(p for p in root.rglob("*.md") if p.is_file())
    out: list[Path] = []
    for p in prompts:
        if p.name.lower() == "readme.md":
            continue
        if "completed" in p.parts or "failed" in p.parts:
            continue
        out.append(p)
    return out


def check_prompt(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    fm, body = split_frontmatter(text)
    errors: list[str] = []

    if not fm:
        errors.append("missing_frontmatter")
        return errors

    for key in REQUIRED_TOP_LEVEL:
        if key not in fm:
            errors.append(f"missing_key:{key}")

    for key in REQUIRED_POLICY:
        if key not in fm:
            errors.append(f"missing_policy:{key}")

    for heading in REQUIRED_BODY_HEADINGS:
        if heading not in body:
            errors.append(f"missing_heading:{heading}")

    # Ensure prompts are intended to be non-destructive in this mini harness.
    for key in REQUIRED_POLICY:
        val = str(fm.get(key, "")).strip().lower().strip("\"").strip("'")
        if val != "no":
            errors.append(f"policy_not_no:{key}={val}")

    return errors


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="check_frontmatter_contract.py",
        description="Validate prompt frontmatter/body contract for deployment_pipeline prompts.",
    )
    ap.add_argument(
        "--root",
        default="apps/deployment_pipeline/prompts",
        help="Prompt root to validate (default: apps/deployment_pipeline/prompts).",
    )
    ap.add_argument(
        "--json",
        action="store_true",
        help="Emit JSON summary.",
    )
    args = ap.parse_args(argv)

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        print(f"ERROR: root not found: {root}", file=sys.stderr)
        return 2

    prompts = list_prompts(root)
    findings: dict[str, list[str]] = {}
    for p in prompts:
        errs = check_prompt(p)
        if errs:
            findings[str(p)] = errs

    summary = {
        "root": str(root),
        "prompt_count": len(prompts),
        "violations": len(findings),
        "ok": len(findings) == 0,
        "findings": findings,
    }

    if args.json:
        print(json.dumps(summary, indent=2, ensure_ascii=True))
    else:
        print(f"root={summary['root']}")
        print(f"prompt_count={summary['prompt_count']}")
        print(f"violations={summary['violations']}")
        if findings:
            for p, errs in findings.items():
                print(f"- {p}")
                for e in errs:
                    print(f"  - {e}")

    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
