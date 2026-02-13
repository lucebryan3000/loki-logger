#!/usr/bin/env bash
set -euo pipefail

# One-command deterministic mini pipeline harness:
# - contract gate
# - production run
# - wipe
# - poc run
# - verification summaries

usage() {
  cat <<'USAGE'
Usage: run_mini.sh [options]

Run the deployment_pipeline mini experiment end-to-end.

Options:
  --root <path>         Experiment root (default: apps/deployment_pipeline)
  --timeout-prod <sec>  Pipeline timeout for production pass (default: 240)
  --timeout-poc <sec>   Pipeline timeout for poc pass (default: 180)
  --keep-between         Skip wipe between production and poc runs
  --skip-production      Skip production pass
  --skip-poc             Skip poc pass
  -h, --help            Show help

Example:
  apps/deployment_pipeline/run_mini.sh --root apps/deployment_pipeline
USAGE
}

ROOT="apps/deployment_pipeline"
TIMEOUT_PROD=240
TIMEOUT_POC=180
KEEP_BETWEEN=0
SKIP_PROD=0
SKIP_POC=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$2"; shift 2 ;;
    --timeout-prod)
      TIMEOUT_PROD="$2"; shift 2 ;;
    --timeout-poc)
      TIMEOUT_POC="$2"; shift 2 ;;
    --keep-between)
      KEEP_BETWEEN=1; shift ;;
    --skip-production)
      SKIP_PROD=1; shift ;;
    --skip-poc)
      SKIP_POC=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 2 ;;
  esac
done

ROOT="$(realpath -m "$ROOT")"
PROMPTS_DIR="$ROOT/prompts"
OUT_DIR="$ROOT/out"

[[ -d "$ROOT" ]] || { echo "missing root: $ROOT" >&2; exit 2; }

wipe_state() {
  rm -f "$OUT_DIR/phase1.txt" "$OUT_DIR/phase2.txt"
  rm -f "$PROMPTS_DIR/.prompt-pipeline.state"
  rm -f "$PROMPTS_DIR/.prompt-pipeline.failed"
  rm -f "$PROMPTS_DIR/.prompt-pipeline.log.jsonl"
  rm -f "$PROMPTS_DIR/.prompt-pipeline.pending.preview.txt"
  rm -f "$PROMPTS_DIR/.prompt-pipeline.plan.txt"
  rm -f "$PROMPTS_DIR/.prompt-pipeline.resume.env"
  rm -f "$PROMPTS_DIR/.prompt-pipeline.lock"
  rm -f "$PROMPTS_DIR/.prompt-pipeline.HOLD"
  rm -rf "$PROMPTS_DIR/logs"
  mkdir -p "$OUT_DIR"
}

run_gate() {
  python3 "$ROOT/check_frontmatter_contract.py" --root "$PROMPTS_DIR" --json
}

run_verify() {
  python3 "$ROOT/verify_mini.py" --root "$ROOT"
}

run_pipeline() {
  local profile="$1"
  local timeout="$2"
  echo "== pipeline profile=${profile} timeout=${timeout}s =="
  PROMPT_FLOW_PROFILE="$profile" \
  /home/luce/.codex/skills/prompt-pipeline/scripts/prompt_pipeline.sh \
    --root "$PROMPTS_DIR" \
    --count 2 \
    --max-retries 0 \
    --timeout-sec "$timeout" \
    --profile "$profile"
}

echo "== contract gate =="
run_gate

if [[ "$SKIP_PROD" -eq 0 ]]; then
  echo "== wipe =="
  wipe_state
  run_pipeline "production" "$TIMEOUT_PROD"
  echo "== verify production =="
  run_verify
fi

if [[ "$SKIP_POC" -eq 0 ]]; then
  if [[ "$KEEP_BETWEEN" -eq 0 ]]; then
    echo "== wipe =="
    wipe_state
  fi
  run_pipeline "poc" "$TIMEOUT_POC"
  echo "== verify poc =="
  run_verify
fi

echo "== done =="
