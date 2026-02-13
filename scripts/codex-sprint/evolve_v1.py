#!/usr/bin/env python3
from __future__ import annotations

import argparse
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


def copy_run_tree(src_dir: Path, dst_dir: Path, rel_files: list[str]) -> int:
    copied = 0
    for rel in rel_files:
        src = src_dir / rel
        dst = dst_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        copied += 1
    return copied


def build_v1(repo_root: Path, out_root: Path) -> dict:
    runs = assign_short_run_ids(collect_legacy_runs(repo_root))

    (out_root / "catalog").mkdir(parents=True, exist_ok=True)
    (out_root / "prompts").mkdir(parents=True, exist_ok=True)
    (out_root / "runs").mkdir(parents=True, exist_ok=True)

    write_json(
        out_root / "catalog" / "schema.json",
        {
            "version": "v1",
            "created_utc": now_utc_iso(),
            "layout": {
                "runs": "runs/<prompt-slug>--<rNNNN>/",
                "prompt_state": "prompts/<prompt-slug>/state.json",
                "prompt_history": "prompts/<prompt-slug>/history.jsonl",
                "global_run_log": "catalog/runs.jsonl",
            },
            "notes": [
                "Short run ids replace timestamp folder names.",
                "Prompt state and history are machine-readable append targets.",
            ],
        },
    )

    prompt_counts: dict[str, int] = {}
    copied_files = 0

    for run in runs:
        src_dir = Path(run.source_run_path)
        run_dir = out_root / "runs" / run.run_key
        run_dir.mkdir(parents=True, exist_ok=True)

        copied_files += copy_run_tree(src_dir, run_dir, run.files)

        run_record = {
            "prompt_slug": run.prompt_slug,
            "run_id": run.run_id,
            "run_seq": run.run_seq,
            "run_key": run.run_key,
            "source_family": run.source_family,
            "source_prompt_label": run.source_prompt_label,
            "source_run_label": run.source_run_label,
            "source_run_path": run.source_run_path,
            "target_run_path": str(run_dir),
            "file_count": run.file_count,
            "total_bytes": run.total_bytes,
            "indexed_utc": now_utc_iso(),
        }

        append_jsonl(out_root / "catalog" / "runs.jsonl", run_record)
        append_jsonl(out_root / "prompts" / run.prompt_slug / "history.jsonl", run_record)
        write_json(out_root / "prompts" / run.prompt_slug / "state.json", run_record)

        prompt_counts[run.prompt_slug] = prompt_counts.get(run.prompt_slug, 0) + 1

    write_json(
        out_root / "catalog" / "prompts.json",
        {
            "created_utc": now_utc_iso(),
            "prompt_count": len(prompt_counts),
            "run_count": len(runs),
            "runs_per_prompt": dict(sorted(prompt_counts.items())),
        },
    )

    metrics = tree_metrics(out_root)
    summary = {
        "evolution": "v1",
        "created_utc": now_utc_iso(),
        "source_run_count": len(runs),
        "source_prompt_count": len(prompt_counts),
        "copied_files": copied_files,
        "output_metrics": metrics.to_dict(),
    }
    write_json(out_root / "SUMMARY.json", summary)
    return summary


def main() -> int:
    ap = argparse.ArgumentParser(description="Build codex-sprint evolution v1")
    ap.add_argument("--repo-root", default=".", help="Repo root")
    ap.add_argument("--out", default="temp/codex-sprint", help="Output root")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_root = Path(args.out).resolve()
    out_root.mkdir(parents=True, exist_ok=True)

    summary = build_v1(repo_root, out_root)
    print(f"v1 complete: runs={summary['source_run_count']} files={summary['copied_files']} out={out_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
