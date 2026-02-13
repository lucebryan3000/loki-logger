#!/usr/bin/env python3
"""Search `temp/codex-sprint/artifacts.jsonl` with simple substring filters.

This helper is intentionally narrow: it only searches artifact rows and emits
matching rows as JSON lines for easy piping into `jq` or other tools.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _build_parser() -> argparse.ArgumentParser:
    epilog = """Examples:
  python3 scripts/codex-sprint/search_artifacts.py --prompt loki-prompt-13 --file manifest.txt
  python3 scripts/codex-sprint/search_artifacts.py --run r0012 --limit 20
"""
    ap = argparse.ArgumentParser(
        description="Search the flat artifact index (`artifacts.jsonl`) by prompt/file/run substrings.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog,
    )
    ap.add_argument(
        "--root",
        default="temp/codex-sprint",
        help="Codex-sprint root containing `artifacts.jsonl` (default: temp/codex-sprint).",
    )
    ap.add_argument("--prompt", default="", help="Case-insensitive prompt slug substring filter.")
    ap.add_argument(
        "--file",
        default="",
        help="Case-insensitive file name or relative-path substring filter.",
    )
    ap.add_argument("--run", default="", help="Case-insensitive run id/key substring filter.")
    ap.add_argument("--limit", type=int, default=100, help="Maximum rows to print (default: 100).")
    return ap


def main() -> int:
    args = _build_parser().parse_args()

    root = Path(args.root)
    index_path = root / "artifacts.jsonl"
    if not index_path.is_file():
        print(f"missing artifact index: {index_path}", file=sys.stderr)
        return 2

    prompt_q = args.prompt.strip().lower()
    file_q = args.file.strip().lower()
    run_q = args.run.strip().lower()
    limit = max(1, args.limit)

    matches = 0
    with index_path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue

            prompt_slug = str(row.get("prompt_slug", "")).lower()
            file_name = str(row.get("file_name", "")).lower()
            rel_path = str(row.get("rel_path", row.get("source_rel", ""))).lower()
            run_id = str(row.get("run_id", "")).lower()
            run_key = str(row.get("run_key", "")).lower()

            # Keep matching rules deterministic and transparent: simple AND filters.
            if prompt_q and prompt_q not in prompt_slug:
                continue
            if file_q and file_q not in file_name and file_q not in rel_path:
                continue
            if run_q and run_q not in run_id and run_q not in run_key:
                continue

            print(json.dumps(row, ensure_ascii=True, sort_keys=True))
            matches += 1
            if matches >= limit:
                break

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
