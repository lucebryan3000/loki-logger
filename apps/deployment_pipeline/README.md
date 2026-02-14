# Deployment Pipeline Mini Experiment

This folder is a deterministic mini harness to validate prompt lifecycle behavior:

- `draft` (ChatGPT-authored frontmatter hints)
- `preflight` (`prompt-preflight` normalization/policy stamping)
- `exec` (`prompt-exec` block execution + completion gate)
- `pipeline` (`prompt-pipeline` orchestration and stage policy stamping)

## Layout

- `prompts/prompt-01-mini.md`
- `prompts/prompt-02-mini.md`
- `canary/prompt-03-canary-fail.md`
- `out/phase1.txt`
- `out/phase2.txt`
- `templates/chatgpt_prompt_template.md`
- `templates/chatgpt_prd_to_12_prompts_template.md`
- `check_frontmatter_contract.py`
- `check_pipeline_runner_contract.py`
- `verify_mini.py`
- `run_mini.sh`

Pipeline state files (generated under `prompts/`):

- `.prompt-pipeline.state`
- `.prompt-pipeline.failed`
- `.prompt-pipeline.log.jsonl`
- `.prompt-pipeline.summary.json`
- `.prompt-pipeline.plan.txt`
- `.prompt-pipeline.pending.preview.txt`
- `logs/prompt-pipeline_<run_utc>/*.log`

## Run (Production Profile)

```bash
PROMPT_FLOW_PROFILE=production \
/home/luce/.codex/skills/prompt-pipeline/scripts/prompt_pipeline.sh \
  --root /home/luce/apps/loki-logging/apps/deployment_pipeline/prompts \
  --count 2 \
  --max-retries 0 \
  --timeout-sec 240 \
  --exec-mode script \
  --profile production
```

Or use the one-command harness:

```bash
apps/deployment_pipeline/run_mini.sh --root apps/deployment_pipeline
```

The harness runs two deterministic gates before the mini pipeline:
- `check_pipeline_runner_contract.py` (runner mode/range/hold summary regression checks)
- `check_frontmatter_contract.py` (prompt contract gate)

## Wipe + Re-Run (POC Profile)

```bash
rm -f apps/deployment_pipeline/out/phase1.txt apps/deployment_pipeline/out/phase2.txt
rm -f apps/deployment_pipeline/prompts/.prompt-pipeline.state
rm -f apps/deployment_pipeline/prompts/.prompt-pipeline.failed
rm -f apps/deployment_pipeline/prompts/.prompt-pipeline.log.jsonl
rm -f apps/deployment_pipeline/prompts/.prompt-pipeline.summary.json
rm -f apps/deployment_pipeline/prompts/.prompt-pipeline.pending.preview.txt
rm -f apps/deployment_pipeline/prompts/.prompt-pipeline.plan.txt
rm -f apps/deployment_pipeline/prompts/.prompt-pipeline.resume.env
rm -f apps/deployment_pipeline/prompts/.prompt-pipeline.lock
rm -f apps/deployment_pipeline/prompts/.prompt-pipeline.HOLD
rm -rf apps/deployment_pipeline/prompts/logs

PROMPT_FLOW_PROFILE=poc \
/home/luce/.codex/skills/prompt-pipeline/scripts/prompt_pipeline.sh \
  --root /home/luce/apps/loki-logging/apps/deployment_pipeline/prompts \
  --count 2 \
  --max-retries 0 \
  --timeout-sec 180 \
  --exec-mode script \
  --profile poc
```

## Canary Fail-Fast Test

Use this isolated canary root to validate fail-fast and parking behavior:

```bash
rm -f apps/deployment_pipeline/canary/.prompt-pipeline.*
rm -f apps/deployment_pipeline/canary/.prompt-pipeline.summary.json
rm -rf apps/deployment_pipeline/canary/logs

PIPELINE_FAIL_FAST_THRESHOLD=1 \\
PIPELINE_MAX_TOTAL_FAILURES=1 \\
PROMPT_FLOW_PROFILE=production \\
/home/luce/.codex/skills/prompt-pipeline/scripts/prompt_pipeline.sh \\
  --root /home/luce/apps/loki-logging/apps/deployment_pipeline/canary \\
  --count 1 \\
  --max-retries 0 \\
  --timeout-sec 120 \\
  --exec-mode script \\
  --profile production
```

Expected: non-zero exit (`10` or `11`), canary prompt added to `.prompt-pipeline.failed`,
and hold details written to log/hold files.

## Expected Pass Criteria

- `out/phase1.txt` exists and contains `phase1_ok`.
- `out/phase2.txt` exists and contains `phase2_ok`.
- `.prompt-pipeline.log.jsonl` ends with `pipeline_done` and `fail_total=0`.
- `.prompt-pipeline.state` contains both prompt IDs.
- Prompt frontmatter contains:
  - `prompt_flow.stages.preflight.*`
  - `prompt_flow.stages.exec.*`
  - `prompt_flow.stages.pipeline.*`

## Profile Notes

Top-5 runtime toggles come from `scripts/codex-sprint/prompt_flow.config.json` via
`scripts/codex-sprint/prompt_flow_profile.py`.

Runtime precedence is:

1. Explicit env overrides (`PROMPT_EXEC_*`, pipeline env)
2. Profile config values
3. Prompt frontmatter policy values
4. Script defaults
