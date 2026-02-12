#!/usr/bin/env bash
set -euo pipefail
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T112400Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
set -euo pipefail
cd /home/luce/apps/loki-logging

ENVF="infra/logging/.env"
umask 077

if [ ! -f "$ENVF" ]; then
  touch "$ENVF"
  chmod 600 "$ENVF"
fi

# helper: set KEY=VALUE if missing (without printing secret)
set_kv_if_missing() {
  local key="$1"
  local val="$2"
  if ! grep -qE "^${key}=" "$ENVF"; then
    printf "%s=%s\n" "$key" "$val" >> "$ENVF"
  fi
}

# Generate secrets (do not echo to stdout)
GRAFANA_ADMIN_PASSWORD="$(openssl rand -base64 36 | tr -d '\n' | tr '/+' '_-' | cut -c1-32)"
GRAFANA_SECRET_KEY="$(openssl rand -hex 32)"

set_kv_if_missing "GRAFANA_ADMIN_USER" "admin"
set_kv_if_missing "GRAFANA_ADMIN_PASSWORD" "$GRAFANA_ADMIN_PASSWORD"
set_kv_if_missing "GRAFANA_SECRET_KEY" "$GRAFANA_SECRET_KEY"

# Record only keys present (not values)
sed -E 's/=.*/=REDACTED/' "$ENVF" | tee "$EVID/env_redacted.txt" >/dev/null
stat -c "%a %U:%G %n" "$ENVF" | tee "$EVID/env_perms.txt"
