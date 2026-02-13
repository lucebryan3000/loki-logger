#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from dataclasses import dataclass, asdict
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
    s = re.sub(r"[^a-z0-9]+", "-", raw.lower())
    s = re.sub(r"-+", "-", s).strip("-")
    return s or "unknown"


def parse_run_sort_epoch(run_name: str, run_dir: Path) -> float:
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
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(obj, ensure_ascii=True, sort_keys=True) + "\n")


def write_json(path: Path, obj: dict | list) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=True, sort_keys=False) + "\n", encoding="utf-8")


def tree_metrics(root: Path) -> TreeMetrics:
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
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
