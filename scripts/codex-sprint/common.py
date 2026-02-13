#!/usr/bin/env python3
"""Common utilities for codex-sprint evolution/recall tooling.

This module is intentionally importable by other scripts and also executable as a
standalone helper for quick diagnostics.

Primary responsibilities:
- Discover legacy run trees from `temp/codex/...` and `temp/.artifacts/...`
- Normalize prompt labels into stable slugs
- Assign short run IDs (`rNNNN`) per prompt slug
- Write JSON / JSONL payloads deterministically
- Compute simple tree metrics for footprint comparisons

CLI quick use:
- `python3 common.py summary --repo-root /path/to/repo`
- `python3 common.py list-runs --prompt loki-prompt-13 --limit 10`
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

TS_RE = re.compile(r"(\d{8}T\d{6}Z?)")


@dataclass
class LegacyRun:
    source_family: str
    source_root: str
    source_prompt_label: str
    source_run_label: str
    source_run_path: str
    prompt_slug: str
    sort_epoch: float
    file_count: int
    total_bytes: int
    files: list[str]
    run_seq: int = 0
    run_id: str = ""
    run_key: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class TreeMetrics:
    dirs: int
    files: int
    small_files_le_120b: int
    max_depth: int

    def to_dict(self) -> dict:
        return asdict(self)


def slugify(raw: str) -> str:
    """Convert arbitrary labels into lowercase filesystem-safe slugs."""
    s = re.sub(r"[^a-z0-9]+", "-", raw.lower())
    s = re.sub(r"-+", "-", s).strip("-")
    return s or "unknown"


def parse_run_sort_epoch(run_name: str, run_dir: Path) -> float:
    """Best-effort timestamp extraction from run folder names.

    We prioritize encoded UTC timestamps in folder names; if absent, we fall back
    to directory mtime.
    """
    m = TS_RE.search(run_name)
    if m:
        raw = m.group(1)
        for fmt in ("%Y%m%dT%H%M%SZ", "%Y%m%dT%H%M%S"):
            try:
                dt = datetime.strptime(raw, fmt).replace(tzinfo=timezone.utc)
                return dt.timestamp()
            except ValueError:
                pass
    try:
        return run_dir.stat().st_mtime
    except OSError:
        return 0.0


def list_files(run_dir: Path) -> tuple[list[str], int]:
    """Return sorted file list (relative paths) and total byte size for a run."""
    files: list[str] = []
    total = 0
    for p in sorted(run_dir.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(run_dir).as_posix()
        files.append(rel)
        try:
            total += p.stat().st_size
        except OSError:
            pass
    return files, total


def detect_prism_prompt_slug(run_dir: Path) -> str:
    """Infer prompt slug for prism evidence directories from early NDJSON entries."""
    events = run_dir / "events.ndjson"
    if events.is_file():
        try:
            for line in events.read_text(encoding="utf-8", errors="ignore").splitlines()[:24]:
                if not line.strip().startswith("{"):
                    continue
                obj = json.loads(line)
                for key in ("prompt_name", "prompt"):
                    value = obj.get(key)
                    if value is None:
                        continue
                    text = str(value).strip()
                    if not text:
                        continue
                    if text.isdigit():
                        return f"prompt-{text}"
                    return slugify(text)
        except (OSError, json.JSONDecodeError):
            pass
    return "prism"


def collect_legacy_runs(repo_root: Path) -> list[LegacyRun]:
    """Collect legacy runs from both codex and prism evidence roots."""
    runs: list[LegacyRun] = []

    codex_roots = [
        repo_root / "temp" / "codex" / "evidence",
        repo_root / "temp" / "codex" / "codex" / "evidence",
    ]
    for root in codex_roots:
        if not root.is_dir():
            continue
        for prompt_dir in sorted(root.iterdir()):
            if not prompt_dir.is_dir():
                continue
            prompt_label = prompt_dir.name
            prompt_slug = slugify(prompt_label)
            for run_dir in sorted(prompt_dir.iterdir()):
                if not run_dir.is_dir():
                    continue
                files, total_bytes = list_files(run_dir)
                runs.append(
                    LegacyRun(
                        source_family="codex",
                        source_root=str(root),
                        source_prompt_label=prompt_label,
                        source_run_label=run_dir.name,
                        source_run_path=str(run_dir),
                        prompt_slug=prompt_slug,
                        sort_epoch=parse_run_sort_epoch(run_dir.name, run_dir),
                        file_count=len(files),
                        total_bytes=total_bytes,
                        files=files,
                    )
                )

    prism_root = repo_root / "temp" / ".artifacts" / "prism" / "evidence"
    if prism_root.is_dir():
        for run_dir in sorted(prism_root.iterdir()):
            if not run_dir.is_dir():
                continue
            prompt_slug = detect_prism_prompt_slug(run_dir)
            files, total_bytes = list_files(run_dir)
            runs.append(
                LegacyRun(
                    source_family="prism",
                    source_root=str(prism_root),
                    source_prompt_label="prism",
                    source_run_label=run_dir.name,
                    source_run_path=str(run_dir),
                    prompt_slug=prompt_slug,
                    sort_epoch=parse_run_sort_epoch(run_dir.name, run_dir),
                    file_count=len(files),
                    total_bytes=total_bytes,
                    files=files,
                )
            )

    runs.sort(key=lambda r: (r.prompt_slug, r.sort_epoch, r.source_run_label, r.source_run_path))
    return runs


def assign_short_run_ids(runs: Iterable[LegacyRun]) -> list[LegacyRun]:
    """Assign deterministic `rNNNN` IDs per prompt slug in chronological order."""
    counters: dict[str, int] = {}
    out: list[LegacyRun] = []
    for run in runs:
        counters[run.prompt_slug] = counters.get(run.prompt_slug, 0) + 1
        run_seq = counters[run.prompt_slug]
        run.run_seq = run_seq
        run.run_id = f"r{run_seq:04d}"
        run.run_key = f"{run.prompt_slug}--{run.run_id}"
        out.append(run)
    return out


def append_jsonl(path: Path, obj: dict) -> None:
    """Append one JSON object per line to path (creates parent dirs)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(obj, ensure_ascii=True, sort_keys=True) + "\n")


def write_json(path: Path, obj: dict | list) -> None:
    """Write canonical pretty JSON with trailing newline."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=True, sort_keys=False) + "\n", encoding="utf-8")


def tree_metrics(root: Path) -> TreeMetrics:
    """Compute simple footprint stats for a directory tree."""
    dirs = 0
    files = 0
    small = 0
    max_depth = 0
    if not root.exists():
        return TreeMetrics(dirs=0, files=0, small_files_le_120b=0, max_depth=0)

    base_parts = len(root.resolve().parts)
    for p in root.rglob("*"):
        depth = len(p.resolve().parts) - base_parts + 1
        if depth > max_depth:
            max_depth = depth
        if p.is_dir():
            dirs += 1
        elif p.is_file():
            files += 1
            try:
                if p.stat().st_size <= 120:
                    small += 1
            except OSError:
                pass

    return TreeMetrics(dirs=dirs, files=files, small_files_le_120b=small, max_depth=max_depth)


def now_utc_iso() -> str:
    """Current UTC timestamp in compact ISO format used across outputs."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ----- Optional CLI for diagnostics ------------------------------------------------------------

def _cmd_summary(repo_root: Path) -> int:
    runs = assign_short_run_ids(collect_legacy_runs(repo_root))
    prompt_counts: dict[str, int] = {}
    family_counts: dict[str, int] = {}
    for run in runs:
        prompt_counts[run.prompt_slug] = prompt_counts.get(run.prompt_slug, 0) + 1
        family_counts[run.source_family] = family_counts.get(run.source_family, 0) + 1

    payload = {
        "repo_root": str(repo_root),
        "run_count": len(runs),
        "prompt_count": len(prompt_counts),
        "source_families": family_counts,
        "top_prompts": [
            {"prompt_slug": k, "runs": prompt_counts[k]}
            for k in sorted(prompt_counts.keys(), key=lambda x: (-prompt_counts[x], x))[:20]
        ],
    }
    print(json.dumps(payload, indent=2, ensure_ascii=True, sort_keys=False))
    return 0


def _cmd_list_runs(repo_root: Path, prompt_filter: str, limit: int) -> int:
    runs = assign_short_run_ids(collect_legacy_runs(repo_root))
    emitted = 0
    for run in runs:
        if prompt_filter and prompt_filter not in run.prompt_slug:
            continue
        print(json.dumps(run.to_dict(), ensure_ascii=True, sort_keys=True))
        emitted += 1
        if emitted >= limit:
            break
    return 0


def _build_parser() -> argparse.ArgumentParser:
    epilog = """Examples:
  python3 common.py summary --repo-root /home/luce/apps/loki-logging
  python3 common.py list-runs --prompt loki-prompt-13 --limit 10
"""
    p = argparse.ArgumentParser(
        description="Common utilities for codex-sprint evolution tooling.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog,
    )
    p.add_argument("--repo-root", default=".", help="Repository root (default: current directory)")

    sp = p.add_subparsers(dest="cmd", required=True)
    sp.add_parser("summary", help="Print run/prompt summary from legacy evidence roots")

    p_runs = sp.add_parser("list-runs", help="Print discovered runs as JSON lines")
    p_runs.add_argument("--prompt", default="", help="Optional prompt slug substring filter")
    p_runs.add_argument("--limit", type=int, default=200, help="Max number of rows to print")
    return p


def main(argv: list[str]) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    repo_root = Path(args.repo_root).resolve()

    if args.cmd == "summary":
        return _cmd_summary(repo_root)
    if args.cmd == "list-runs":
        return _cmd_list_runs(repo_root, args.prompt.strip().lower(), max(1, args.limit))
    return 2


if __name__ == "__main__":
    import sys

    raise SystemExit(main(sys.argv[1:]))
