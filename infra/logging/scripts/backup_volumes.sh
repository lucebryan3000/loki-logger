#!/usr/bin/env bash
set -euo pipefail

out_dir="${1:-/home/luce/apps/loki-logging/_build/logging/backups}"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$out_dir/$ts"

for vol in logging-grafana-data logging-loki-data logging-prometheus-data; do
  docker run --rm -v "${vol}:/from:ro" -v "$out_dir/$ts:/to" alpine:3.20 sh -lc "cd /from && tar -czf /to/${vol}.tgz ."
done

echo "backup_dir=$out_dir/$ts"
