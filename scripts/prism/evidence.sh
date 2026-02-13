#!/usr/bin/env bash
set -euo pipefail

# Evidence v3 (repo-owned):
#   temp/codex/evidence/<prompt-name>/<run-id-local>/
# Files per run:
#   exec.log (combined stdout/stderr)
#   events.ndjson (append-only structured registry)
#
# Environment:
#   REPO_ROOT (required by callers; defaults to pwd)
#   CODEX_PROMPT_NAME (optional; defaults "prism")

prism_init() {
  : "${REPO_ROOT:=$(pwd)}"
  : "${CODEX_PROMPT_NAME:=prism}"

  # directory-safe local run id + human label
  export RUN_LOCAL_ID
  RUN_LOCAL_ID="$(date +%Y%m%dT%H%M%S)"
  export RUN_LOCAL_LABEL
  RUN_LOCAL_LABEL="$(date +%I:%M
