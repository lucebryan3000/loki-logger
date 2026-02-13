#!/usr/bin/env python3
"""Resolve prompt-flow profile toggles for preflight/exec/pipeline scripts.

This helper is intentionally deterministic:
- load one JSON config
- normalize the top 5 profile toggles
- emit normalized values for shell scripts to consume
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any


DEFAULT_CONFIG_REL = Path("scripts/codex-sprint/prompt_flow.config.json")
FALLBACK_CONFIG_REL = Path("temp/codex-sprint/prompt_flow.config.json")


def _norm_yes_no(value: Any, default: str = "yes") -> str:
    raw = str(value).strip().lower()
    if raw in {"yes", "no"}:
        return raw
    if raw in {"true", "1"}:
        return "yes"
    if raw in {"false", "0"}:
        return "no"
    return default


def _norm_warn_mode(value: Any, default: str = "ask") -> str:
    raw = str(value).strip().lower()
    if raw in {"ask", "auto-approve", "halt"}:
        return raw
    if raw in {"autoapprove", "auto_approve"}:
        return "auto-approve"
    return default


def _norm_retry_max(value: Any, default: str = "1") -> str:
    raw = str(value).strip().lower()
    if raw in {"yes", "true"}:
        return "1"
    if raw in {"no", "false"}:
        return "0"
    try:
        n = int(raw)
    except Exception:
        return default
    return "0" if n <= 0 else "1"


def _norm_positive_int(value: Any, default: int, minimum: int = 1) -> int:
    try:
        n = int(str(value).strip())
    except Exception:
        return default
    return max(minimum, n)


def _find_repo_root(start: Path) -> Path | None:
    cur = start.resolve()
    for candidate in [cur, *cur.parents]:
        if (candidate / ".git").exists():
            return candidate
    return None


def _resolve_repo_root(repo_root_arg: str) -> Path:
    if repo_root_arg:
        return Path(repo_root_arg).expanduser().resolve()

    env_root = os.environ.get("REPO_ROOT", "").strip()
    if env_root:
        return Path(env_root).expanduser().resolve()

    found = _find_repo_root(Path.cwd())
    if found:
        return found
    return Path.cwd().resolve()


def _resolve_config_path(repo_root: Path, config_arg: str) -> Path:
    if config_arg:
        return Path(config_arg).expanduser().resolve()

    candidates = [
        repo_root / DEFAULT_CONFIG_REL,
        repo_root / FALLBACK_CONFIG_REL,
        Path(__file__).resolve().with_name("prompt_flow.config.json"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return candidates[0]


def _load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"missing profile config: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON in profile config {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"profile config must be a JSON object: {path}")
    return data


def _normalize_profile(raw: dict[str, Any]) -> dict[str, str]:
    return {
        "warn_mode": _norm_warn_mode(raw.get("warn_mode", "ask"), "ask"),
        "warn_gate": _norm_yes_no(raw.get("warn_gate", "yes"), "yes"),
        "retry_max": _norm_retry_max(raw.get("retry_max", "1"), "1"),
        "pipeline_fail_fast_threshold": str(
            _norm_positive_int(raw.get("pipeline_fail_fast_threshold", 3), 3, minimum=1)
        ),
        "pipeline_max_total_failures": str(
            _norm_positive_int(raw.get("pipeline_max_total_failures", 8), 8, minimum=1)
        ),
    }


def _resolve_profile(
    cfg: dict[str, Any], profile_arg: str
) -> tuple[str, dict[str, str], dict[str, Any]]:
    profiles_raw = cfg.get("profiles")
    if not isinstance(profiles_raw, dict) or not profiles_raw:
        raise ValueError("profile config must include a non-empty 'profiles' mapping")

    profile_name = (profile_arg or str(cfg.get("active_profile", "")).strip() or "poc").strip()
    if profile_name not in profiles_raw:
        known = ", ".join(sorted(str(x) for x in profiles_raw.keys()))
        raise ValueError(f"unknown profile '{profile_name}' (known: {known})")

    selected_raw = profiles_raw[profile_name]
    if not isinstance(selected_raw, dict):
        raise ValueError(f"profile '{profile_name}' must be a JSON object")

    normalized = _normalize_profile(selected_raw)
    return profile_name, normalized, selected_raw


def _emit_env(profile_name: str, profile: dict[str, str], target: str) -> list[tuple[str, str]]:
    # Base keys are always emitted.
    items: list[tuple[str, str]] = [("PROMPT_FLOW_PROFILE", profile_name)]

    # Exec/preflight/pipeline all share these core controls.
    items.extend(
        [
            ("PROMPT_FLOW_WARN_MODE", profile["warn_mode"]),
            ("PROMPT_FLOW_WARN_GATE", profile["warn_gate"]),
            ("PROMPT_FLOW_RETRY_MAX", profile["retry_max"]),
        ]
    )

    if target in {"pipeline", "all"}:
        items.extend(
            [
                (
                    "PROMPT_FLOW_PIPELINE_FAIL_FAST_THRESHOLD",
                    profile["pipeline_fail_fast_threshold"],
                ),
                (
                    "PROMPT_FLOW_PIPELINE_MAX_TOTAL_FAILURES",
                    profile["pipeline_max_total_failures"],
                ),
            ]
        )

    return items


def cmd_show(args: argparse.Namespace) -> int:
    repo_root = _resolve_repo_root(args.repo_root)
    cfg_path = _resolve_config_path(repo_root, args.config)
    cfg = _load_json(cfg_path)
    profile_name, normalized, raw_selected = _resolve_profile(cfg, args.profile)

    payload = {
        "repo_root": str(repo_root),
        "config_path": str(cfg_path),
        "active_profile": profile_name,
        "top5_toggles": cfg.get(
            "top5_toggles",
            [
                "warn_mode",
                "warn_gate",
                "retry_max",
                "pipeline_fail_fast_threshold",
                "pipeline_max_total_failures",
            ],
        ),
        "profile_raw": raw_selected,
        "profile_normalized": normalized,
    }
    print(json.dumps(payload, indent=2, ensure_ascii=True))
    return 0


def cmd_emit_env(args: argparse.Namespace) -> int:
    repo_root = _resolve_repo_root(args.repo_root)
    cfg_path = _resolve_config_path(repo_root, args.config)
    cfg = _load_json(cfg_path)
    profile_name, normalized, _raw_selected = _resolve_profile(cfg, args.profile)
    rows = _emit_env(profile_name, normalized, args.target)
    for key, value in rows:
        print(f"{key}={value}")
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    repo_root = _resolve_repo_root(args.repo_root)
    cfg_path = _resolve_config_path(repo_root, args.config)
    cfg = _load_json(cfg_path)
    profile_name, normalized, _raw_selected = _resolve_profile(cfg, args.profile)

    summary = {
        "ok": True,
        "repo_root": str(repo_root),
        "config_path": str(cfg_path),
        "profile": profile_name,
        "normalized": normalized,
    }
    print(json.dumps(summary, indent=2, ensure_ascii=True))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="prompt_flow_profile.py",
        description=(
            "Resolve profile-driven prompt flow toggles for prompt-preflight, "
            "prompt-exec, and prompt-pipeline."
        ),
    )
    parser.add_argument(
        "--repo-root",
        default="",
        help="Repository root (default: REPO_ROOT env, then auto-detected from cwd).",
    )
    parser.add_argument(
        "--config",
        default="",
        help=(
            "Path to profile config JSON. Defaults to "
            "<repo>/scripts/codex-sprint/prompt_flow.config.json."
        ),
    )
    parser.add_argument(
        "--profile",
        default="",
        help="Override profile name (default: config active_profile).",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    p_show = sub.add_parser(
        "show",
        help="Print resolved profile data as JSON (raw + normalized values).",
    )
    p_show.set_defaults(fn=cmd_show)

    p_emit = sub.add_parser(
        "emit-env",
        help=(
            "Emit KEY=VALUE lines for shell consumption. "
            "Use with: while IFS='=' read -r k v; do ...; done."
        ),
    )
    p_emit.add_argument(
        "--target",
        choices=["exec", "preflight", "pipeline", "all"],
        default="all",
        help="Choose which variable set to emit (default: all).",
    )
    p_emit.set_defaults(fn=cmd_emit_env)

    p_validate = sub.add_parser(
        "validate",
        help="Validate config structure and print normalized profile summary.",
    )
    p_validate.set_defaults(fn=cmd_validate)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.fn(args))
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
