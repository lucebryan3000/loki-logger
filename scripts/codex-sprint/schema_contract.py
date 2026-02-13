#!/usr/bin/env python3
"""Schema contracts for codex-sprint flat indexes.

This module intentionally avoids third-party dependencies. It defines strict
field/type contracts used by `verify.py` so validation stays deterministic and
portable in sandbox environments.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class FieldRule:
    name: str
    py_types: tuple[type, ...]


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_str(value: Any) -> bool:
    return isinstance(value, str)


def _is_num(value: Any) -> bool:
    return (isinstance(value, int) and not isinstance(value, bool)) or isinstance(value, float)


RUNS_REQUIRED = (
    FieldRule("prompt_slug", (str,)),
    FieldRule("run_id", (str,)),
    FieldRule("run_seq", (int,)),
    FieldRule("run_key", (str,)),
    FieldRule("run_ref", (str,)),
    FieldRule("status", (str,)),
    FieldRule("source_family", (str,)),
    FieldRule("source_prompt_label", (str,)),
    FieldRule("source_run_label", (str,)),
    FieldRule("source_run_path", (str,)),
    FieldRule("file_count", (int,)),
    FieldRule("total_bytes", (int,)),
    FieldRule("indexed_utc", (str,)),
)

STATE_REQUIRED = (
    FieldRule("prompt_slug", (str,)),
    FieldRule("run_id", (str,)),
    FieldRule("run_seq", (int,)),
    FieldRule("run_key", (str,)),
    FieldRule("run_ref", (str,)),
    FieldRule("status", (str,)),
    FieldRule("indexed_utc", (str,)),
)

HISTORY_REQUIRED = (
    FieldRule("event", (str,)),
    FieldRule("prompt_slug", (str,)),
    FieldRule("run_id", (str,)),
    FieldRule("run_seq", (int,)),
    FieldRule("run_key", (str,)),
    FieldRule("run_ref", (str,)),
    FieldRule("status", (str,)),
    FieldRule("indexed_utc", (str,)),
)

ARTIFACTS_REQUIRED = (
    FieldRule("prompt_slug", (str,)),
    FieldRule("run_id", (str,)),
    FieldRule("run_seq", (int,)),
    FieldRule("run_key", (str,)),
    FieldRule("run_ref", (str,)),
    FieldRule("file_name", (str,)),
    FieldRule("rel_path", (str,)),
    FieldRule("source_abs", (str,)),
    FieldRule("bytes", (int,)),
    FieldRule("sha256", (str,)),
    FieldRule("indexed_utc", (str,)),
)


def validate_required_fields(row: dict[str, Any], rules: tuple[FieldRule, ...]) -> list[str]:
    """Return list of violations for required fields and expected python types."""
    violations: list[str] = []
    for rule in rules:
        if rule.name not in row:
            violations.append(f"missing field `{rule.name}`")
            continue
        value = row[rule.name]
        if rule.py_types == (int,) and not _is_int(value):
            violations.append(f"field `{rule.name}` expected int got {type(value).__name__}")
            continue
        if rule.py_types == (str,) and not _is_str(value):
            violations.append(f"field `{rule.name}` expected str got {type(value).__name__}")
            continue
        if rule.py_types == (float, int) and not _is_num(value):
            violations.append(f"field `{rule.name}` expected number got {type(value).__name__}")
            continue
        if rule.py_types not in ((int,), (str,), (float, int)) and not isinstance(value, rule.py_types):
            violations.append(f"field `{rule.name}` expected {rule.py_types} got {type(value).__name__}")
    return violations
