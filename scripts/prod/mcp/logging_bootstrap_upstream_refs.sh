#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: logging_bootstrap_upstream_refs.sh

Pin upstream reference repositories (Grafana, Loki, Alloy, Prometheus)
by recording their remote HEAD refs into tracked files under infra/logging/.

Outputs:
  infra/logging/upstream-references.lock   Machine-readable lock file
  infra/logging/upstream-references.md     Human-readable table

Environment:
  CLONE_MODE   1 (default) shallow-clone repos into _build/upstream-sources/
               0 record refs only, no local clones

Repos pinned:
  grafana/grafana, grafana/loki, grafana/alloy, prometheus/prometheus
EOF
  exit 0
fi

# Bootstrap and pin upstream reference repositories used by the Loki logging prompt.
# - Always records remote HEAD refs into tracked files under infra/logging.
# - Optionally shallow-clones repos into _build/ (ignored by git) for local inspection.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
OUT_LOCK="${REPO_ROOT}/infra/logging/upstream-references.lock"
OUT_MD="${REPO_ROOT}/infra/logging/upstream-references.md"
CLONE_MODE="${CLONE_MODE:-1}" # 1=yes, 0=no
CLONE_DIR="${CLONE_DIR:-${REPO_ROOT}/_build/upstream-sources}"

RUN_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

repos=(
  "grafana|https://github.com/grafana/grafana.git"
  "loki|https://github.com/grafana/loki.git"
  "alloy|https://github.com/grafana/alloy.git"
  "prometheus|https://github.com/prometheus/prometheus.git"
)

mkdir -p "$(dirname "$OUT_LOCK")"
if [ "$CLONE_MODE" = "1" ]; then
  mkdir -p "$CLONE_DIR"
fi

{
  echo "# upstream-references.lock"
  echo "generated_utc=${RUN_UTC}"
  echo "repo_root=${REPO_ROOT}"
  echo "clone_mode=${CLONE_MODE}"
  if [ "$CLONE_MODE" = "1" ]; then
    echo "clone_dir=${CLONE_DIR}"
  fi
} >"$OUT_LOCK"

{
  echo "# Upstream References"
  echo
  echo "- Generated (UTC): \`${RUN_UTC}\`"
  echo "- Source: \`_build/Sprint-1/Loki-logging-1.md\` GitHub repos section"
  echo "- Clone mode: \`${CLONE_MODE}\`"
  if [ "$CLONE_MODE" = "1" ]; then
    echo "- Clone directory: \`${CLONE_DIR}\`"
  fi
  echo
  echo "| Name | URL | Default Branch | Remote HEAD | Local Path | Local SHA |"
  echo "|---|---|---|---|---|---|"
} >"$OUT_MD"

for entry in "${repos[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"

  # Resolve remote default branch + HEAD commit.
  symref="$(git ls-remote --symref "$url" HEAD)"
  default_branch="$(printf '%s\n' "$symref" | awk '/^ref:/ {gsub("refs/heads/","",$2); print $2; exit}')"
  remote_sha="$(printf '%s\n' "$symref" | awk '/^[0-9a-f]{40}\tHEAD$/ {print $1; exit}')"

  local_path="<none>"
  local_sha="<none>"
  if [ "$CLONE_MODE" = "1" ]; then
    local_path="${CLONE_DIR}/${name}"
    if [ ! -d "${local_path}/.git" ]; then
      git clone --depth 1 --branch "$default_branch" "$url" "$local_path" >/dev/null 2>&1
    fi
    git -C "$local_path" fetch origin "$remote_sha" --depth 1 >/dev/null 2>&1
    git -C "$local_path" checkout -q "$remote_sha" >/dev/null 2>&1
    local_sha="$(git -C "$local_path" rev-parse HEAD 2>/dev/null || echo "<unknown>")"
  fi

  {
    echo
    echo "[${name}]"
    echo "url=${url}"
    echo "default_branch=${default_branch}"
    echo "remote_head=${remote_sha}"
    echo "local_path=${local_path}"
    echo "local_sha=${local_sha}"
  } >>"$OUT_LOCK"

  printf '| %s | %s | %s | `%s` | `%s` | `%s` |\n' \
    "$name" "$url" "$default_branch" "$remote_sha" "$local_path" "$local_sha" >>"$OUT_MD"
done

echo "Wrote:"
echo "  ${OUT_LOCK}"
echo "  ${OUT_MD}"
if [ "$CLONE_MODE" = "1" ]; then
  echo "  ${CLONE_DIR}"
fi
