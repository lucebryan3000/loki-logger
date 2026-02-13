#!/usr/bin/env python3
"""Canonical codex-sprint command entrypoint.

This wrapper keeps mechanics deterministic:
- load/validate one config contract
- dispatch deterministic script calls for build/verify/sync/recall
- avoid embedding complex planning logic in shell scripts
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG = SCRIPT_DIR / "codex_sprint.config.json"


def _read_config(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"missing config file: {path}")
    obj = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(obj, dict):
        raise ValueError("config must be a JSON object")
    return obj


def _require_str(obj: dict[str, Any], key: str) -> str:
    value = obj.get(key)
    if not isinstance(value, str):
        raise ValueError(f"config key `{key}` must be a string")
    return value


def _require_section(obj: dict[str, Any], key: str) -> dict[str, Any]:
    value = obj.get(key)
    if not isinstance(value, dict):
        raise ValueError(f"config section `{key}` must be an object")
    return value


def _validate_config(cfg: dict[str, Any]) -> None:
    if cfg.get("version") != "v1":
        raise ValueError("config version must be `v1`")
    _require_str(cfg, "repo_root")
    _require_str(cfg, "out_dir")
    _require_str(cfg, "phase_log_dir")

    build = _require_section(cfg, "build")
    for key in ("phase", "atomic", "incremental", "clean_between", "ledger_path"):
        _require_str(build, key)

    verify = _require_section(cfg, "verify")
    for key in ("phase", "dev_readme"):
        _require_str(verify, key)

    sync = _require_section(cfg, "sync")
    for key in ("mode", "prune", "allowlist"):
        _require_str(sync, key)

    recall = _require_section(cfg, "recall")
    _require_str(recall, "root")


def _resolve_path(repo_root: Path, value: str) -> Path:
    p = Path(value)
    if p.is_absolute():
        return p.resolve()
    return (repo_root / p).resolve()


def _run(cmd: list[str]) -> int:
    proc = subprocess.run(cmd, check=False)
    return proc.returncode


def _build_parser() -> argparse.ArgumentParser:
    epilog = """Examples:
  python3 scripts/codex-sprint/codex_sprint.py build
  python3 scripts/codex-sprint/codex_sprint.py verify --phase 3
  python3 scripts/codex-sprint/codex_sprint.py sync --mode all
  python3 scripts/codex-sprint/codex_sprint.py recall find --index runs --status failed --limit 10
"""
    ap = argparse.ArgumentParser(
        description=(
            "Canonical codex-sprint CLI using validated config defaults. "
            "Subcommands dispatch deterministic mechanics; LLM handles planning decisions."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog,
    )
    ap.add_argument("--config", default=str(DEFAULT_CONFIG), help="Config JSON path.")

    sub = ap.add_subparsers(dest="cmd", required=True)

    p_build = sub.add_parser("build", help="Run evolve builder with config defaults.")
    p_build.add_argument("--phase", choices=["1", "2", "3", "all"], default=None)
    p_build.add_argument("--atomic", choices=["yes", "no"], default=None)
    p_build.add_argument("--incremental", choices=["yes", "no"], default=None)
    p_build.add_argument("--clean-between", choices=["yes", "no"], default=None)
    p_build.add_argument("--out", default=None, help="Override output root.")
    p_build.add_argument("--ledger-path", default=None, help="Override ledger path.")

    p_verify = sub.add_parser("verify", help="Verify output contracts and integrity.")
    p_verify.add_argument("--phase", choices=["1", "2", "3", "all"], default=None)
    p_verify.add_argument("--root", default=None, help="Override verify root.")

    p_sync = sub.add_parser("sync", help="Sync canonical scripts/docs to temp output root.")
    p_sync.add_argument("--mode", choices=["helpers", "all"], default=None)
    p_sync.add_argument("--prod-root", default=None, help="Override destination root.")
    p_sync.add_argument("--allowlist", default=None, help="Override allowlist path.")
    p_sync.add_argument("--no-prune", action="store_true", help="Disable stale-file pruning.")

    p_recall = sub.add_parser("recall", help="Dispatch to recall helper.")
    p_recall.add_argument("recall_args", nargs=argparse.REMAINDER, help="Arguments passed to codex_sprint_recall.py")
    return ap


def main(argv: list[str]) -> int:
    args = _build_parser().parse_args(argv)
    cfg_path = Path(args.config).resolve()
    cfg = _read_config(cfg_path)
    _validate_config(cfg)

    repo_root = Path(cfg["repo_root"]).resolve()
    out_dir = _resolve_path(repo_root, cfg["out_dir"])
    build_cfg = cfg["build"]
    verify_cfg = cfg["verify"]
    sync_cfg = cfg["sync"]
    recall_cfg = cfg["recall"]

    if args.cmd == "build":
        cmd = [
            "python3",
            str(SCRIPT_DIR / "evolve.py"),
            "--repo-root",
            str(repo_root),
            "--out",
            str(_resolve_path(repo_root, args.out) if args.out else out_dir),
            "--phase",
            str(args.phase or build_cfg["phase"]),
            "--atomic",
            str(args.atomic or build_cfg["atomic"]),
            "--incremental",
            str(args.incremental or build_cfg["incremental"]),
            "--clean-between",
            str(args.clean_between or build_cfg["clean_between"]),
        ]
        ledger_path = args.ledger_path if args.ledger_path is not None else build_cfg["ledger_path"]
        if ledger_path:
            cmd.extend(["--ledger-path", str(_resolve_path(repo_root, ledger_path))])
        return _run(cmd)

    if args.cmd == "verify":
        cmd = [
            "python3",
            str(SCRIPT_DIR / "verify.py"),
            "--root",
            str(_resolve_path(repo_root, args.root) if args.root else out_dir),
            "--phase",
            str(args.phase or verify_cfg["phase"]),
            "--dev-readme",
            str(_resolve_path(repo_root, verify_cfg["dev_readme"])),
        ]
        return _run(cmd)

    if args.cmd == "sync":
        cmd = [
            str(SCRIPT_DIR / "sync_helpers_to_prod.sh"),
            "--repo-root",
            str(repo_root),
            "--prod-root",
            str(_resolve_path(repo_root, args.prod_root) if args.prod_root else out_dir),
            "--mode",
            str(args.mode or sync_cfg["mode"]),
            "--allowlist",
            str(_resolve_path(repo_root, args.allowlist) if args.allowlist else _resolve_path(repo_root, sync_cfg["allowlist"])),
        ]
        prune_default = str(sync_cfg["prune"]).strip().lower()
        prune_enabled = prune_default in ("yes", "1", "true")
        if args.no_prune or not prune_enabled:
            cmd.append("--no-prune")
        return _run(cmd)

    if args.cmd == "recall":
        recall_root = _resolve_path(repo_root, recall_cfg["root"])
        cmd = [
            "python3",
            str(SCRIPT_DIR / "codex_sprint_recall.py"),
            "--root",
            str(recall_root),
        ]
        extra = args.recall_args
        if extra and extra[0] == "--":
            extra = extra[1:]
        cmd.extend(extra)
        return _run(cmd)

    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
