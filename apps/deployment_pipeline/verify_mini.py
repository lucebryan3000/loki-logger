#!/usr/bin/env python3
"""Deterministic verifier for deployment_pipeline mini experiment."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml


def read_yaml_frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}
    body = text[4:end]
    data = yaml.safe_load(body)
    return data if isinstance(data, dict) else {}


def parse_log_events(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if not path.is_file():
        return rows
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        if isinstance(obj, dict):
            rows.append(obj)
    return rows


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="verify_mini.py",
        description="Verify mini experiment artifacts, pipeline state, and staged prompt metadata.",
    )
    ap.add_argument("--root", default="apps/deployment_pipeline", help="Experiment root.")
    args = ap.parse_args(argv)

    root = Path(args.root).expanduser().resolve()
    prompts_dir = root / "prompts"
    out_dir = root / "out"

    checks: list[dict[str, Any]] = []

    def add_check(name: str, ok: bool, detail: str) -> None:
        checks.append({"name": name, "ok": ok, "detail": detail})

    p1 = out_dir / "phase1.txt"
    p2 = out_dir / "phase2.txt"

    add_check("phase1_exists", p1.is_file(), str(p1))
    add_check("phase2_exists", p2.is_file(), str(p2))

    if p1.is_file():
        add_check("phase1_content", p1.read_text(encoding="utf-8").strip() == "phase1_ok", p1.read_text(encoding="utf-8").strip())
    if p2.is_file():
        add_check("phase2_content", p2.read_text(encoding="utf-8").strip() == "phase2_ok", p2.read_text(encoding="utf-8").strip())

    log_path = prompts_dir / ".prompt-pipeline.log.jsonl"
    events = parse_log_events(log_path)
    add_check("pipeline_log_exists", log_path.is_file(), str(log_path))
    add_check("pipeline_has_events", len(events) > 0, f"events={len(events)}")
    add_check("pipeline_done", any(e.get("event") == "pipeline_done" for e in events), "pipeline_done event")

    state_path = prompts_dir / ".prompt-pipeline.state"
    state_lines = []
    if state_path.is_file():
        state_lines = [x.strip() for x in state_path.read_text(encoding="utf-8").splitlines() if x.strip()]
    add_check("state_exists", state_path.is_file(), str(state_path))
    add_check("state_has_two", len(state_lines) >= 2, f"count={len(state_lines)}")

    for name in ("prompt-01-mini.md", "prompt-02-mini.md"):
        pp = prompts_dir / name
        fm = read_yaml_frontmatter(pp)
        pf = fm.get("prompt_flow") if isinstance(fm, dict) else {}
        stages = pf.get("stages") if isinstance(pf, dict) else {}

        pre = stages.get("preflight") if isinstance(stages, dict) else {}
        ex = stages.get("exec") if isinstance(stages, dict) else {}
        pipe = stages.get("pipeline") if isinstance(stages, dict) else {}

        add_check(f"{name}:preflight_ready", str(pre.get("ready", "")).lower() == "yes", str(pre.get("ready", "")))
        add_check(f"{name}:exec_success", str(ex.get("status", "")).lower() == "success", str(ex.get("status", "")))
        add_check(f"{name}:pipeline_status", str(pipe.get("status", "")).lower() in {"success", "done"}, str(pipe.get("status", "")))

    ok = all(c["ok"] for c in checks)
    summary = {
        "root": str(root),
        "ok": ok,
        "checks": checks,
    }
    print(json.dumps(summary, indent=2, ensure_ascii=True))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
