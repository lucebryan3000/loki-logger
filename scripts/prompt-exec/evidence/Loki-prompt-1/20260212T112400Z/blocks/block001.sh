#!/usr/bin/env bash
set -euo pipefail
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T112400Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
set -euo pipefail

RUN_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
EVID="/home/luce/apps/loki-logging/.artifacts/prism/evidence/${RUN_UTC}"
mkdir -p "$EVID"
chmod 700 "$EVID"

exec > >(tee -a "$EVID/exec.log") 2> >(tee -a "$EVID/exec.err.log" >&2)

echo "RUN_UTC=$RUN_UTC" | tee "$EVID/run_id.txt"

# Must be on expected host path
test -d /home/luce || { echo "FAIL: /home/luce missing"; exit 1; }

# Tools
for bin in git docker curl sed awk grep ss; do
  command -v "$bin" >/dev/null || { echo "FAIL: missing tool: $bin"; exit 1; }
done

# Docker daemon + compose
docker ps >/dev/null || { echo "FAIL: docker daemon not usable"; exit 1; }
docker compose version >/dev/null || { echo "FAIL: docker compose missing"; exit 1; }

# Ports must be free on loopback binds
if ss -ltnp | grep -E '127\.0\.0\.1:9001|127\.0\.0\.1:9004' >/dev/null; then
  echo "FAIL: required loopback ports already in use (9001/9004)"; ss -ltnp | grep -E '127\.0\.0\.1:9001|127\.0\.0\.1:9004' || true
  exit 1
fi

# journald posture evidence (not a blocker; record)
if test -d /var/log/journal; then
  echo "journald=persistent" | tee "$EVID/journald_posture.txt"
else
  echo "journald=runtime_only" | tee "$EVID/journald_posture.txt"
fi

# Repo presence / remote validation
if test -d /home/luce/apps/loki-logging/.git; then
  cd /home/luce/apps/loki-logging
  REMOTE_URL="$(git remote get-url origin || true)"
  echo "origin=$REMOTE_URL" | tee "$EVID/git_origin.txt"
  if [ "$REMOTE_URL" != "https://github.com/lucebryan3000/loki-logger.git" ] && [ "$REMOTE_URL" != "git@github.com:lucebryan3000/loki-logger.git" ]; then
    echo "FAIL: repo exists but origin remote mismatch"; exit 1
  fi
else
  mkdir -p /home/luce/apps
fi

# Record versions
{
  echo "date_utc=$(date -u --iso-8601=seconds)"
  echo "uname=$(uname -a)"
  echo "docker=$(docker version --format '{{.Server.Version}}' || true)"
  echo "compose=$(docker compose version 2>/dev/null || true)"
} | tee "$EVID/versions.txt"

echo "PHASE0_OK" | tee "$EVID/phase0_ok.txt"
