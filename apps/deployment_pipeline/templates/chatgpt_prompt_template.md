---
chatgpt_scoping_kind: task
chatgpt_scoping_scope: single-file
chatgpt_scoping_targets_root: apps/deployment_pipeline/prompts/
chatgpt_scoping_targets:
  - prompt-XX-name.md
chatgpt_verify_files_exist:
  - apps/deployment_pipeline/out/example.txt
codex_preflight_autocommit: "no"
codex_preflight_autopush: "no"
codex_preflight_move_to_completed: "no"
---

# Prompt Title

One sentence objective.

## Scope

- Describe the exact bounded scope.

## Affects

- `repo/relative/path.ext`

## Steps

```bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
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
