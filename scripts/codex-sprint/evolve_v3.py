#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
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

HIGH_SIGNAL_BASENAMES = {
    "manifest.txt",
    "completion_gate.json",
    "events.ndjson",
    "exec.log",
    "prompt.md",
    "env.sh",
    "warnings.txt",
    "summary.txt",
    "prom_ready.txt",
    "grafana_health.json",
    "git.status.txt",
    "git.head.txt",
    "git.diff.names.txt",
    "git.diff.cached.names.txt",
}


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


def should_copy(rel_path: str) -> bool:
    base = Path(rel_path).name
    if base in HIGH_SIGNAL_BASENAMES:
        return True
    if rel_path.startswith("out/block001"):
        return True
    return False


def build_v3(repo_root: Path, out_root: Path) -> dict:
    runs = assign_short_run_ids(collect_legacy_runs(repo_root))

    for d in ("state", "history", "runs", "catalog", "artifacts"):
        (out_root / d).mkdir(parents=True, exist_ok=True)

    readme = """# codex-sprint v3

Compact machine-readable evidence layout.

- `state/<slug>.jsonl`: append-only state snapshots per run
- `state/<slug>.latest.json`: latest state snapshot for quick reads
- `history/<slug>.jsonl`: append-only run summaries per prompt
- `history/all-runs.jsonl`: append-only global run summaries
- `runs/<slug>--<rNNNN>/`: focused run bundle with high-signal files + artifact manifest
- `artifacts/<slug>.jsonl`: append-only artifact index (sha256 + size + source path)
- `catalog/prompts.json`: compact query index for prompts and counts
"""
    (out_root / "README.md").write_text(readme, encoding="utf-8")

    write_json(
        out_root / "catalog" / "schema.json",
        {
            "version": "v3",
            "created_utc": now_utc_iso(),
            "short_run_id_format": "rNNNN (per prompt sequence)",
            "layout": {
                "state_log": "state/<slug>.jsonl",
                "state_latest": "state/<slug>.latest.json",
                "history_prompt": "history/<slug>.jsonl",
                "history_global": "history/all-runs.jsonl",
                "run_bundle": "runs/<slug>--<rNNNN>/",
                "artifact_index": "artifacts/<slug>.jsonl",
                "catalog": "catalog/prompts.json",
            },
        },
    )

    prompt_stats: dict[str, dict] = {}
    indexed_artifacts = 0
    copied_high_signal_files = 0

    for run in runs:
        src_dir = Path(run.source_run_path)
        run_bundle = out_root / "runs" / run.run_key
        run_bundle.mkdir(parents=True, exist_ok=True)

        artifact_manifest: list[dict] = []
        for rel in run.files:
            src = src_dir / rel
            size = src.stat().st_size
            digest = sha256_file(src)

            copied_rel = ""
            if should_copy(rel):
                dst = run_bundle / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
                copied_rel = rel
                copied_high_signal_files += 1

            artifact_entry = {
                "prompt_slug": run.prompt_slug,
                "run_id": run.run_id,
                "run_key": run.run_key,
                "source_rel": rel,
                "source_abs": str(src),
                "bytes": size,
                "sha256": digest,
                "copied_rel": copied_rel,
            }
            artifact_manifest.append(artifact_entry)
            append_jsonl(out_root / "artifacts" / f"{run.prompt_slug}.jsonl", artifact_entry)
            indexed_artifacts += 1

        status = detect_status(src_dir)
        run_summary = {
            "prompt_slug": run.prompt_slug,
            "run_id": run.run_id,
            "run_seq": run.run_seq,
            "run_key": run.run_key,
            "status": status,
            "source_family": run.source_family,
            "source_prompt_label": run.source_prompt_label,
            "source_run_label": run.source_run_label,
            "source_run_path": run.source_run_path,
            "run_bundle_path": str(run_bundle),
            "file_count": run.file_count,
            "total_bytes": run.total_bytes,
            "copied_high_signal_file_count": sum(1 for a in artifact_manifest if a["copied_rel"]),
            "indexed_utc": now_utc_iso(),
        }

        write_json(run_bundle / "run.json", run_summary)
        write_json(run_bundle / "artifacts.manifest.json", {"entries": artifact_manifest})

        append_jsonl(out_root / "history" / "all-runs.jsonl", run_summary)
        append_jsonl(out_root / "history" / f"{run.prompt_slug}.jsonl", run_summary)
        append_jsonl(out_root / "state" / f"{run.prompt_slug}.jsonl", run_summary)
        write_json(out_root / "state" / f"{run.prompt_slug}.latest.json", run_summary)

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
        out_root / "catalog" / "prompts.json",
        {
            "created_utc": now_utc_iso(),
            "prompt_count": len(prompt_rows),
            "run_count": len(runs),
            "indexed_artifacts": indexed_artifacts,
            "prompts": prompt_rows,
        },
    )

    metrics = tree_metrics(out_root)
    summary = {
        "evolution": "v3",
        "created_utc": now_utc_iso(),
        "source_run_count": len(runs),
        "source_prompt_count": len(prompt_rows),
        "indexed_artifacts": indexed_artifacts,
        "copied_high_signal_files": copied_high_signal_files,
        "output_metrics": metrics.to_dict(),
    }
    write_json(out_root / "SUMMARY.json", summary)
    return summary


def main() -> int:
    ap = argparse.ArgumentParser(description="Build codex-sprint evolution v3")
    ap.add_argument("--repo-root", default=".", help="Repo root")
    ap.add_argument("--out", default="temp/codex-sprint", help="Output root")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    out_root = Path(args.out).resolve()
    out_root.mkdir(parents=True, exist_ok=True)

    summary = build_v3(repo_root, out_root)
    print(
        "v3 complete: "
        f"runs={summary['source_run_count']} indexed_artifacts={summary['indexed_artifacts']} out={out_root}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
