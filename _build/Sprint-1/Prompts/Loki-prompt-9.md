---
codex_reviewed_utc: '2026-02-12T00:00:00Z'
codex_revision: 2
codex_ready_to_execute: "yes"
codex_kind: task
codex_scope: multi-file
codex_targets:
  - infra/logging/grafana/dashboards/host_overview.json
  - infra/logging/grafana/dashboards/containers_overview.json
  - infra/logging/prometheus/rules/loki_logging_rules.yml
  - infra/logging/prometheus/prometheus.yml
  - infra/logging/docker-compose.observability.yml
codex_autocommit: "yes"
codex_move_to_completed: "yes"
codex_warn_gate: "yes"
codex_warn_mode: ask
codex_allow_noncritical: "yes"
codex_prompt_sha256_mode: "none"
codex_reason: "Runbook Phase G: provision baseline Grafana dashboards and seed Prometheus alert rules using Evidence v2."
---

# PHASE G — Provision Dashboards + Seed Alerts (Prometheus Rules)

## Objective
- Provision baseline Grafana dashboards from files (no click-ops).
- Seed Prometheus alerting rules under `infra/logging/prometheus/rules/`.
- Ensure Prometheus scrapes Loki and Alloy metrics.
- Capture evidence in `temp/.artifacts/prism/evidence/<RUN_UTC>/` via `scripts/prism/evidence.sh`.

## Affects
- `infra/logging/grafana/dashboards/host_overview.json`
- `infra/logging/grafana/dashboards/containers_overview.json`
- `infra/logging/prometheus/rules/loki_logging_rules.yml`
- `infra/logging/prometheus/prometheus.yml`
- `infra/logging/docker-compose.observability.yml`

## Conflict Report
- `OK`: Evidence v2 path is repo-local and ignored (`temp/.artifacts/...`).
- `OK`: Dashboard/rule provisioning is file-based and deterministic.
- `CONFLICT RESOLVED`: Prior draft was truncated; this version restores complete fenced blocks and acceptance criteria.

## Phase 0 — Preflight Gate (STOP if any FAIL)

```bash
set -euo pipefail

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

FAIL=0

need_cmd() {
  local c="$1"
  if command -v "$c" >/dev/null 2>&1; then
    echo "PASS: command '$c' found"
  else
    echo "FAIL: command '$c' missing"
    FAIL=1
  fi
}

need_file() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "PASS: file exists: $f"
  else
    echo "FAIL: missing file: $f"
    FAIL=1
  fi
}

need_cmd docker
need_cmd curl
need_cmd python3
need_cmd git
need_cmd rg

need_file "$REPO/scripts/prism/evidence.sh"
need_file "$REPO/infra/logging/docker-compose.observability.yml"
need_file "$REPO/infra/logging/prometheus/prometheus.yml"

if [ "$FAIL" -ne 0 ]; then
  echo "PRECHECK_FAIL"
  exit 1
fi

echo "PRECHECK_OK"
```

## Phase 1 — Dashboards + Rules + Validation

```bash
set -euo pipefail

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

source scripts/prism/evidence.sh
export REPO_ROOT="$REPO"
prism_init
prism_event phase_start phase="G" note="dashboards+alerts"

OBS_COMPOSE="${REPO}/infra/logging/docker-compose.observability.yml"
test -f "$OBS_COMPOSE" || { prism_event fail reason="missing_compose"; exit 1; }
PROJECT="$(awk '/^name:/{print $2; exit}' "$OBS_COMPOSE" 2>/dev/null || true)"
PROJECT="${PROJECT:-infra_observability}"
export COMPOSE_PROJECT_NAME="$PROJECT"
prism_event ctx compose_project="$PROJECT"

GRAFANA_DASH_DIR="infra/logging/grafana/dashboards"
PROM_DIR="infra/logging/prometheus"
PROM_YML="${PROM_DIR}/prometheus.yml"
PROM_RULES_DIR="${PROM_DIR}/rules"
PROM_RULES_FILE="${PROM_RULES_DIR}/loki_logging_rules.yml"

mkdir -p "$GRAFANA_DASH_DIR" "$PROM_RULES_DIR"

cat > "${GRAFANA_DASH_DIR}/host_overview.json" <<'JSON'
{
  "annotations": { "list": [] },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": {}, "overrides": [] },
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
      "id": 1,
      "options": { "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [
        { "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)", "refId": "A" }
      ],
      "title": "CPU Usage % (instance)",
      "type": "timeseries"
    },
    {
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": {}, "overrides": [] },
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 0 },
      "id": 2,
      "options": { "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [
        { "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100", "refId": "A" }
      ],
      "title": "Memory Usage % (instance)",
      "type": "timeseries"
    },
    {
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": {}, "overrides": [] },
      "gridPos": { "h": 8, "w": 24, "x": 0, "y": 8 },
      "id": 3,
      "options": { "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [
        {
          "expr": "100 - (node_filesystem_avail_bytes{fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\"}) * 100",
          "refId": "A"
        }
      ],
      "title": "Disk Usage % (mountpoint)",
      "type": "timeseries"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 39,
  "style": "dark",
  "tags": ["loki-logging", "baseline"],
  "templating": { "list": [] },
  "time": { "from": "now-30m", "to": "now" },
  "timepicker": {},
  "timezone": "browser",
  "title": "Host Overview (Baseline)",
  "uid": "host_overview_baseline",
  "version": 1
}
JSON

cat > "${GRAFANA_DASH_DIR}/containers_overview.json" <<'JSON'
{
  "annotations": { "list": [] },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": {}, "overrides": [] },
      "gridPos": { "h": 9, "w": 24, "x": 0, "y": 0 },
      "id": 1,
      "options": { "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [
        {
          "expr": "topk(10, rate(container_cpu_usage_seconds_total{container!=\"\",container!=\"POD\"}[5m]))",
          "refId": "A"
        }
      ],
      "title": "Top 10 Containers by CPU (rate)",
      "type": "timeseries"
    },
    {
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": {}, "overrides": [] },
      "gridPos": { "h": 9, "w": 24, "x": 0, "y": 9 },
      "id": 2,
      "options": { "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [
        {
          "expr": "topk(10, container_memory_working_set_bytes{container!=\"\",container!=\"POD\"})",
          "refId": "A"
        }
      ],
      "title": "Top 10 Containers by Memory (working set)",
      "type": "timeseries"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 39,
  "style": "dark",
  "tags": ["loki-logging", "baseline"],
  "templating": { "list": [] },
  "time": { "from": "now-30m", "to": "now" },
  "timepicker": {},
  "timezone": "browser",
  "title": "Containers Overview (Baseline)",
  "uid": "containers_overview_baseline",
  "version": 1
}
JSON

prism_hash "${GRAFANA_DASH_DIR}/host_overview.json" "${GRAFANA_DASH_DIR}/containers_overview.json"
prism_event dashboards created="2" dir="$GRAFANA_DASH_DIR"

cat > "$PROM_RULES_FILE" <<'YAML'
groups:
  - name: loki_logging_v1
    rules:
      - alert: TargetDown
        expr: up == 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Prometheus target down"
          description: "Target {{ $labels.job }} at {{ $labels.instance }} is down."

      - alert: NodeDiskSpaceLow
        expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) < 0.10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk space low (<10%)"
          description: "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} is below 10% free."

      - alert: NodeMemoryHigh
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Memory usage high (>90%)"
          description: "Host {{ $labels.instance }} memory usage above 90%."

      - alert: NodeCPUHigh
        expr: (100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU usage high (>90%)"
          description: "Host {{ $labels.instance }} CPU usage above 90%."
YAML

prism_hash "$PROM_RULES_FILE"
prism_event alerts rules_file="$PROM_RULES_FILE"

python3 - <<'PY'
from pathlib import Path
import re

p = Path('/home/luce/apps/loki-logging/infra/logging/prometheus/prometheus.yml')
t = p.read_text(encoding='utf-8')

if 'rule_files:' not in t:
    m = re.search(r'global:\n(?:.*\n)+?\n', t)
    ins = 'rule_files:\n  - /etc/prometheus/rules/*.yml\n\n'
    t = (t[:m.end()] + ins + t[m.end():]) if m else (ins + t)

if 'job_name: loki' not in t:
    t += '\n  - job_name: loki\n    static_configs:\n      - targets: ["loki:3100"]\n'
if 'job_name: alloy' not in t:
    t += '\n  - job_name: alloy\n    static_configs:\n      - targets: ["alloy:12345"]\n'

p.write_text(t, encoding='utf-8')
print('UPDATED: prometheus.yml ensured rule_files + loki/alloy scrape jobs')
PY

if ! rg -n -- '/etc/prometheus/rules' infra/logging/docker-compose.observability.yml >/dev/null 2>&1; then
  python3 - <<'PY'
from pathlib import Path
import re

p = Path('/home/luce/apps/loki-logging/infra/logging/docker-compose.observability.yml')
t = p.read_text(encoding='utf-8')

m = re.search(r'\n\s*prometheus:\n(.*?)(\n\s*[a-zA-Z0-9_.-]+:\n|\Z)', t, re.S)
if not m:
    raise SystemExit('FAIL: could not locate prometheus service block')

block = m.group(1)
if '/etc/prometheus/rules' in block:
    print('NOCHANGE: rules mount already present')
    raise SystemExit(0)

mount = '      - ./infra/logging/prometheus/rules:/etc/prometheus/rules:ro\n'
t2 = re.sub(r'(prometheus\.yml:/etc/prometheus/prometheus\.yml:ro\n)', r'\1' + mount, t, count=1)
p.write_text(t2, encoding='utf-8')
print('UPDATED: added prometheus rules mount to compose')
PY
fi

prism_hash "$PROM_YML" infra/logging/docker-compose.observability.yml

prism_cmd "restart prometheus" -- docker compose -f "$OBS_COMPOSE" up -d prometheus
prism_cmd "restart grafana" -- docker compose -f "$OBS_COMPOSE" up -d grafana

sleep 3

PROM_PORT="$(grep -E '127\.0\.0\.1:[0-9]+:9090' infra/logging/docker-compose.observability.yml | head -n1 | sed -E 's/.*127\.0\.0\.1:([0-9]+):9090.*/\1/' || true)"
PROM_PORT="${PROM_PORT:-9004}"
prism_event ctx prom_port="$PROM_PORT"

prism_cmd "prom ready" -- curl --connect-timeout 5 --max-time 20 -sf "http://127.0.0.1:${PROM_PORT}/-/ready"
curl --connect-timeout 5 --max-time 20 -sf "http://127.0.0.1:${PROM_PORT}/api/v1/rules" > "${PRISM_EVID_DIR}/prom_rules.json" || true
if grep -q "loki_logging_v1" "${PRISM_EVID_DIR}/prom_rules.json" 2>/dev/null; then
  prism_event pass check="prom_rules_loaded" group="loki_logging_v1"
else
  prism_event warn check="prom_rules_loaded" note="rule_group_not_found_in_api"
fi

GRAFANA_PORT="$(grep -E '127\.0\.0\.1:[0-9]+:3000' infra/logging/docker-compose.observability.yml | head -n1 | sed -E 's/.*127\.0\.0\.1:([0-9]+):3000.*/\1/' || true)"
GRAFANA_PORT="${GRAFANA_PORT:-9001}"
prism_event ctx grafana_port="$GRAFANA_PORT"
prism_cmd "grafana health" -- curl --connect-timeout 5 --max-time 20 -sf "http://127.0.0.1:${GRAFANA_PORT}/api/health"

ls -la "$GRAFANA_DASH_DIR" > "${PRISM_EVID_DIR}/dashboards_ls.txt"
prism_event dashboards_ls file="dashboards_ls.txt"

git add \
  "$GRAFANA_DASH_DIR/host_overview.json" \
  "$GRAFANA_DASH_DIR/containers_overview.json" \
  "$PROM_RULES_FILE" \
  "$PROM_YML" \
  infra/logging/docker-compose.observability.yml

git commit -m "Phase G: add baseline dashboards + Prometheus alert rules + scrape loki/alloy" || true

prism_event phase_ok phase="G"
```

## Acceptance
- Dashboard JSONs exist in `infra/logging/grafana/dashboards/`.
- Prometheus rules file exists and rule group `loki_logging_v1` is visible in API (preferred).
- Prometheus and Grafana health checks succeed.
- Evidence is captured in `temp/.artifacts/prism/evidence/<RUN_UTC>/`.
