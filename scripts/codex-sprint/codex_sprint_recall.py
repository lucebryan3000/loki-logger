#!/usr/bin/env python3
"""Unified recall helper for flat codex-sprint indexes.

Commands:
- `summary`: file locations + lightweight counts/sizes
- `latest`: latest prompt state rows from `state.latest.json`
- `find`: filtered scan across one or all JSONL indexes

This is the main machine-facing recall entrypoint used by shell wrappers and
skills when quick lookups are needed.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _iter_jsonl(path: Path):
    """Yield parsed JSON rows from a JSONL path, skipping malformed lines."""
    if not path.is_file():
        return
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def _matches(row: dict, prompt_q: str, run_q: str, file_q: str, status_q: str) -> bool:
    """Apply deterministic AND filters used by `find` command."""
    prompt = str(row.get("prompt_slug", "")).lower()
    run = " ".join(
        [
            str(row.get("run_id", "")),
            str(row.get("run_key", "")),
            str(row.get("run_ref", "")),
        ]
    ).lower()
    file_text = " ".join(
        [
            str(row.get("file_name", "")),
            str(row.get("rel_path", "")),
            str(row.get("source_rel", "")),
        ]
    ).lower()
    status = str(row.get("status", "")).lower()

    if prompt_q and prompt_q not in prompt:
        return False
    if run_q and run_q not in run:
        return False
    if file_q and file_q not in file_text:
        return False
    if status_q and status_q != status:
        return False
    return True


def cmd_latest(root: Path, prompt_q: str, limit: int) -> int:
    """Print latest prompt state rows from `state.latest.json`."""
    latest_path = root / "state.latest.json"
    if not latest_path.is_file():
        print(f"missing file: {latest_path}", file=sys.stderr)
        return 2
    obj = json.loads(latest_path.read_text(encoding="utf-8"))
    prompts = obj.get("prompts", {})
    if not isinstance(prompts, dict):
        prompts = {}

    rows = []
    for slug, row in prompts.items():
        if not isinstance(row, dict):
            continue
        if prompt_q and prompt_q not in slug.lower():
            continue
        rows.append(row)

    rows.sort(key=lambda x: str(x.get("run_key", "")))
    for row in rows[:limit]:
        print(json.dumps(row, ensure_ascii=True, sort_keys=True))
    return 0


def cmd_find(root: Path, index: str, prompt_q: str, run_q: str, file_q: str, status_q: str, limit: int) -> int:
    """Search one or more indexes and print matching rows as JSON lines."""
    index_map = {
        "state": root / "state.jsonl",
        "history": root / "history.jsonl",
        "runs": root / "runs.jsonl",
        "artifacts": root / "artifacts.jsonl",
    }

    selected = list(index_map.keys()) if index == "all" else [index]
    printed = 0

    for idx in selected:
        p = index_map[idx]
        if not p.is_file():
            continue
        for row in _iter_jsonl(p):
            if not _matches(row, prompt_q, run_q, file_q, status_q):
                continue
            # Include source index for multi-index scans to preserve provenance.
            out = {"index": idx, **row}
            print(json.dumps(out, ensure_ascii=True, sort_keys=True))
            printed += 1
            if printed >= limit:
                return 0
    return 0


def cmd_summary(root: Path) -> int:
    """Print root paths plus line counts (jsonl) / byte size (json files)."""
    files = ["state.jsonl", "history.jsonl", "runs.jsonl", "artifacts.jsonl", "catalog.json", "state.latest.json"]
    payload = {"root": str(root), "files": {}, "counts": {}}

    for name in files:
        p = root / name
        payload["files"][name] = str(p)
        if not p.exists():
            payload["counts"][name] = 0
            continue
        if name.endswith(".jsonl"):
            payload["counts"][name] = sum(1 for _ in p.open("r", encoding="utf-8"))
        else:
            payload["counts"][name] = p.stat().st_size

    print(json.dumps(payload, ensure_ascii=True, sort_keys=True, indent=2))
    return 0


def _build_parser() -> argparse.ArgumentParser:
    epilog = """Examples:
  python3 scripts/codex-sprint/codex_sprint_recall.py summary
  python3 scripts/codex-sprint/codex_sprint_recall.py latest --prompt loki-prompt-13 --limit 10
  python3 scripts/codex-sprint/codex_sprint_recall.py find --index runs --status failed
  python3 scripts/codex-sprint/codex_sprint_recall.py find --index all --file manifest.txt --limit 25
"""
    ap = argparse.ArgumentParser(
        description="Unified recall helper for flat codex-sprint state/history/runs/artifacts indexes.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog,
    )
    ap.add_argument(
        "--root",
        default="temp/codex-sprint",
        help="Codex-sprint root containing flat index files (default: temp/codex-sprint).",
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_latest = sub.add_parser(
        "latest",
        help="Show latest state rows from state.latest.json",
        description="Print latest prompt state rows, optionally filtered by prompt slug substring.",
    )
    p_latest.add_argument("--prompt", default="", help="Case-insensitive prompt slug substring filter.")
    p_latest.add_argument("--limit", type=int, default=50, help="Maximum rows to print (default: 50).")

    p_find = sub.add_parser(
        "find",
        help="Search one or more JSONL indexes",
        description="Search state/history/runs/artifacts indexes with deterministic AND filters.",
    )
    p_find.add_argument(
        "--index",
        choices=["state", "history", "runs", "artifacts", "all"],
        default="all",
        help="Index to scan (default: all).",
    )
    p_find.add_argument("--prompt", default="", help="Case-insensitive prompt slug substring filter.")
    p_find.add_argument("--run", default="", help="Case-insensitive run id/key/ref substring filter.")
    p_find.add_argument("--file", default="", help="Case-insensitive file name/path substring filter.")
    p_find.add_argument("--status", default="", help="Case-insensitive exact status match filter.")
    p_find.add_argument("--limit", type=int, default=100, help="Maximum rows to print (default: 100).")

    sub.add_parser(
        "summary",
        help="Show index file paths plus quick counts/sizes",
        description="Print index file locations and lightweight row/byte metrics.",
    )
    return ap


def main() -> int:
    args = _build_parser().parse_args()
    root = Path(args.root)

    if args.cmd == "latest":
        return cmd_latest(root, args.prompt.strip().lower(), max(1, args.limit))
    if args.cmd == "find":
        return cmd_find(
            root,
            args.index,
            args.prompt.strip().lower(),
            args.run.strip().lower(),
            args.file.strip().lower(),
            args.status.strip().lower(),
            max(1, args.limit),
        )
    if args.cmd == "summary":
        return cmd_summary(root)

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
