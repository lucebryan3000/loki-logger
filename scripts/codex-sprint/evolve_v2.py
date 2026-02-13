#!/usr/bin/env python3
"""Build codex-sprint evolution v2.

v2 keeps append-only state/history logs and adds a flat artifact blob strategy:
- run summaries go to `runs/<prompt-slug>--<rNNNN>.json`
- per-prompt and global history/state indexes are JSONL
- run artifacts are copied into `blobs/<prompt-slug>/` as
  `<rNNNN>__<flattened-original-path>`

This model reduces deep folder churn while preserving artifact bytes.
"""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path

from common import (
    append_jsonl,
    assign_short_run_ids,
    collect_legacy_runs,
    now_utc_iso,
    tree_metrics,
    write_json,
)


def safe_blob_name(rel_path: str) -> str:
    """Flatten relative paths into filesystem-safe file names."""
    flattened = rel_path.replace("/", "__")
    flattened = re.sub(r"[^A-Za-z0-9._-]+", "-", flattened)
    return flattened.strip("-") or "artifact.bin"


def build_v2(repo_root: Path, out_root: Path) -> dict:
    """Materialize the v2 layout and return a summary payload."""
    runs = assign_short_run_ids(collect_legacy_runs(repo_root))

    for d in ("state", "history", "blobs", "runs", "catalog"):
        (out_root / d).mkdir(parents=True, exist_ok=True)

    write_json(
        out_root / "catalog" / "schema.json",
        {
            "version": "v2",
            "created_utc": now_utc_iso(),
            "layout": {
                "state_log": "state/<prompt-slug>.jsonl",
                "state_latest": "state/<prompt-slug>.latest.json",
                "history": "history/<prompt-slug>.jsonl",
                "global_history": "history/all-runs.jsonl",
                "run_summary": "runs/<prompt-slug>--<rNNNN>.json",
                "blobs": "blobs/<prompt-slug>/<rNNNN>__<artifact-file>",
            },
            "notes": [
                "Run metadata is append-only JSONL.",
                "Artifacts are flattened to one prompt folder with run-id prefixes.",
            ],
        },
    )

    prompt_stats: dict[str, dict] = {}
    copied_files = 0

    for run in runs:
        src_dir = Path(run.source_run_path)
        prompt_blob_dir = out_root / "blobs" / run.prompt_slug
        prompt_blob_dir.mkdir(parents=True, exist_ok=True)

        blob_entries: list[dict] = []
        collision_count = 0
        for rel in run.files:
            src = src_dir / rel
            base = safe_blob_name(rel)
            dst = prompt_blob_dir / f"{run.run_id}__{base}"
            suffix = 1
            # Preserve every artifact even if flattened names collide.
            while dst.exists():
                collision_count += 1
                dst = prompt_blob_dir / f"{run.run_id}__{suffix:02d}__{base}"
                suffix += 1
            shutil.copy2(src, dst)
            copied_files += 1
            blob_entries.append({"name": dst.name, "source_rel": rel, "bytes": src.stat().st_size})

        run_record = {
            "prompt_slug": run.prompt_slug,
            "run_id": run.run_id,
            "run_seq": run.run_seq,
            "run_key": run.run_key,
            "source_family": run.source_family,
            "source_prompt_label": run.source_prompt_label,
            "source_run_label": run.source_run_label,
            "source_run_path": run.source_run_path,
            "file_count": run.file_count,
            "total_bytes": run.total_bytes,
            "blob_count": len(blob_entries),
            "blob_collision_count": collision_count,
            "indexed_utc": now_utc_iso(),
        }

        write_json(out_root / "runs" / f"{run.run_key}.json", {**run_record, "blobs": blob_entries})

        append_jsonl(out_root / "history" / "all-runs.jsonl", run_record)
        append_jsonl(out_root / "history" / f"{run.prompt_slug}.jsonl", run_record)
        append_jsonl(out_root / "state" / f"{run.prompt_slug}.jsonl", run_record)
        write_json(out_root / "state" / f"{run.prompt_slug}.latest.json", run_record)

        stats = prompt_stats.setdefault(
            run.prompt_slug,
            {
                "prompt_slug": run.prompt_slug,
                "run_count": 0,
                "total_files": 0,
                "total_bytes": 0,
                "last_run_id": "",
            },
        )
        stats["run_count"] += 1
        stats["total_files"] += run.file_count
        stats["total_bytes"] += run.total_bytes
        stats["last_run_id"] = run.run_id

    write_json(
        out_root / "catalog" / "prompts.json",
        {
            "created_utc": now_utc_iso(),
            "prompt_count": len(prompt_stats),
            "run_count": len(runs),
            "prompts": [prompt_stats[k] for k in sorted(prompt_stats.keys())],
        },
    )

    metrics = tree_metrics(out_root)
    summary = {
        "evolution": "v2",
        "created_utc": now_utc_iso(),
        "source_run_count": len(runs),
        "source_prompt_count": len(prompt_stats),
        "copied_files": copied_files,
        "output_metrics": metrics.to_dict(),
    }
    write_json(out_root / "SUMMARY.json", summary)
    return summary


def _build_parser() -> argparse.ArgumentParser:
    epilog = """Examples:
  python3 scripts/codex-sprint/evolve_v2.py
  python3 scripts/codex-sprint/evolve_v2.py --repo-root /home/luce/apps/loki-logging --out temp/codex-sprint
"""
    ap = argparse.ArgumentParser(
        description=(
            "Build codex-sprint evolution v2 with append-only indexes and "
            "flattened artifact blobs."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog,
    )
    ap.add_argument(
        "--repo-root",
        default=".",
        help="Repository root used to discover legacy evidence trees (default: current directory).",
    )
    ap.add_argument(
        "--out",
        default="temp/codex-sprint",
        help="Destination root for v2 output (default: temp/codex-sprint).",
    )
    return ap


def main() -> int:
    args = _build_parser().parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_root = Path(args.out).resolve()
    out_root.mkdir(parents=True, exist_ok=True)

    summary = build_v2(repo_root, out_root)
    print(f"v2 complete: runs={summary['source_run_count']} files={summary['copied_files']} out={out_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
