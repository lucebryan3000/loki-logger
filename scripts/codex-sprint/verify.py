#!/usr/bin/env python3
"""Deterministic verification gate for codex-sprint outputs.

Writes a compact machine-readable verdict file:
- `<root>/verify.result.json`

Fail-closed behavior:
- non-zero exit on missing/invalid required artifacts
- non-zero exit on schema or cross-index integrity failures
- non-zero exit when temp README drifts from canonical dev README
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from schema_contract import (
    ARTIFACTS_REQUIRED,
    HISTORY_REQUIRED,
    RUNS_REQUIRED,
    STATE_REQUIRED,
    validate_required_fields,
)


@dataclass
class Verdict:
    ok: bool
    phase: str
    root: str
    checks_run: int
    errors: list[str]
    warnings: list[str]
    summary: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "phase": self.phase,
            "root": self.root,
            "checks_run": self.checks_run,
            "errors": self.errors,
            "warnings": self.warnings,
            "summary": self.summary,
        }


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def _read_json(path: Path) -> dict | list:
    return json.loads(path.read_text(encoding="utf-8"))


def _iter_jsonl(path: Path):
    with path.open("r", encoding="utf-8") as fh:
        for idx, line in enumerate(fh, start=1):
            text = line.strip()
            if not text:
                continue
            try:
                yield idx, json.loads(text)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}: invalid jsonl at line {idx}: {exc}") from exc


def _check_required_files(root: Path, rels: list[str], errors: list[str], summary: dict[str, Any]) -> int:
    checks = 0
    for rel in rels:
        checks += 1
        p = root / rel
        if not p.exists():
            errors.append(f"missing required path: {p}")
            continue
        if p.is_file() and p.stat().st_size == 0:
            errors.append(f"required file is empty: {p}")
        summary[f"exists::{rel}"] = p.exists()
    return checks


def _verify_phase1(root: Path, errors: list[str], summary: dict[str, Any]) -> int:
    checks = _check_required_files(
        root,
        [
            "catalog/schema.json",
            "catalog/runs.jsonl",
            "catalog/prompts.json",
            "SUMMARY.json",
            "prompts",
            "runs",
        ],
        errors,
        summary,
    )
    checks += 1
    schema = root / "catalog/schema.json"
    if schema.is_file():
        obj = _read_json(schema)
        if not isinstance(obj, dict) or obj.get("version") != "v1":
            errors.append("phase1 schema version mismatch: expected v1")
    return checks


def _verify_phase2(root: Path, errors: list[str], summary: dict[str, Any]) -> int:
    checks = _check_required_files(
        root,
        [
            "catalog/schema.json",
            "catalog/prompts.json",
            "history/all-runs.jsonl",
            "runs",
            "state",
            "blobs",
            "SUMMARY.json",
        ],
        errors,
        summary,
    )
    checks += 1
    schema = root / "catalog/schema.json"
    if schema.is_file():
        obj = _read_json(schema)
        if not isinstance(obj, dict) or obj.get("version") != "v2":
            errors.append("phase2 schema version mismatch: expected v2")
    return checks


def _verify_v4_flat(root: Path, dev_readme: Path, errors: list[str], warnings: list[str], summary: dict[str, Any]) -> int:
    checks = _check_required_files(
        root,
        [
            "state.jsonl",
            "state.latest.json",
            "history.jsonl",
            "runs.jsonl",
            "artifacts.jsonl",
            "catalog.json",
            "schema.json",
            "SUMMARY.json",
            "README.md",
            "helpers.manifest.json",
        ],
        errors,
        summary,
    )

    # README drift check against canonical dev README.
    checks += 1
    readme = root / "README.md"
    if dev_readme.is_file() and readme.is_file():
        dev_hash = _sha256(dev_readme)
        out_hash = _sha256(readme)
        summary["readme_dev_sha256"] = dev_hash
        summary["readme_out_sha256"] = out_hash
        if dev_hash != out_hash:
            errors.append("README drift detected: temp README does not match canonical scripts/codex-sprint/README.md")
    elif not dev_readme.is_file():
        warnings.append(f"canonical dev README missing: {dev_readme}")

    # Parse core files.
    runs: list[dict[str, Any]] = []
    state_rows: list[dict[str, Any]] = []
    history_rows: list[dict[str, Any]] = []
    artifacts: list[dict[str, Any]] = []

    try:
        for line_no, row in _iter_jsonl(root / "runs.jsonl"):
            checks += 1
            if not isinstance(row, dict):
                errors.append(f"runs.jsonl line {line_no}: row is not object")
                continue
            for violation in validate_required_fields(row, RUNS_REQUIRED):
                errors.append(f"runs.jsonl line {line_no}: {violation}")
            runs.append(row)
    except ValueError as exc:
        errors.append(str(exc))

    try:
        for line_no, row in _iter_jsonl(root / "state.jsonl"):
            checks += 1
            if not isinstance(row, dict):
                errors.append(f"state.jsonl line {line_no}: row is not object")
                continue
            for violation in validate_required_fields(row, STATE_REQUIRED):
                errors.append(f"state.jsonl line {line_no}: {violation}")
            state_rows.append(row)
    except ValueError as exc:
        errors.append(str(exc))

    try:
        for line_no, row in _iter_jsonl(root / "history.jsonl"):
            checks += 1
            if not isinstance(row, dict):
                errors.append(f"history.jsonl line {line_no}: row is not object")
                continue
            for violation in validate_required_fields(row, HISTORY_REQUIRED):
                errors.append(f"history.jsonl line {line_no}: {violation}")
            history_rows.append(row)
    except ValueError as exc:
        errors.append(str(exc))

    try:
        for line_no, row in _iter_jsonl(root / "artifacts.jsonl"):
            checks += 1
            if not isinstance(row, dict):
                errors.append(f"artifacts.jsonl line {line_no}: row is not object")
                continue
            for violation in validate_required_fields(row, ARTIFACTS_REQUIRED):
                errors.append(f"artifacts.jsonl line {line_no}: {violation}")
            artifacts.append(row)
    except ValueError as exc:
        errors.append(str(exc))

    summary["runs_count"] = len(runs)
    summary["state_count"] = len(state_rows)
    summary["history_count"] = len(history_rows)
    summary["artifacts_count"] = len(artifacts)

    # Schema/version checks.
    checks += 3
    schema_obj = _read_json(root / "schema.json") if (root / "schema.json").is_file() else {}
    if not isinstance(schema_obj, dict) or schema_obj.get("version") != "v4-flat":
        errors.append("schema.json version mismatch: expected v4-flat")
    summary_obj = _read_json(root / "SUMMARY.json") if (root / "SUMMARY.json").is_file() else {}
    if not isinstance(summary_obj, dict) or summary_obj.get("evolution") != "v4-flat":
        errors.append("SUMMARY.json evolution mismatch: expected v4-flat")
    catalog_obj = _read_json(root / "catalog.json") if (root / "catalog.json").is_file() else {}
    if not isinstance(catalog_obj, dict) or catalog_obj.get("version") != "v4-flat":
        errors.append("catalog.json version mismatch: expected v4-flat")

    # Cross-index integrity checks.
    run_keys = [str(r.get("run_key", "")) for r in runs]
    run_key_set = set(run_keys)
    if len(run_key_set) != len(run_keys):
        errors.append("runs.jsonl contains duplicate run_key values")

    run_lookup: dict[str, dict[str, Any]] = {}
    max_seq_by_prompt: dict[str, int] = {}
    for row in runs:
        run_key = str(row.get("run_key", ""))
        run_lookup[run_key] = row
        expected_ref = f"runs.jsonl#{run_key}"
        if row.get("run_ref") != expected_ref:
            errors.append(f"run_ref mismatch for run_key={run_key}")
        prompt = str(row.get("prompt_slug", ""))
        seq = int(row.get("run_seq", 0)) if isinstance(row.get("run_seq"), int) else 0
        if seq <= 0:
            errors.append(f"non-positive run_seq for run_key={run_key}")
        max_seq_by_prompt[prompt] = max(max_seq_by_prompt.get(prompt, 0), seq)

    for row in state_rows:
        run_key = str(row.get("run_key", ""))
        if run_key not in run_key_set:
            errors.append(f"state row references unknown run_key={run_key}")
        if row.get("run_ref") != f"runs.jsonl#{run_key}":
            errors.append(f"state run_ref mismatch for run_key={run_key}")

    for row in history_rows:
        run_key = str(row.get("run_key", ""))
        if run_key not in run_key_set:
            errors.append(f"history row references unknown run_key={run_key}")
        if row.get("run_ref") != f"runs.jsonl#{run_key}":
            errors.append(f"history run_ref mismatch for run_key={run_key}")

    for row in artifacts:
        run_key = str(row.get("run_key", ""))
        if run_key not in run_key_set:
            errors.append(f"artifact row references unknown run_key={run_key}")
        if row.get("run_ref") != f"runs.jsonl#{run_key}":
            errors.append(f"artifact run_ref mismatch for run_key={run_key}")

    checks += 1
    latest_obj = _read_json(root / "state.latest.json") if (root / "state.latest.json").is_file() else {}
    prompts_obj = latest_obj.get("prompts", {}) if isinstance(latest_obj, dict) else {}
    if not isinstance(prompts_obj, dict):
        errors.append("state.latest.json invalid: `prompts` must be an object")
        prompts_obj = {}
    for slug, row in prompts_obj.items():
        if not isinstance(row, dict):
            errors.append(f"state.latest.json prompt={slug}: row is not object")
            continue
        run_key = str(row.get("run_key", ""))
        run_seq = row.get("run_seq")
        if run_key not in run_key_set:
            errors.append(f"state.latest.json prompt={slug} references unknown run_key={run_key}")
            continue
        if not isinstance(run_seq, int) or run_seq != max_seq_by_prompt.get(slug, -1):
            errors.append(f"state.latest.json prompt={slug} run_seq does not match max observed sequence")

    checks += 1
    if isinstance(catalog_obj, dict):
        if catalog_obj.get("run_count") != len(runs):
            errors.append("catalog.json run_count does not match runs.jsonl row count")
        if catalog_obj.get("indexed_artifacts") != len(artifacts):
            errors.append("catalog.json indexed_artifacts does not match artifacts.jsonl row count")
        prompts = catalog_obj.get("prompts", [])
        if isinstance(prompts, list):
            if catalog_obj.get("prompt_count") != len(prompts):
                errors.append("catalog.json prompt_count does not match prompts list length")
        else:
            errors.append("catalog.json `prompts` must be a list")

    checks += 1
    manifest_obj = _read_json(root / "helpers.manifest.json") if (root / "helpers.manifest.json").is_file() else {}
    if not isinstance(manifest_obj, dict):
        errors.append("helpers.manifest.json must be an object")
    elif not isinstance(manifest_obj.get("files"), list):
        errors.append("helpers.manifest.json missing `files` list")
    else:
        manifest_files = manifest_obj.get("files", [])
        manifest_names = set()
        for row in manifest_files:
            if not isinstance(row, dict):
                errors.append("helpers.manifest.json has non-object file row")
                continue
            name = row.get("name")
            if not isinstance(name, str) or not name:
                errors.append("helpers.manifest.json file row missing valid `name`")
                continue
            manifest_names.add(name)
            if not (root / name).is_file():
                errors.append(f"helpers.manifest.json references missing synced file: {name}")

        allowlist_path = dev_readme.parent / "sync.allowlist"
        if allowlist_path.is_file():
            expected = set()
            for line in allowlist_path.read_text(encoding="utf-8").splitlines():
                entry = line.strip()
                if not entry or entry.startswith("#"):
                    continue
                expected.add(entry)
            summary["allowlist_path"] = str(allowlist_path)
            summary["allowlist_expected_count"] = len(expected)
            if manifest_names != expected:
                missing = sorted(expected - manifest_names)
                extra = sorted(manifest_names - expected)
                if missing:
                    errors.append(f"helpers.manifest.json missing allowlisted entries: {missing}")
                if extra:
                    errors.append(f"helpers.manifest.json has non-allowlisted entries: {extra}")
        else:
            warnings.append(f"sync allowlist not found: {allowlist_path}")

    # Anti-pattern guardrails (fail-closed).
    checks += 1
    dev_dir = dev_readme.parent
    legacy_dev = sorted(p.name for p in dev_dir.glob("evolve_v*.py"))
    legacy_prod = sorted(p.name for p in root.glob("evolve_v*.py"))
    if legacy_dev:
        errors.append(f"anti-pattern: legacy phase scripts present in dev dir: {legacy_dev}")
    if legacy_prod:
        errors.append(f"anti-pattern: legacy phase scripts present in output root: {legacy_prod}")

    checks += 1
    run_evolutions = dev_dir / "run_evolutions.sh"
    if run_evolutions.is_file():
        text = run_evolutions.read_text(encoding="utf-8", errors="ignore")
        if "evolve_v" in text:
            errors.append("anti-pattern: run_evolutions.sh still references evolve_v* scripts")
        if "evolve.py" not in text:
            errors.append("anti-pattern: run_evolutions.sh does not reference canonical evolve.py")
    else:
        warnings.append(f"run_evolutions.sh not found for anti-pattern check: {run_evolutions}")

    checks += 1
    config_path = dev_dir / "codex_sprint.config.json"
    cli_path = dev_dir / "codex_sprint.py"
    if not config_path.is_file():
        errors.append("anti-pattern: missing codex_sprint.config.json")
    if not cli_path.is_file():
        errors.append("anti-pattern: missing canonical codex_sprint.py entrypoint")

    return checks


def verify(root: Path, phase: str, dev_readme: Path) -> Verdict:
    errors: list[str] = []
    warnings: list[str] = []
    summary: dict[str, Any] = {}
    checks_run = 0

    if phase == "1":
        checks_run += _verify_phase1(root, errors, summary)
    elif phase == "2":
        checks_run += _verify_phase2(root, errors, summary)
    elif phase == "3":
        checks_run += _verify_v4_flat(root, dev_readme, errors, warnings, summary)
    else:
        checks_run += _verify_phase1(root, errors, summary)
        checks_run += _verify_phase2(root, errors, summary)
        checks_run += _verify_v4_flat(root, dev_readme, errors, warnings, summary)

    return Verdict(
        ok=len(errors) == 0,
        phase=phase,
        root=str(root),
        checks_run=checks_run,
        errors=errors,
        warnings=warnings,
        summary=summary,
    )


def _build_parser() -> argparse.ArgumentParser:
    epilog = """Examples:
  python3 scripts/codex-sprint/verify.py --root temp/codex-sprint --phase 3
  python3 scripts/codex-sprint/verify.py --root temp/codex-sprint --phase all
"""
    ap = argparse.ArgumentParser(
        description=(
            "Verify codex-sprint output completeness, schema contract, and "
            "cross-index integrity. Writes verify.result.json under --root."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog,
    )
    ap.add_argument("--root", default="temp/codex-sprint", help="Output root to verify.")
    ap.add_argument("--phase", choices=["1", "2", "3", "all"], default="3", help="Phase contract to verify.")
    ap.add_argument(
        "--dev-readme",
        default="scripts/codex-sprint/README.md",
        help="Canonical README used for drift checks in phase 3.",
    )
    return ap


def main() -> int:
    args = _build_parser().parse_args()
    root = Path(args.root).resolve()
    dev_readme = Path(args.dev_readme).resolve()
    verdict = verify(root, args.phase, dev_readme)

    result_path = root / "verify.result.json"
    result_path.write_text(json.dumps(verdict.to_dict(), indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"verify result: {'PASS' if verdict.ok else 'FAIL'} ({result_path})")
    if verdict.errors:
        for err in verdict.errors:
            print(f"ERROR: {err}", file=sys.stderr)
    if verdict.warnings:
        for warn in verdict.warnings:
            print(f"WARN: {warn}", file=sys.stderr)
    return 0 if verdict.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
