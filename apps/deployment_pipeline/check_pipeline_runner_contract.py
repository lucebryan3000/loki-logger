#!/usr/bin/env python3
"""Deterministic regression checks for prompt-pipeline runner behavior.

Goals:
- catch contract drift quickly (flags/help/output artifacts)
- validate deterministic execution path (`--exec-mode script`)
- validate range slicing and hold-summary behavior

No LLM work, no prompt rewriting, no repo state dependency.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path


def run(cmd: list[str], timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def write_prompt(path: Path, label: str) -> None:
    path.write_text(
        f"# {label}\n\n```bash\necho {label}\n```\n",
        encoding="utf-8",
    )


def check_help_flags(pipeline_script: str) -> tuple[bool, str]:
    cp = run([pipeline_script, "--help"], timeout=30)
    if cp.returncode != 0:
        return False, f"help_returncode={cp.returncode}"
    output = (cp.stdout or "") + (cp.stderr or "")
    required = ["--exec-mode", "--from", "--to", "--prompts-file", ".prompt-pipeline.summary.json"]
    missing = [token for token in required if token not in output]
    if missing:
        return False, f"help_missing={','.join(missing)}"
    return True, "ok"


def check_script_mode_summary(pipeline_script: str) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="pipeline-contract-smoke-") as td:
        root = Path(td)
        write_prompt(root / "prompt-01.md", "phase1")
        cp = run(
            [
                pipeline_script,
                "--root",
                str(root),
                "--count",
                "1",
                "--max-retries",
                "0",
                "--timeout-sec",
                "60",
                "--exec-mode",
                "script",
            ],
            timeout=180,
        )
        if cp.returncode != 0:
            return False, f"script_mode_returncode={cp.returncode}"
        summary_path = root / ".prompt-pipeline.summary.json"
        if not summary_path.is_file():
            return False, "summary_missing"
        try:
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
        except Exception as exc:
            return False, f"summary_parse_error={exc}"
        if summary.get("status") != "done":
            return False, f"summary_status={summary.get('status')}"
        if summary.get("runner_mode") != "script":
            return False, f"summary_runner_mode={summary.get('runner_mode')}"
        if int(summary.get("ran", 0)) != 1:
            return False, f"summary_ran={summary.get('ran')}"
        return True, "ok"


def check_range_slice(pipeline_script: str) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="pipeline-contract-range-") as td:
        root = Path(td)
        write_prompt(root / "prompt-01.md", "p1")
        write_prompt(root / "prompt-02.md", "p2")
        write_prompt(root / "prompt-03.md", "p3")
        cp = run(
            [
                pipeline_script,
                "--root",
                str(root),
                "--from",
                "prompt-02.md",
                "--to",
                "prompt-03.md",
                "--count",
                "0",
                "--max-retries",
                "0",
                "--timeout-sec",
                "30",
                "--exec-mode",
                "script",
            ],
            timeout=120,
        )
        if cp.returncode != 0:
            return False, f"range_returncode={cp.returncode}"
        plan = (root / ".prompt-pipeline.plan.txt").read_text(encoding="utf-8").strip().splitlines()
        names = [Path(p).name for p in plan if p.strip()]
        if names != ["prompt-02.md", "prompt-03.md"]:
            return False, f"range_plan={names}"
        return True, "ok"


def check_hold_summary(pipeline_script: str) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="pipeline-contract-hold-") as td:
        root = Path(td)
        write_prompt(root / "prompt-01.md", "hold")
        missing_go = root / "GO.token"
        cp = run(
            [
                pipeline_script,
                "--root",
                str(root),
                "--count",
                "1",
                "--max-retries",
                "0",
                "--timeout-sec",
                "30",
                "--exec-mode",
                "script",
                "--require-go",
                str(missing_go),
            ],
            timeout=120,
        )
        if cp.returncode != 13:
            return False, f"hold_returncode={cp.returncode}"
        summary_path = root / ".prompt-pipeline.summary.json"
        if not summary_path.is_file():
            return False, "hold_summary_missing"
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        if summary.get("status") != "hold":
            return False, f"hold_status={summary.get('status')}"
        reason = str(summary.get("reason", ""))
        if "go_missing" not in reason:
            return False, f"hold_reason={reason}"
        return True, "ok"


def main() -> int:
    ap = argparse.ArgumentParser(
        prog="check_pipeline_runner_contract.py",
        description="Regression checks for prompt-pipeline runner/summary/range behavior.",
    )
    ap.add_argument(
        "--pipeline-script",
        default="/home/luce/.codex/skills/prompt-pipeline/scripts/prompt_pipeline.sh",
        help="Absolute path to prompt_pipeline.sh.",
    )
    ap.add_argument("--json", action="store_true", help="Emit JSON summary.")
    args = ap.parse_args()

    checks = []
    for name, fn in [
        ("help_flags", check_help_flags),
        ("script_mode_summary", check_script_mode_summary),
        ("range_slice", check_range_slice),
        ("hold_summary", check_hold_summary),
    ]:
        ok, detail = fn(args.pipeline_script)
        checks.append({"name": name, "ok": ok, "detail": detail})

    ok = all(c["ok"] for c in checks)
    summary = {"ok": ok, "pipeline_script": args.pipeline_script, "checks": checks}

    if args.json:
        print(json.dumps(summary, indent=2, ensure_ascii=True))
    else:
        print(f"pipeline_script={args.pipeline_script}")
        print(f"ok={ok}")
        for c in checks:
            print(f"- {c['name']}: {'PASS' if c['ok'] else 'FAIL'} ({c['detail']})")

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
