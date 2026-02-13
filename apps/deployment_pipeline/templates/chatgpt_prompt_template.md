---
chatgpt_scoping_kind: task
chatgpt_scoping_scope: single-file
chatgpt_scoping_targets_root: apps/deployment_pipeline/prompts/
chatgpt_scoping_targets:
  - prompt-XX-name.md
chatgpt_verify_files_exist:
  - apps/deployment_pipeline/out/example.txt
chatgpt_verify_headers: []
chatgpt_verify_http_200: []
codex_preflight_autocommit: "no"
codex_preflight_autopush: "no"
codex_preflight_move_to_completed: "no"
codex_preflight_warn_mode: "ask"
codex_preflight_warn_gate: "yes"
codex_preflight_retry_max: "1"
---

# Prompt Title

One sentence objective.

## Scope

- Describe the exact bounded scope.

## Affects

- `repo/relative/path.ext`

## State Inputs (Read-Only)

- `temp/codex-sprint/state.latest.json`
- `temp/codex-sprint/runs.jsonl`
- `temp/codex-sprint/history.jsonl`
- `temp/codex-sprint/catalog.json`
- `apps/deployment_pipeline/prompts/.prompt-pipeline.state`
- `apps/deployment_pipeline/prompts/.prompt-pipeline.failed`
- `apps/deployment_pipeline/prompts/.prompt-pipeline.log.jsonl`

## Steps

```bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
# Optional state recall example:
# python3 "$ROOT/temp/codex-sprint/search_records.py" --root "$ROOT/temp/codex-sprint" --index runs --prompt prompt-xx-name --limit 5 || true
# deterministic implementation
```

## Acceptance Proofs

- `repo/relative/path.ext` exists and is non-empty.
- Output content satisfies exact expected value.

## Guardrails

- Keep changes within listed `## Affects` paths.
- Avoid interactive commands.

## Done Criteria

- Script block exits `0`.
- Completion gate passes.

## Operator Checkpoint

Proceed with all phases uninterrupted? (yes/no)
