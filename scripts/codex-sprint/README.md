# codex-sprint (Canonical Layout + Tooling)

This README is the canonical source for `temp/codex-sprint/README.md`.
The canonical builder (`scripts/codex-sprint/evolve.py`) copies this file into
the output root when generating sprint artifacts.

## Purpose

`temp/codex-sprint/` is the compact, machine-readable sprint evidence store.
It replaces deeply nested run trees with append-only flat indexes.

## Core Data Files

- `state.jsonl`: append-only state snapshot per indexed run
- `state.latest.json`: latest state row per prompt slug
- `history.jsonl`: append-only event/history log
- `runs.jsonl`: append-only run summaries
- `artifacts.jsonl`: append-only artifact catalog (`sha256`, bytes, refs)
- `catalog.json`: prompt/run catalog plus index pointers
- `schema.json`: layout contract for scripts and LLM tooling
- `SUMMARY.json`: latest generation summary

## Canonical Scripts

- `evolve.py`: single canonical evolution/builder entrypoint
- `run_evolutions.sh`: executes phases `1 -> 2 -> 3` for comparison/simulation
- `sync_helpers_to_prod.sh`: syncs dev scripts into `temp/codex-sprint/`
- `codex_sprint_recall.py` / `codex_sprint_recall.sh`: recall/search entrypoints
- `search_records.py`, `search_artifacts.py`: focused index query helpers

## Naming Rule

Legacy phase-specific script names are deprecated.

- do not add `evolve_v1.py`, `evolve_v2.py`, `evolve_v3.py`
- keep `evolve.py` as the only evolution script name

## Typical Flow

1. update dev scripts under `scripts/codex-sprint/`
2. run `scripts/codex-sprint/run_evolutions.sh` (or `evolve.py --phase 3`)
3. run `scripts/codex-sprint/sync_helpers_to_prod.sh --mode all`
4. query via `temp/codex-sprint/codex_sprint_recall.sh ...`
