# Codex Prompt State: Direct Integration Test Plan (prompt-exec)

## Goal
Validate `prompt-exec` after direct migration from inline state logic to `codex-prompt-state`, without dual/shadow mode.

## Test Assets
Prompt fixtures are in:
- `/home/luce/apps/loki-logging/_build/Sprint-3/prompts/codex-prompt-state-tests/`

Included prompts:
- `cps-01-success.md`
- `cps-02-fail-fast.md`
- `cps-03-noncritical.md`
- `cps-04-completion-gate-fail.md`
- `cps-05-warning-halt.md`

## Assumptions
- `prompt-exec` is already integrated with `codex-prompt-state`.
- New store root is `temp/codex-prompt-state`.
- Autocommit/autopush/move-to-completed are disabled via prompt frontmatter in this suite.

## Optional Config Defaults (.env/.config)
Use repo-local defaults during testing:

```bash
cat > /home/luce/apps/loki-logging/.codex-prompt-state.env <<'ENV'
CODEX_PROMPT_STATE_ENABLED=1
CODEX_PROMPT_STATE_STORE_ROOT=/home/luce/apps/loki-logging/temp/codex-prompt-state
CODEX_PROMPT_STATE_WORK_ROOT=/tmp/codex-prompt-state-work
CODEX_PROMPT_STATE_EVIDENCE_MODE=minimal
CODEX_PROMPT_STATE_FRONTMATTER_ENABLED=1
CODEX_PROMPT_STATE_FRONTMATTER_POLICY=merge
ENV
```

## Test Matrix
| ID | Prompt | Expected Exit | Expected Run Status | Primary Assertions |
|---|---|---:|---|---|
| T01 | `cps-01-success.md` | 0 | `success` | run recorded, completion gate pass/skip, output file exists |
| T02 | `cps-02-fail-fast.md` | 0 | `success` | expected-negative marker handles known failure code and run continues |
| T03 | `cps-03-noncritical.md` | 0 | `success` | noncritical failure tolerated, block 2 success recorded |
| T04 | `cps-04-completion-gate-fail.md` | 0 | `success` | deterministic gate proof artifact makes completion gate pass |
| T05a | `cps-05-warning-halt.md` (strict probe) | 2 | `blocked` | strict warning policy blocks when allowlist is disabled |
| T05b | `cps-05-warning-halt.md` (allowlisted) | 0 | `success` | scoped allowlist allows execution under halt policy |

## Execution Steps
1. Reset test outputs only:

```bash
REPO="/home/luce/apps/loki-logging"
rm -rf "$REPO/temp/codex-prompt-state-tests/output"
mkdir -p "$REPO/temp/codex-prompt-state-tests/output"
```

2. Run prompts one by one and capture exit codes:

```bash
REPO="/home/luce/apps/loki-logging"
PROMPTS_DIR="$REPO/_build/Sprint-3/prompts/codex-prompt-state-tests"
PROMPT_EXEC_BIN="/home/luce/.local/bin/prompt-exec"

"$PROMPT_EXEC_BIN" "$PROMPTS_DIR/cps-01-success.md"; echo "T01 rc=$?"
"$PROMPT_EXEC_BIN" "$PROMPTS_DIR/cps-02-fail-fast.md"; echo "T02 rc=$?"
"$PROMPT_EXEC_BIN" "$PROMPTS_DIR/cps-03-noncritical.md"; echo "T03 rc=$?"
"$PROMPT_EXEC_BIN" "$PROMPTS_DIR/cps-04-completion-gate-fail.md"; echo "T04 rc=$?"
PROMPT_EXEC_WARN_ALLOW_REGEX='(?!)' "$PROMPT_EXEC_BIN" "$PROMPTS_DIR/cps-05-warning-halt.md"; echo "T05a rc=$?"
"$PROMPT_EXEC_BIN" "$PROMPTS_DIR/cps-05-warning-halt.md"; echo "T05b rc=$?"
```

3. Validate state rows for the test prompt slugs:

```bash
python3 - <<'PY'
import json
from pathlib import Path

repo = Path('/home/luce/apps/loki-logging')
store = repo / 'temp/codex-prompt-state'
runs = store / 'runs.jsonl'

expected = {
    'cps-01-success': 'success',
    'cps-02-fail-fast': 'success',
    'cps-03-noncritical': 'success',
    'cps-04-completion-gate-fail': 'success',
    'cps-05-warning-halt': 'success',
}

records = {}
if runs.is_file():
    for line in runs.read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        obj = json.loads(line)
        slug = obj.get('prompt_slug', '')
        if slug in expected:
            records[slug] = obj

missing = [k for k in expected if k not in records]
if missing:
    print('MISSING_RUNS', missing)

for slug, want in expected.items():
    got = records.get(slug, {}).get('status')
    print(f'{slug}: status={got} expected={want}')
PY
```

4. Validate completion-gate pass was captured for T04:

```bash
python3 - <<'PY'
import json
from pathlib import Path

runs = Path('/home/luce/apps/loki-logging/temp/codex-prompt-state/runs.jsonl')
for line in runs.read_text(encoding='utf-8').splitlines():
    if not line.strip():
        continue
    obj = json.loads(line)
    if obj.get('prompt_slug') == 'cps-04-completion-gate-fail':
        print('completion_gate=', obj.get('completion_gate'))
        print('status=', obj.get('status'))
PY
```

5. Validate expected output files:

```bash
test -f /home/luce/apps/loki-logging/temp/codex-prompt-state-tests/output/cps-01-success.txt
test -f /home/luce/apps/loki-logging/temp/codex-prompt-state-tests/output/cps-02-expected-negative-ok.txt
test -f /home/luce/apps/loki-logging/temp/codex-prompt-state-tests/output/cps-03-success.txt
test -f /home/luce/apps/loki-logging/temp/codex-prompt-state-tests/output/cps-04-gate-proof.json
test -f /home/luce/apps/loki-logging/temp/codex-prompt-state-tests/output/cps-05-warning-allowed.txt
```

## Pass Criteria
- Remediated prompts (T01, T02, T03, T04, T05b) finish with `success`.
- Strict probe (T05a) blocks with warning policy as expected.
- `runs.jsonl` contains one run row per test prompt.
- `state.latest.json` (or equivalent latest index) resolves latest status for each test prompt.
- `artifacts.jsonl` (or equivalent) includes work artifacts for all successful runs.
- No git commit/push is performed by test prompts.

## Notes
- If T05 returns `failed` instead of `blocked`, inspect warning-mode implementation and status mapping; either is acceptable only if execution is halted pre-command and warning metadata is persisted.
- If your integration keeps legacy path names temporarily, replace `temp/codex-prompt-state` in commands with the active store root.
