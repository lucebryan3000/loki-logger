# ChatGPT Template: PRD -> 12 Execution Prompts

Paste this entire template into ChatGPT, then replace the placeholder sections.
This is designed to generate prompts compatible with:

- `$prompt-preflight`
- `$prompt-exec`
- `$prompt-pipeline`

It enforces the sections and frontmatter keys expected by the current pipeline.

---

## Paste-Ready Prompt For ChatGPT

```md
You are generating an execution prompt pack for Codex.

Goal:
- Convert one large PRD into exactly 12 actionable markdown prompts.
- Each prompt must be execution-ready for prompt-preflight + prompt-exec.
- Keep each prompt detailed enough to run, but not over-engineered.

Context:
- Repo root: /home/luce/apps/loki-logging
- Prompt output dir: apps/deployment_pipeline/prompts/
- Evidence/state root: temp/codex-sprint/
- Pipeline state files:
  - apps/deployment_pipeline/prompts/.prompt-pipeline.state
  - apps/deployment_pipeline/prompts/.prompt-pipeline.failed
  - apps/deployment_pipeline/prompts/.prompt-pipeline.log.jsonl
- Recall helpers:
  - temp/codex-sprint/search_records.py
  - temp/codex-sprint/search_artifacts.py
  - temp/codex-sprint/codex_sprint_recall.sh

Use this PRD:
<PASTE_PRD_HERE>

Requirements:
1) Produce exactly 13 files in your response:
   - 1 index file:
     - apps/deployment_pipeline/prompts/INDEX-prd-breakdown.md
   - 12 execution prompts:
     - apps/deployment_pipeline/prompts/prompt-01-<slug>.md
     - ...
     - apps/deployment_pipeline/prompts/prompt-12-<slug>.md

2) Output format must be:
   - one file block at a time
   - each starts with:
     - FILE: <repo-relative-path>
   - then a fenced markdown block containing full file content

3) Every execution prompt must include this YAML frontmatter shape:
---
chatgpt_scoping_kind: task
chatgpt_scoping_scope: single-file
chatgpt_scoping_targets_root: apps/deployment_pipeline/prompts/
chatgpt_scoping_targets:
  - prompt-XX-slug.md
chatgpt_verify_files_exist:
  - <at least 1 concrete output path>
chatgpt_verify_headers: []
chatgpt_verify_http_200: []
codex_preflight_autocommit: "no"
codex_preflight_autopush: "no"
codex_preflight_move_to_completed: "no"
codex_preflight_warn_mode: "ask"
codex_preflight_warn_gate: "yes"
codex_preflight_retry_max: "1"
---

4) Every execution prompt body must contain these sections exactly:
- # <Prompt Title>
- ## Scope
- ## Affects
- ## State Inputs (Read-Only)
- ## Steps
- ## Acceptance Proofs
- ## Guardrails
- ## Done Criteria
- ## Operator Checkpoint

5) State awareness:
- In `## State Inputs (Read-Only)`, reference relevant files from:
  - temp/codex-sprint/state.latest.json
  - temp/codex-sprint/runs.jsonl
  - temp/codex-sprint/history.jsonl
  - temp/codex-sprint/catalog.json
  - apps/deployment_pipeline/prompts/.prompt-pipeline.state
  - apps/deployment_pipeline/prompts/.prompt-pipeline.failed
  - apps/deployment_pipeline/prompts/.prompt-pipeline.log.jsonl
- Steps may read these files, but must not mutate them directly.

6) Shell block rules in `## Steps`:
- Use one fenced `bash` block per prompt.
- Include:
  - `set -euo pipefail`
  - `ROOT="$(git rev-parse --show-toplevel)"`
- Commands must be non-interactive and deterministic.
- Avoid destructive commands.

7) Decomposition quality bar:
- Prompt 01-02: foundation/scaffolding and contracts.
- Prompt 03-08: core implementation slices.
- Prompt 09-10: validation/hardening.
- Prompt 11: docs/runbook updates.
- Prompt 12: final verification/reporting.
- Each prompt should target 1 focused outcome and 1-3 affected files.

8) `INDEX-prd-breakdown.md` must include:
- PRD summary (5-10 bullets).
- Prompt dependency graph (which prompt depends on which).
- Execution order table with:
  - prompt file
  - objective
  - expected outputs
  - verification artifact(s)

9) Compatibility constraints:
- Do not add `codex_preflight_ready` or `codex_preflight_revision`; preflight will stamp those.
- Keep prompts single-file scoped by default.
- Use repo-relative paths in all references.

Return only the 13 file blocks in the required format.
```

---

## Notes

- This template intentionally uses `chatgpt_*` keys because `prompt-preflight` will normalize and backfill `codex_verify_*` and staged `prompt_flow.*` fields.
- For multi-file tasks, set `chatgpt_scoping_scope: multi-file` and list prompt basenames in `chatgpt_scoping_targets`.

