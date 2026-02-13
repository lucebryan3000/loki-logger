#!/usr/bin/env python3
"""Search any flat codex-sprint JSONL index.

Supported indexes:
- artifacts.jsonl
- runs.jsonl
- history.jsonl
- state.jsonl

Rows are emitted as JSON lines for downstream automation.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def iter_jsonl(path: Path):
    """Yield parsed JSON objects from a JSONL file and skip malformed rows."""
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


def matches(row: dict, prompt_q: str, run_q: str, file_q: str, status_q: str) -> bool:
    """Return True when a row satisfies all active filters."""
    prompt = str(row.get("prompt_slug", "")).lower()
    run = " ".join([str(row.get("run_id", "")), str(row.get("run_key", "")), str(row.get("run_ref", ""))]).lower()
    file_text = " ".join([str(row.get("file_name", "")), str(row.get("rel_path", "")), str(row.get("source_rel", ""))]).lower()
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


def _build_parser() -> argparse.ArgumentParser:
    epilog = """Examples:
  python3 scripts/codex-sprint/search_records.py --index runs --prompt loki-prompt-13
  python3 scripts/codex-sprint/search_records.py --index state --status failed --limit 20
  python3 scripts/codex-sprint/search_records.py --index artifacts --file manifest.txt --run r0007
"""
    ap = argparse.ArgumentParser(
        description="Search flat codex-sprint JSONL indexes with consistent substring filters.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog,
    )
    ap.add_argument(
        "--root",
        default="temp/codex-sprint",
        help="Codex-sprint root containing flat indexes (default: temp/codex-sprint).",
    )
    ap.add_argument(
        "--index",
        choices=["artifacts", "runs", "history", "state"],
        default="artifacts",
        help="Index to search (default: artifacts).",
    )
    ap.add_argument("--prompt", default="", help="Case-insensitive prompt slug substring filter.")
    ap.add_argument("--run", default="", help="Case-insensitive run id/key/ref substring filter.")
    ap.add_argument("--file", default="", help="Case-insensitive file name/path substring filter.")
    ap.add_argument("--status", default="", help="Case-insensitive exact status match filter.")
    ap.add_argument("--limit", type=int, default=100, help="Maximum rows to print (default: 100).")
    return ap


def main() -> int:
    args = _build_parser().parse_args()

    root = Path(args.root)
    index_map = {
        "artifacts": root / "artifacts.jsonl",
        "runs": root / "runs.jsonl",
        "history": root / "history.jsonl",
        "state": root / "state.jsonl",
    }
    path = index_map[args.index]
    if not path.is_file():
        print(f"missing index: {path}", file=sys.stderr)
        return 2

    prompt_q = args.prompt.strip().lower()
    run_q = args.run.strip().lower()
    file_q = args.file.strip().lower()
    status_q = args.status.strip().lower()
    limit = max(1, args.limit)

    count = 0
    for row in iter_jsonl(path):
        # Deterministic AND semantics across all active filters.
        if not matches(row, prompt_q, run_q, file_q, status_q):
            continue
        print(json.dumps(row, ensure_ascii=True, sort_keys=True))
        count += 1
        if count >= limit:
            break

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
