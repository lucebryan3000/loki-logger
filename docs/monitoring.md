# Monitoring and Health Checks

This runbook explains how to validate the Loki logging stack comprehensively.

Scope:
- Compose project: `logging`
- Compose file: `infra/logging/docker compose -p logging.observability.yml`
- Host endpoints:
  - Grafana: `http://127.0.0.1:9001`
  - Prometheus: `http://127.0.0.1:9004`
- Internal endpoint:
  - Loki: `http://loki:3100` (inside Docker network `obs`)

## Conventions

Set these once per shell:

```bash
set -euo pipefail
REPO="/home/luce/apps/loki-logging"
cd "$REPO"
export COMPOSE_PROJECT_NAME=logging
OBS="infra/logging/docker compose -p logging.observability.yml"
```

## Health Levels

Use these levels depending on urgency:

- Level 1 (`quick`): service up/down and core readiness.
- Level 2 (`standard`): scrape health, rules, retention, and ingest proof.
- Level 3 (`deep`): logs, resource pressure, storage/network posture, and drift checks.

## Level 1: Quick Health (1-2 min)

### 1) Service status

```bash
docker compose -f "$OBS" ps
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' \
  | rg 'NAMES|logging-(grafana|loki|prometheus|alloy|host-monitor|docker-metrics)-1'
```

Expected:
- all six services are `Up`
- `grafana` publishes `0.0.0.0:9001->3000`
- `prometheus` publishes `0.0.0.0:9004->9090`

### 2) Core endpoint readiness

```bash
curl -sf --connect-timeout 5 --max-time 20 'http://127.0.0.1:9001/api/health' | jq -c .
curl -sf --connect-timeout 5 --max-time 20 'http://127.0.0.1:9004/-/ready'
docker run --rm --network obs curlimages/curl:8.6.0 -sf 'http://loki:3100/ready'
```

Expected:
- Grafana returns JSON with `"database":"ok"`
- Prometheus returns `Prometheus Server is Ready.`
- Loki returns `ready`

### 3) Built-in stack check script

```bash
scripts/prod/mcp/logging_stack_health.sh
```

Expected:
- `grafana_ok=1`
- `prometheus_ok=1`

## Level 2: Standard Health (5-10 min)

### 4) Prometheus target matrix

```bash
curl -sf 'http://127.0.0.1:9004/api/v1/targets' \
  | jq -r '.data.activeTargets[] | [.labels.job,.scrapeUrl,.health,(.lastError//"-")] | @tsv' \
  | sort
```

Expected jobs `up`:
- `alloy`
- `docker-metrics`
- `host-monitor`
- `loki`
- `prometheus`

### 5) `up` query sanity

```bash
curl -sf 'http://127.0.0.1:9004/api/v1/query?query=up' \
  | jq -r '.data.result[] | [.metric.job,.value[1]] | @tsv' \
  | sort
```

Expected:
- each expected job has value `1`

### 6) Prometheus retention and flags

```bash
curl -sf 'http://127.0.0.1:9004/api/v1/status/flags' \
  | jq -r '.data["storage.tsdb.retention.time"], .data["storage.tsdb.path"]'
```

Expected:
- retention is `15d`
- storage path is `/prometheus`

### 7) Rule and alert posture

```bash
curl -sf 'http://127.0.0.1:9004/api/v1/rules' \
  | jq -r '"groups=\(.data.groups|length)", (.data.groups[] | [.file,.name,(.rules|length)] | @tsv)'

curl -sf 'http://127.0.0.1:9004/api/v1/alerts' \
  | jq -r '"active_alerts=\(.data.alerts|length)"'
```

Expected:
- at least one rule group loaded
- no unexpected active alerts

### 8) Loki query path

```bash
NOW_NS=$(date +%s%N)
FROM_NS=$((NOW_NS-10*60*1000000000))

docker run --rm --network obs curlimages/curl:8.6.0 -sfG \
  --data-urlencode 'query={env=~".+"}' \
  --data-urlencode "start=${FROM_NS}" \
  --data-urlencode "end=${NOW_NS}" \
  --data-urlencode 'limit=20' \
  --data-urlencode 'direction=BACKWARD' \
  'http://loki:3100/loki/api/v1/query_range' \
  | jq -r '.status, ("streams=" + ((.data.result|length)|tostring))'
```

Expected:
- `status` is `success`
- stream count is non-zero in normal operation

### 9) End-to-end ingest proof

```bash
TESTLINE="healthproof-$(date -u +%Y%m%dT%H%M%SZ)"
echo "$TESTLINE" >> /home/luce/apps/vLLM/_data/mcp-logs/mcp-test.log
sleep 3

NOW_NS=$(date +%s%N)
FROM_NS=$((NOW_NS-15*60*1000000000))

docker run --rm --network obs curlimages/curl:8.6.0 -sfG \
  --data-urlencode "query={env=~\".+\",log_source=\"codeswarm_mcp\"} |= \"${TESTLINE}\"" \
  --data-urlencode "start=${FROM_NS}" \
  --data-urlencode "end=${NOW_NS}" \
  --data-urlencode 'limit=20' \
  --data-urlencode 'direction=BACKWARD' \
  'http://loki:3100/loki/api/v1/query_range' \
  | jq -r --arg t "$TESTLINE" '"testline="+$t, "status="+.status, "matches="+((.data.result|length)|tostring)'
```

Expected:
- `status=success`
- `matches>=1`

## Level 3: Deep Health (10-20 min)

### 10) Config validity checks

```bash
export COMPOSE_PROJECT_NAME=logging
docker compose -f "$OBS" config >/tmp/compose.rendered.yml

PROM_IMAGE=$(sed -nE 's/^[[:space:]]*image:[[:space:]]*(prom\/prometheus:[^[:space:]]+).*/\1/p' "$OBS" | head -n1)
[ -n "$PROM_IMAGE" ] || PROM_IMAGE='prom/prometheus:latest'

docker run --rm --entrypoint /bin/promtool \
  -v "$PWD/infra/logging/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  "$PROM_IMAGE" \
  check config /etc/prometheus/prometheus.yml
```

Expected:
- compose render succeeds
- promtool returns `SUCCESS`

### 11) Recent error trend by service

```bash
for s in grafana prometheus loki alloy host-monitor docker-metrics; do
  echo "=== $s (last 5m) ==="
  COMPOSE_PROJECT_NAME=logging docker compose -f "$OBS" logs --since=5m --no-color "$s" \
    | rg -in 'error|fatal|panic|failed|status=400|too far behind|empty ring' \
    | sed -n '1,40p' || echo "none"
done
```

Interpretation:
- occasional startup warnings may be benign
- repeated fresh errors across intervals indicate active fault

### 12) Restart counters and runtime stability

```bash
for c in logging-grafana-1 logging-prometheus-1 logging-loki-1 logging-alloy-1 logging-host-monitor-1 logging-docker-metrics-1; do
  docker inspect -f '{{.Name}}\trestarts={{.RestartCount}}\thealth={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}\tstarted={{.State.StartedAt}}' "$c"
done
```

Expected:
- `restarts=0` (or stable and not increasing)

### 13) Resource and capacity checks

```bash
docker stats --no-stream --format '{{.Name}}\tCPU={{.CPUPerc}}\tMEM={{.MemUsage}}\tNET={{.NetIO}}\tBLOCK={{.BlockIO}}' \
  | rg 'logging-(grafana|prometheus|loki|alloy|host-monitor|docker-metrics)-1'

df -h / /var/lib/docker
docker system df
```

Watch for:
- sustained high CPU or memory growth
- low free disk on `/` or heavy Docker image/cache growth

### 14) Port/listener and exposure posture

```bash
ss -ltnp | rg ':9001|:9004|:3100|LISTEN'
sudo -n ufw status verbose
```

Expected:
- `9001` and `9004` bound to `0.0.0.0` (all interfaces, protected by UFW)
- UFW active with expected policy restricting access to LAN

## Troubleshooting Patterns

### A) Prometheus target down

1. Confirm container is running:

```bash
docker compose -f "$OBS" ps
```

2. Check target errors quickly:

```bash
curl -sf 'http://127.0.0.1:9004/api/v1/targets' \
  | jq -r '.data.activeTargets[] | select(.health!="up") | [.labels.job,.lastError,.scrapeUrl] | @tsv'
```

3. Inspect service logs:

```bash
docker compose -f "$OBS" logs --since=10m --no-color <service>
```

### B) Loki query returns empty or errors

1. Validate Loki ready:

```bash
docker run --rm --network obs curlimages/curl:8.6.0 -sf 'http://loki:3100/ready'
```

2. Run broad query over last 15 minutes:

```bash
NOW_NS=$(date +%s%N)
FROM_NS=$((NOW_NS-15*60*1000000000))
docker run --rm --network obs curlimages/curl:8.6.0 -sfG \
  --data-urlencode 'query={env=~".+"}' \
  --data-urlencode "start=${FROM_NS}" \
  --data-urlencode "end=${NOW_NS}" \
  --data-urlencode 'limit=50' \
  'http://loki:3100/loki/api/v1/query_range' | jq -r '.status, (.data.result|length)'
```

3. Check Alloy send errors:

```bash
docker compose -f "$OBS" logs --since=10m --no-color alloy | rg -in 'error|status=400|too far behind'
```

### C) Config drift suspicion

```bash
sha256sum \
  infra/logging/docker compose -p logging.observability.yml \
  infra/logging/loki-config.yml \
  infra/logging/alloy-config.alloy \
  infra/logging/prometheus/prometheus.yml \
  infra/logging/grafana/provisioning/datasources/loki.yml \
  infra/logging/grafana/provisioning/datasources/prometheus.yml \
  infra/logging/grafana/provisioning/dashboards/dashboards.yml
```

Compare against your last known-good snapshot in `docs/20-as-configured.md`.

## Optional: One-Command Comprehensive Snapshot

Use this when you want a timestamped health artifact:

```bash
OUT="temp/codex/monitoring/health-$(date -u +%Y%m%dT%H%M%SZ).txt"
mkdir -p "$(dirname "$OUT")"
{
  echo "# monitoring snapshot"
  date -u
  echo
  echo "## compose ps"
  docker compose -f "$OBS" ps
  echo
  echo "## endpoint health"
  curl -sf 'http://127.0.0.1:9001/api/health'
  echo
  curl -sf 'http://127.0.0.1:9004/-/ready'
  echo
  docker run --rm --network obs curlimages/curl:8.6.0 -sf 'http://loki:3100/ready'
  echo
  echo "## prometheus targets"
  curl -sf 'http://127.0.0.1:9004/api/v1/targets' | jq -r '.data.activeTargets[] | [.labels.job,.health,.lastError] | @tsv'
} | tee "$OUT"

echo "wrote: $OUT"
```

## Recovery Basics

If health checks fail after config changes:

```bash
# restart stack
COMPOSE_PROJECT_NAME=logging docker compose -f "$OBS" up -d

# if needed, recreate only a failing service
COMPOSE_PROJECT_NAME=logging docker compose -f "$OBS" up -d --force-recreate <service>
```

Re-run Level 1 and Level 2 checks after recovery.
