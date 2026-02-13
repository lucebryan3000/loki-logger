#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser(description="Search temp/codex-sprint/artifacts.jsonl")
    ap.add_argument("--root", default="temp/codex-sprint", help="codex-sprint root")
    ap.add_argument("--prompt", default="", help="prompt slug substring match")
    ap.add_argument("--file", default="", help="artifact file name or rel path substring match")
    ap.add_argument("--run", default="", help="run id or run key substring match")
    ap.add_argument("--limit", type=int, default=100, help="max rows to print")
    args = ap.parse_args()

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
