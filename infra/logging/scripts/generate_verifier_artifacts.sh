#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-/home/luce/apps/loki-logging}"
OUTDIR="${OUTDIR:-$ROOT/_build/logging}"
SRC_DIR="$ROOT/infra/logging/grafana/dashboards/sources"
DIM_DIR="$ROOT/infra/logging/grafana/dashboards/dimensions"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: generate_verifier_artifacts.sh

Generates strict-verifier governance inputs.
Default output dir is _build/logging with writable fallback to /tmp/logging-artifacts.
  - log_source_values.json
  - chosen_dimension.txt
  - dimension_values.txt
EOF
  exit 0
fi

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

mkdir -p "$OUTDIR" 2>/dev/null || true
if ! touch "$OUTDIR/.verifier_artifacts_write_test" 2>/dev/null; then
  OUTDIR="/tmp/logging-artifacts"
  mkdir -p "$OUTDIR"
else
  rm -f "$OUTDIR/.verifier_artifacts_write_test"
fi

mapfile -t SRC_VALUES < <(
  cd "$SRC_DIR"
  ls codeswarm-src-*.json 2>/dev/null | sed -E 's/^codeswarm-src-//; s/[.]json$//' | sort -u
)

SRC_JSON="$OUTDIR/log_source_values.json"
printf '%s\n' "${SRC_VALUES[@]}" | jq -R -s 'split("\n")[:-1] | {count:length, values:.}' > "$SRC_JSON"

DIM_INDEX_FILE="$(cd "$DIM_DIR" && ls codeswarm-dim-index-*.json 2>/dev/null | sort | head -n 1 || true)"
if [[ -z "$DIM_INDEX_FILE" ]]; then
  echo "No dimension index dashboard found under $DIM_DIR" >&2
  exit 2
fi

DIM_NAME="$(echo "$DIM_INDEX_FILE" | sed -E 's/^codeswarm-dim-index-//; s/[.]json$//')"
DIM_SLUG="$(echo "$DIM_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"

echo "$DIM_NAME" > "$OUTDIR/chosen_dimension.txt"

mapfile -t DIM_VALUES < <(
  cd "$DIM_DIR"
  ls "codeswarm-dim-${DIM_SLUG}-"*.json 2>/dev/null \
    | sed -E "s/^codeswarm-dim-${DIM_SLUG}-//; s/[.]json$//" \
    | sort -u
)

printf '%s\n' "${DIM_VALUES[@]}" > "$OUTDIR/dimension_values.txt"

echo "WROTE=$SRC_JSON"
echo "WROTE=$OUTDIR/chosen_dimension.txt"
echo "WROTE=$OUTDIR/dimension_values.txt"
