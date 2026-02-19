#!/usr/bin/env bash
set -euo pipefail

src_dir="${1:?usage: restore_volumes.sh <backup_dir>}"

for vol in logging_grafana-data logging_loki-data logging_prometheus-data; do
  test -f "$src_dir/${vol}.tgz"
  docker run --rm -v "${vol}:/to" -v "$src_dir:/from:ro" alpine:3.20 sh -lc "cd /to && tar -xzf /from/${vol}.tgz"
done

echo "restore=ok source=$src_dir"
