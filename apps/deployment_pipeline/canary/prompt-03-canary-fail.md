---
chatgpt_scoping_kind: task
chatgpt_scoping_scope: single-file
chatgpt_scoping_targets_root: apps/deployment_pipeline/canary/
chatgpt_scoping_targets:
- prompt-03-canary-fail.md
codex_preflight_kind: task
codex_preflight_scope: single-file
codex_preflight_targets_root: apps/deployment_pipeline/canary/
codex_preflight_targets: prompt-03-canary-fail.md
codex_preflight_ready: 'yes'
codex_preflight_reason: ''
codex_preflight_reviewed_local: 4:13 PM - 13-02-2026
codex_preflight_revision: 1
codex_preflight_autocommit: 'no'
codex_preflight_autopush: 'no'
codex_preflight_move_to_completed: 'no'
codex_preflight_warn_gate: 'yes'
codex_preflight_warn_mode: halt
codex_preflight_allow_noncritical: 'yes'
codex_preflight_retry_max: '0'
prompt_flow:
  version: v1
  stages:
    draft:
      source: chatgpt
      status: drafted
      updated_utc: '2026-02-13T22:13:32Z'
      scoping:
        kind: task
        scope: single-file
        targets_root: apps/deployment_pipeline/canary/
        targets:
        - prompt-03-canary-fail.md
      next_stage: preflight
    preflight:
      source: prompt-preflight
      status: ready
      ready: 'yes'
      reason: ''
      reviewed_local: 4:13 PM - 13-02-2026
      revision: 1
      kind: task
      scope: single-file
      targets_root: apps/deployment_pipeline/canary/
      targets:
      - prompt-03-canary-fail.md
      policy:
        autocommit: 'no'
        autopush: 'no'
        move_to_completed: 'no'
        warn_gate: 'yes'
        warn_mode: halt
        allow_noncritical: 'yes'
        retry_max: '0'
      updated_utc: '2026-02-13T22:13:32Z'
      next_stage: exec
    exec:
      source: prompt-exec
      status: failed
      run_local: 4:13 PM - 13-02-2026
      run_ref: /home/luce/apps/loki-logging/temp/codex-sprint/runs.jsonl#prompt-03-canary-fail--r0001
      prompt_sha: 9c34612d6338ad105731d72adb0d1a28eaf642dfd8d63868fa6cd2a385af09da
      completion_gate: skipped
      failed_block: block001
      failed_bucket: unknown
      last_ok_block: '0'
      warning_count: '0'
      move_status: skipped
      updated_utc: '2026-02-13T22:13:33Z'
      next_stage: pipeline
    pipeline:
      source: prompt-pipeline
      status: hold
      run_id: 20260213T221324Z
      batch_id: 20260213T221324Z
      attempt: '1'
      fail_streak: '1'
      fail_total: '1'
      loop_count: '1'
      parked: 'yes'
      plan_file: /home/luce/apps/loki-logging/apps/deployment_pipeline/canary/.prompt-pipeline.plan.txt
      resume_file: /home/luce/apps/loki-logging/apps/deployment_pipeline/canary/.prompt-pipeline.resume.env
      last_event: pipeline_hold
      policy:
        auto_yes: '0'
        count: '1'
        fail_fast_threshold: '1'
        max_total_failures: '1'
        loop_threshold: '3'
        profile: production
      updated_utc: '2026-02-13T22:14:46Z'
codex_exec_last_run_status: failed
codex_exec_last_run_local: 4:13 PM - 13-02-2026
codex_exec_last_run_dir: /home/luce/apps/loki-logging/temp/codex-sprint/runs.jsonl#prompt-03-canary-fail--r0001
codex_exec_last_run_prompt_sha: 9c34612d6338ad105731d72adb0d1a28eaf642dfd8d63868fa6cd2a385af09da
codex_exec_last_run_completion_gate: skipped
codex_exec_last_run_failed_block: block001
codex_exec_last_run_failed_bucket: unknown
codex_exec_last_run_last_ok_block: '0'
codex_exec_last_run_warning_count: '0'
codex_exec_last_run_move_status: skipped
---

# Canary Fail Prompt

Intentional failure prompt to validate pipeline fail-fast and parking behavior.

## Scope

- Force a deterministic failure to validate orchestration safety gates.

## Affects

- `apps/deployment_pipeline/canary/prompt-03-canary-fail.md`

## Steps

```bash
set -euo pipefail
echo "canary: intentional failure"
exit 1
```

## Acceptance Proofs

- Pipeline marks this prompt as failed/blocked.
- Failure is logged in `.prompt-pipeline.log.jsonl`.

## Guardrails

- No destructive operations.
- No writes outside canary scope.

## Done Criteria

- Prompt fails with non-zero exit code.
- Pipeline fail-fast/parking behavior is observable.

## Operator Checkpoint

Proceed with all phases uninterrupted? (yes/no)
