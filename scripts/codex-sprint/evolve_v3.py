#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from common import (
    append_jsonl,
    assign_short_run_ids,
    collect_legacy_runs,
    now_utc_iso,
    tree_metrics,
    write_json,
)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def detect_status(src_dir: Path) -> str:
    manifest = src_dir / "manifest.txt"
    if manifest.is_file():
        text = manifest.read_text(encoding="utf-8", errors="ignore")
        if "status=success" in text:
            return "success"
        if "status=failed" in text or "FAILED:" in text:
            return "failed"
        if "status=blocked" in text:
            return "blocked"

    events = src_dir / "events.ndjson"
    if events.is_file():
        text = events.read_text(encoding="utf-8", errors="ignore")
        if '"type":"fail"' in text:
            return "failed"
        if '"type":"pass"' in text:
            return "success"

    return "unknown"


def build_v3(repo_root: Path, out_root: Path) -> dict:
    runs = assign_short_run_ids(collect_legacy_runs(repo_root))
    out_root.mkdir(parents=True, exist_ok=True)

    state_log = out_root / "state.jsonl"
    state_latest = out_root / "state.latest.json"
    history_log = out_root / "history.jsonl"
    runs_log = out_root / "runs.jsonl"
    artifacts_log = out_root / "artifacts.jsonl"
    catalog_path = out_root / "catalog.json"
    schema_path = out_root / "schema.json"

    readme = """# codex-sprint v4 (Flat)

Compact machine-readable evidence layout with append-only single-file indexes.

- `state.jsonl`: append-only state snapshots per run
- `state.latest.json`: latest state per prompt slug
- `history.jsonl`: append-only history events
- `runs.jsonl`: append-only run summaries
- `artifacts.jsonl`: append-only artifact index (sha256 + size + file name)
- `catalog.json`: compact prompt/run catalog
- `schema.json`: machine-readable layout contract
"""
    (out_root / "README.md").write_text(readme, encoding="utf-8")

    write_json(
        schema_path,
        {
            "version": "v4-flat",
            "created_utc": now_utc_iso(),
            "short_run_id_format": "rNNNN (per prompt sequence)",
            "layout": {
                "state_log": "state.jsonl",
                "state_latest": "state.latest.json",
                "history_log": "history.jsonl",
                "runs_log": "runs.jsonl",
                "artifact_index": "artifacts.jsonl",
                "catalog": "catalog.json",
            },
        },
    )

    prompt_stats: dict[str, dict] = {}
    state_latest_map: dict[str, dict] = {}
    indexed_artifacts = 0

    for run in runs:
        src_dir = Path(run.source_run_path)
        status = detect_status(src_dir)
        run_ref = f"runs.jsonl#{run.run_key}"
        indexed_utc = now_utc_iso()

        run_summary = {
            "prompt_slug": run.prompt_slug,
            "run_id": run.run_id,
            "run_seq": run.run_seq,
            "run_key": run.run_key,
            "run_ref": run_ref,
            "status": status,
            "source_family": run.source_family,
            "source_prompt_label": run.source_prompt_label,
            "source_run_label": run.source_run_label,
            "source_run_path": run.source_run_path,
            "file_count": run.file_count,
            "total_bytes": run.total_bytes,
            "indexed_utc": indexed_utc,
        }
        append_jsonl(runs_log, run_summary)

        history_row = {
            "event": "run_indexed",
            **run_summary,
        }
        append_jsonl(history_log, history_row)

        state_row = {
            "prompt_slug": run.prompt_slug,
            "run_id": run.run_id,
            "run_seq": run.run_seq,
            "run_key": run.run_key,
            "run_ref": run_ref,
            "status": status,
            "indexed_utc": indexed_utc,
        }
        append_jsonl(state_log, state_row)
        state_latest_map[run.prompt_slug] = state_row

        for rel in run.files:
            src = src_dir / rel
            artifact_entry = {
                "prompt_slug": run.prompt_slug,
                "run_id": run.run_id,
                "run_seq": run.run_seq,
                "run_key": run.run_key,
                "run_ref": run_ref,
                "file_name": Path(rel).name,
                "rel_path": rel,
                "source_abs": str(src),
                "bytes": src.stat().st_size,
                "sha256": sha256_file(src),
                "indexed_utc": indexed_utc,
            }
            append_jsonl(artifacts_log, artifact_entry)
            indexed_artifacts += 1

        stats = prompt_stats.setdefault(
            run.prompt_slug,
            {
                "prompt_slug": run.prompt_slug,
                "run_count": 0,
                "total_files": 0,
                "total_bytes": 0,
                "last_run_id": "",
                "last_status": "",
                "source_families": set(),
            },
        )
        stats["run_count"] += 1
        stats["total_files"] += run.file_count
        stats["total_bytes"] += run.total_bytes
        stats["last_run_id"] = run.run_id
        stats["last_status"] = status
        stats["source_families"].add(run.source_family)

    prompt_rows = []
    for slug in sorted(prompt_stats.keys()):
        row = prompt_stats[slug]
        row["source_families"] = sorted(row["source_families"])
        prompt_rows.append(row)

    write_json(
        state_latest,
        {
            "updated_utc": now_utc_iso(),
            "prompts": {k: state_latest_map[k] for k in sorted(state_latest_map.keys())},
        },
    )

    write_json(
        catalog_path,
        {
            "version": "v4-flat",
            "created_utc": now_utc_iso(),
            "prompt_count": len(prompt_rows),
            "run_count": len(runs),
            "indexed_artifacts": indexed_artifacts,
            "prompts": prompt_rows,
            "files": {
                "state_log": str(state_log),
                "state_latest": str(state_latest),
                "history_log": str(history_log),
                "runs_log": str(runs_log),
                "artifact_index": str(artifacts_log),
            },
        },
    )

    metrics = tree_metrics(out_root)
    summary = {
        "evolution": "v4-flat",
        "created_utc": now_utc_iso(),
        "source_run_count": len(runs),
        "source_prompt_count": len(prompt_rows),
        "indexed_artifacts": indexed_artifacts,
        "artifact_index_path": str(artifacts_log),
        "output_metrics": metrics.to_dict(),
    }
    write_json(out_root / "SUMMARY.json", summary)
    return summary


def main() -> int:
    ap = argparse.ArgumentParser(description="Build codex-sprint evolution v4-flat")
    ap.add_argument("--repo-root", default=".", help="Repo root")
    ap.add_argument("--out", default="temp/codex-sprint", help="Output root")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_root = Path(args.out).resolve()
    out_root.mkdir(parents=True, exist_ok=True)

    summary = build_v3(repo_root, out_root)
    print(
        "v4-flat complete: "
        f"runs={summary['source_run_count']} indexed_artifacts={summary['indexed_artifacts']} out={out_root}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
