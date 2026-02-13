#!/usr/bin/env python3
"""Canonical codex-sprint evolution builder.

This script replaces the prior phase-specific files (`evolve_v1.py`,
`evolve_v2.py`, `evolve_v3.py`) with one canonical entrypoint.

Phase mapping:
- `1` -> v1: short run IDs + per-prompt state/history + copied run trees
- `2` -> v2: append-only logs + flattened blob copies
- `3` -> v4-flat: single-file append-only indexes (current production model)

Typical usage:
- Build final flat model directly:
  `python3 scripts/codex-sprint/evolve.py --phase 3 --out temp/codex-sprint`
- Execute all phases sequentially (mainly for comparison/debug):
  `python3 scripts/codex-sprint/evolve.py --phase all --clean-between yes`
"""

from __future__ import annotations

import argparse
import hashlib
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

README_FALLBACK = """# codex-sprint (Flat Canonical Layout)

This directory is the compact machine-readable output for codex sprint evidence.

Core files:
- `state.jsonl`: append-only state snapshots per run
- `state.latest.json`: latest state row per prompt slug
- `history.jsonl`: append-only history events
- `runs.jsonl`: append-only run summaries
- `artifacts.jsonl`: append-only artifact index (`sha256`, size, file refs)
- `catalog.json`: prompt/run catalog and file pointers
- `schema.json`: machine-readable layout contract
- `SUMMARY.json`: latest generation summary

Script model:
- Canonical builder is `scripts/codex-sprint/evolve.py`
- Legacy phase-specific names (`evolve_v1.py`, `evolve_v2.py`, `evolve_v3.py`) are deprecated.
"""


def copy_run_tree(src_dir: Path, dst_dir: Path, rel_files: list[str]) -> int:
    """Copy run files while preserving relative paths from source run root."""
    copied = 0
    for rel in rel_files:
        src = src_dir / rel
        dst = dst_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        copied += 1
    return copied


def safe_blob_name(rel_path: str) -> str:
    """Flatten relative paths into filesystem-safe blob names."""
    flattened = rel_path.replace("/", "__")
    flattened = re.sub(r"[^A-Za-z0-9._-]+", "-", flattened)
    return flattened.strip("-") or "artifact.bin"


def sha256_file(path: Path) -> str:
    """Return sha256 digest for a file path."""
    h = hashlib.sha256()
    with path.open("rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def detect_status(src_dir: Path) -> str:
    """Infer run status from known evidence markers."""
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


def render_output_readme() -> str:
    """Return README body from dev template, falling back to built-in text."""
    dev_readme = Path(__file__).resolve().with_name("README.md")
    if dev_readme.is_file():
        return dev_readme.read_text(encoding="utf-8")
    return README_FALLBACK


def build_phase1(repo_root: Path, out_root: Path) -> dict:
    """Build v1 layout: copied run trees + prompt-level state/history files."""
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


def build_phase2(repo_root: Path, out_root: Path) -> dict:
    """Build v2 layout: append logs plus flattened artifact blob copies."""
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
            # Preserve every artifact even when flattened names collide.
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


def build_phase3(repo_root: Path, out_root: Path) -> dict:
    """Build v4-flat layout: single-file append-only indexes."""
    runs = assign_short_run_ids(collect_legacy_runs(repo_root))
    out_root.mkdir(parents=True, exist_ok=True)

    state_log = out_root / "state.jsonl"
    state_latest = out_root / "state.latest.json"
    history_log = out_root / "history.jsonl"
    runs_log = out_root / "runs.jsonl"
    artifacts_log = out_root / "artifacts.jsonl"
    catalog_path = out_root / "catalog.json"
    schema_path = out_root / "schema.json"

    (out_root / "README.md").write_text(render_output_readme(), encoding="utf-8")

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

        history_row = {"event": "run_indexed", **run_summary}
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

        # Artifact index references source files without recopying bytes.
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


PHASE_BUILDERS = {
    "1": ("v1", build_phase1),
    "2": ("v2", build_phase2),
    "3": ("v4-flat", build_phase3),
}


def run_phase(phase: str, repo_root: Path, out_root: Path) -> dict:
    """Run one phase by id and print canonical completion line."""
    version, fn = PHASE_BUILDERS[phase]
    summary = fn(repo_root, out_root)
    if version in ("v1", "v2"):
        print(f"{version} complete: runs={summary['source_run_count']} files={summary['copied_files']} out={out_root}")
    else:
        print(
            "v4-flat complete: "
            f"runs={summary['source_run_count']} indexed_artifacts={summary['indexed_artifacts']} out={out_root}"
        )
    return summary


def _build_parser() -> argparse.ArgumentParser:
    epilog = """Examples:
  python3 scripts/codex-sprint/evolve.py --phase 3
  python3 scripts/codex-sprint/evolve.py --phase 1 --out /tmp/codex-sprint-v1
  python3 scripts/codex-sprint/evolve.py --phase all --clean-between yes --out /tmp/codex-sprint
"""
    ap = argparse.ArgumentParser(
        description=(
            "Canonical codex-sprint evolution builder. "
            "Use --phase 1|2|3 for a single phase or --phase all to run sequentially."
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
        help="Destination root for generated output (default: temp/codex-sprint).",
    )
    ap.add_argument(
        "--phase",
        choices=["1", "2", "3", "all"],
        default="3",
        help="Which phase to run (default: 3, the flat production model).",
    )
    ap.add_argument(
        "--clean-between",
        choices=["yes", "no"],
        default="yes",
        help="When --phase all, remove --out before each phase (default: yes).",
    )
    return ap


def main() -> int:
    args = _build_parser().parse_args()
    repo_root = Path(args.repo_root).resolve()
    out_root = Path(args.out).resolve()

    if args.phase == "all":
        for phase in ("1", "2", "3"):
            if args.clean_between == "yes" and out_root.exists():
                shutil.rmtree(out_root)
            out_root.mkdir(parents=True, exist_ok=True)
            run_phase(phase, repo_root, out_root)
        return 0

    out_root.mkdir(parents=True, exist_ok=True)
    run_phase(args.phase, repo_root, out_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
