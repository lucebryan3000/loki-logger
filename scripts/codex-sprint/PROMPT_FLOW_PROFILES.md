# Prompt Flow Profiles (POC vs Production)

This document defines the developer-facing runtime profile controls for:

- `prompt-preflight`
- `prompt-exec`
- `prompt-pipeline`

The goal is one centralized profile with deterministic toggles that are safe to
reuse across runs and easy to switch for POC vs production changes.

## Canonical Config

- Dev source of truth:
  - `scripts/codex-sprint/prompt_flow.config.json`
- Runtime/prod copy:
  - `temp/codex-sprint/prompt_flow.config.json`

Use the helper to inspect or validate:

```bash
python3 scripts/codex-sprint/prompt_flow_profile.py --repo-root /home/luce/apps/loki-logging show
python3 scripts/codex-sprint/prompt_flow_profile.py --repo-root /home/luce/apps/loki-logging validate
```

## Top 5 Toggles

The config intentionally controls only five high-value runtime toggles:

1. `warn_mode`: `ask | auto-approve | halt`
2. `warn_gate`: `yes | no`
3. `retry_max`: `0 | 1`
4. `pipeline_fail_fast_threshold`: positive integer
5. `pipeline_max_total_failures`: positive integer

These map to:

- `prompt-exec`: warning behavior + retry budget
- `prompt-pipeline`: fail-fast behavior and max tolerated failures

## Recommended Defaults

- `poc`:
  - `warn_mode=auto-approve`
  - `warn_gate=no`
  - `retry_max=1`
  - `pipeline_fail_fast_threshold=6`
  - `pipeline_max_total_failures=20`
- `production`:
  - `warn_mode=halt`
  - `warn_gate=yes`
  - `retry_max=0`
  - `pipeline_fail_fast_threshold=2`
  - `pipeline_max_total_failures=4`

Current frozen baseline in this repo:
- `active_profile=production`

## Integration Precedence

Runtime precedence is deterministic:

1. Explicit environment variables (highest)
2. Profile config values from `prompt_flow.config.json`
3. Prompt frontmatter defaults
4. Script built-ins (lowest fallback)

This keeps emergency/manual overrides possible while making profile behavior the
default for normal execution.

## Implementation Order

Use this order for safe rollout and repeatability:

1. Create/update `prompt_flow.config.json` and validate it.
2. Update `prompt-preflight` to stamp profile-driven policy values.
3. Update `prompt-exec` to apply profile defaults at runtime.
4. Update `prompt-pipeline` to consume profile defaults and forward overrides to `prompt-exec`.
5. Run mini experiment in `apps/deployment_pipeline/` (small prompt set, wipe/re-run).
6. Run full pipeline only after mini experiment passes.

Why full pipeline last:

- it confirms end-to-end behavior after deterministic gates are already proven in a
  constrained test run
- it prevents large-scale retries while policy integration is still being tuned
