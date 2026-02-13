# codex-sprint (Canonical Layout + Tooling)

This README is the canonical source for `temp/codex-sprint/README.md`.
The canonical builder (`scripts/codex-sprint/evolve.py`) copies this file into
the output root when generating sprint artifacts.

## Purpose

`temp/codex-sprint/` is the compact, machine-readable sprint evidence store.
It replaces deeply nested run trees with append-only flat indexes.

## Canonical Review Folder

Review this folder for current sprint output and generated artifacts:

- `temp/codex-sprint/`

Authoritative implementation/source-of-truth scripts live here:

- `scripts/codex-sprint/`

## Core Data Files

- `state.jsonl`: append-only state snapshot per indexed run
- `state.latest.json`: latest state row per prompt slug
- `history.jsonl`: append-only event/history log
- `runs.jsonl`: append-only run summaries
- `artifacts.jsonl`: append-only artifact catalog (`sha256`, bytes, refs)
- `catalog.json`: prompt/run catalog plus index pointers
- `schema.json`: layout contract for scripts and LLM tooling
- `SUMMARY.json`: latest generation summary
- `verify.result.json`: deterministic pass/fail verification verdict
- `source_snapshot.json`: incremental no-change fingerprint (phase 3)

## Canonical Scripts

- `codex_sprint.py`: canonical CLI (`build`, `verify`, `sync`, `recall`)
- `codex_sprint.config.json`: validated default config contract
- `prompt_flow.config.json`: active runtime profile (`poc` or `production`)
- `prompt_flow_profile.py`: deterministic profile loader/validator for scripts
- `evolve.py`: single canonical evolution/builder entrypoint
- `verify.py`: strict schema + cross-index + anti-pattern gate
- `run_evolutions.sh`: executes phases `1 -> 2 -> 3` for comparison/simulation
- `sync_helpers_to_prod.sh`: syncs dev scripts into `temp/codex-sprint/`
- `codex_sprint_recall.py` / `codex_sprint_recall.sh`: recall/search entrypoints
- `search_records.py`, `search_artifacts.py`: focused index query helpers
- `PROMPT_FLOW_PROFILES.md`: profile strategy and rollout order (`poc` vs `production`)

## Naming Rule

Legacy phase-specific script names are deprecated.

- do not add `evolve_v1.py`, `evolve_v2.py`, `evolve_v3.py`
- keep `evolve.py` as the only evolution script name

## Guardrails

- canonical sync scope is defined by `scripts/codex-sprint/sync.allowlist`
- `sync_helpers_to_prod.sh` prunes stale non-allowlisted top-level files by default
- `verify.py` fails closed on schema/integrity drift and anti-pattern violations
- anti-pattern reference is codified in `scripts/codex-sprint/ANTI_PATTERNS.md`

## Typical Flow

1. update dev scripts under `scripts/codex-sprint/`
2. run `python3 scripts/codex-sprint/codex_sprint.py build` (or `run_evolutions.sh`)
3. run `python3 scripts/codex-sprint/codex_sprint.py sync`
4. run `python3 scripts/codex-sprint/codex_sprint.py verify`
5. query via `python3 scripts/codex-sprint/codex_sprint.py recall ...`

## Runtime Profile Flow

Use profiles to switch behavior between proof-of-concept and production runs:

1. set `active_profile` in `scripts/codex-sprint/prompt_flow.config.json`
2. validate profile:
   - `python3 scripts/codex-sprint/prompt_flow_profile.py validate`
3. sync helpers/config to prod:
   - `scripts/codex-sprint/sync_helpers_to_prod.sh`
4. run a mini prompt set first (recommended), then full pipeline
