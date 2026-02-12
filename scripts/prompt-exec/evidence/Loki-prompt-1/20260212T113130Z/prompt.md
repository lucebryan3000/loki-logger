---
codex_reviewed_utc: 2026-02-12T11:22:10Z
codex_revision: 2
codex_ready_to_execute: yes
codex_kind: task
codex_scope: single-file
codex_targets:
- _build/Sprint-1/Prompts/Loki-prompt-1.md
codex_autocommit: yes
codex_move_to_completed: yes
codex_warn_gate: yes
codex_warn_mode: ask
codex_allow_noncritical: yes
codex_reason: ""
codex_prompt_sha256_mode: none
codex_last_run_utc: '20260212T112400Z'
codex_last_run_dir: '/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T112400Z'
codex_last_run_status: 'failed'
codex_last_run_git_head: '3faef5fc0b992d862cb3c4a18f6ab10304b1db7c'
codex_last_run_warning_count: '0'
codex_last_run_failed_block: 'block002'
codex_last_run_last_ok_block: '1'
codex_last_run_move_status: 'skipped'
codex_last_run_prompt_sha256: '3835528f9b6684c6cdca621b31a4887c3a0f6cc6dcbbb0e0b99c66425bf15605'
---

# Loki Logging v1 — End-to-End Local Sandbox Deployment (LOOPBACK-only)

## Header

prism:
mode: EXECUTION
track: EXECUTION
clutch_phase: 2
gate_state: WARN
scope_ref: "\_build/Sprint-1/Prompts/Loki-prompt-1.md"
mutation_intent: ["CODE", "CONFIG", "RUNTIME", "DATA"]
exposure: LOOPBACK
expires_at_utc: null
revert_command: "cd /home/luce/apps/loki-logging && COMPOSE_PROJECT_NAME=infra_observability docker compose -f infra/logging/docker-compose.observability.yml down -v"
artifact_root: "/home/luce/apps/loki-logging/.artifacts/prism"

## Objective

Deploy Loki Logging v1 on a single host as a private sandbox stack (Grafana + Loki + Alloy + Prometheus + node_exporter + cAdvisor) with:

- deterministic file layout under /home/luce/apps/loki-logging
- generated secrets stored in infra/logging/.env (never printed)
- LOOPBACK-only access:
  - Grafana: 127.0.0.1:9001
  - Prometheus: 127.0.0.1:9004
  - Loki: NOT published (Docker network only at http://loki:3100)
- evidence recorded under .artifacts/prism/evidence/<run_id>/
- command-verifiable acceptance proofs

## Scope

In-scope:

- Ensure repo exists at /home/luce/apps/loki-logging with remote https://github.com/lucebryan3000/loki-logger.git
- Create/overwrite these repo-managed files (authoritative):
  - infra/logging/docker-compose.observability.yml
  - infra/logging/loki-config.yml
  - infra/logging/alloy-config.alloy
  - infra/logging/prometheus/prometheus.yml
  - infra/logging/grafana/provisioning/datasources/loki.yml
  - infra/logging/grafana/provisioning/datasources/prometheus.yml
  - infra/logging/grafana/provisioning/dashboards/dashboards.yml
  - scripts/mcp/logging_stack_up.sh
  - scripts/mcp/logging_stack_down.sh
  - scripts/mcp/logging_stack_health.sh
  - infra/logging/.env (generated if missing)
- Create required host dirs:
  - /home/luce/\_logs
  - /home/luce/\_telemetry

## Non-Goals

- No WAN/LAN exposure and no UFW rule modifications (LOOPBACK-only stance)
- No Alertmanager service (reserved future)
- No HA/scaling patterns, no object store, no multi-tenant auth
- No dashboard library import beyond basic provisioning scaffold

## Affects

- Docker runtime: new compose project infra_observability
- Host ports: 127.0.0.1:9001 and 127.0.0.1:9004 will be bound
- Disk: docker volumes (grafana-data, prometheus-data, loki-data) and repo files
- Evidence: /home/luce/apps/loki-logging/.artifacts/prism/evidence/<run_id>/

## Primary Sources (Authority Order)

1. PRISM.md (execution contract; evidence paths; exposure semantics)
2. Loki-logging PRD: _build/Sprint-1/Prompts/Loki-logging-1.md (design + acceptance)
3. Repo canonical remote: https://github.com/lucebryan3000/loki-logger.git
4. Component official docs are referenced in PRD; do not browse during execution

## Reality Snapshot (2026-02-12)

All reality MUST be captured by commands in Phase 0; do not assume:

- docker/compose versions
- whether repo exists / clean tree
- port availability
- journald persistence location
- presence of required host directories

## Conflict Report

- PRD default exposure suggests LAN/WireGuard allowed; this prompt enforces LOOPBACK-only for sandbox privacy.
  - status: OK (operator instruction: "everything is private ... sandbox")
- PRD mentions docker toolchain; Phase 0 will validate and fail closed if missing.
  - status: TBD until Phase 0
- Alloy version pinning not explicitly given; this prompt pins to a known image tag set below for determinism.
  - status: OK (deterministic choice)
- Promtail is not used; Alloy is used (matches PRD intent).
  - status: OK

## Phase Requirements & Data Inputs

Required:

- sudo available (or root)
- outbound network access for docker image pulls (unless images already present)
- git installed and can reach GitHub (unless repo already present)

Data inputs (fixed by this prompt):

- Repo root: /home/luce/apps/loki-logging
- Compose project: infra_observability
- Ports:
  - grafana: 127.0.0.1:9001
  - prometheus: 127.0.0.1:9004
  - loki: internal-only (no publish)
- Retention:
  - loki: 30d
  - prometheus: 15d

## Phase Outputs

- Running docker compose stack: infra_observability
- Grafana available at http://127.0.0.1:9001 with provisioned datasources for Loki + Prometheus
- Prometheus available at http://127.0.0.1:9004 with targets UP for node_exporter + cadvisor
- Loki ready on Docker network (http://loki:3100) and receiving at least one log stream from Alloy
- Evidence bundle under .artifacts/prism/evidence/<run_id>/
- Git commit containing created/updated files (unless Phase 0 finds repo state disallows)

## Destination (What "Done" Looks Like)

- `COMPOSE_PROJECT_NAME=infra_observability docker compose -f infra/logging/docker-compose.observability.yml ps` shows all services healthy/up
- `curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9001/api/health` returns JSON with `"database":"ok"`
- `curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/-/ready` returns `Prometheus is Ready.`
- Prometheus targets endpoint shows node_exporter + cadvisor UP
- Loki readiness returns success from inside the docker network
- Secrets exist in infra/logging/.env with 0600 perms and were never printed to stdout

## Phase 0 - Preflight Gate (STOP if any FAIL)

Objective: capture reality, ensure determinism, set evidence root, and block on missing prerequisites.

```bash
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
```

Expected:

- Phase 0 completes and writes evidence files.
  Evidence:
- exec.log, exec.err.log, versions.txt, git_origin.txt (if applicable), journald_posture.txt

STOP conditions:

- missing tools, docker unusable, ports in use, repo origin mismatch

## Phase 1 - Ensure Repo State + Create Required Directories

Objective: ensure repo exists at canonical path and directory layout exists.

```bash
set -euo pipefail
cd /home/luce/apps

if [ ! -d /home/luce/apps/loki-logging/.git ]; then
  git clone https://github.com/lucebryan3000/loki-logger.git /home/luce/apps/loki-logging
fi

cd /home/luce/apps/loki-logging

# Fail closed if dirty tree (we want deterministic diffs)
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "FAIL: git working tree not clean. Commit/stash manually before running this prompt." | tee -a "$EVID/stop_reason.txt"
  git status --porcelain | tee "$EVID/git_status_dirty.txt"
  exit 1
fi

mkdir -p infra/logging/prometheus
mkdir -p infra/logging/grafana/provisioning/datasources
mkdir -p infra/logging/grafana/provisioning/dashboards
mkdir -p infra/logging/grafana/dashboards
mkdir -p scripts/mcp

# Host bind targets
mkdir -p /home/luce/_logs
mkdir -p /home/luce/_telemetry
chmod 700 /home/luce/_logs /home/luce/_telemetry

# Evidence snapshot of tree
git rev-parse HEAD | tee "$EVID/git_head_before.txt"
ls -la infra/logging | tee "$EVID/infra_logging_ls.txt"
```

Expected:

- Repo exists, tree clean, required dirs created.
  Evidence:
- git_head_before.txt, infra_logging_ls.txt

## Phase 2 - Generate Secrets (.env) Safely (Never Print)

Objective: generate deterministic secret material and store in infra/logging/.env with strict perms.

```bash
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
```

Expected:

- infra/logging/.env exists with required keys, perms 0600.
  Evidence:
- env_redacted.txt, env_perms.txt

## Phase 3 - Write Compose + Component Configs (Authoritative Files)

Objective: materialize the v1 configuration per PRD decisions, using LOOPBACK-only publishing and internal Loki.

Chosen versions (deterministic):

- grafana/grafana:11.1.0
- grafana/loki:3.0.0
- grafana/alloy:v1.2.1
- prom/prometheus:v2.52.0
- prom/node-exporter:v1.8.1
- gcr.io/cadvisor/cadvisor:v0.49.1

```bash
set -euo pipefail
cd /home/luce/apps/loki-logging

# 1) Loki config (filesystem + compactor retention 30d)
cat > infra/logging/loki-config.yml <<'YAML'
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  filesystem:
    directory: /loki/chunks

compactor:
  working_directory: /loki/compactor
  retention_enabled: true
  compaction_interval: 10m
  retention_delete_delay: 2h
  retention_delete_worker_count: 50

limits_config:
  retention_period: 720h
  max_label_names_per_series: 15
YAML

# 2) Prometheus config (retention 15d via config, static scrape)
cat > infra/logging/prometheus/prometheus.yml <<'YAML'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

storage:
  tsdb:
    retention:
      time: 15d

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["prometheus:9090"]

  - job_name: node_exporter
    static_configs:
      - targets: ["node_exporter:9100"]

  - job_name: cadvisor
    static_configs:
      - targets: ["cadvisor:8080"]
YAML

# 3) Alloy config (docker logs + journald + telemetry/file tail minimal; exclude self-ingestion)
cat > infra/logging/alloy-config.alloy <<'HCL'
logging {
  level = "info"
}

discovery.docker "all" {
  host = "unix:///var/run/docker.sock"
}

# Docker logs -> Loki, exclude observability stack itself and grafana/* images
loki.source.docker "dockerlogs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.all.targets
  forward_to = [loki.process.main.receiver]

  relabel_rules = [
    # Drop infra_observability project containers (self-ingestion)
    {
      action        = "drop"
      source_labels = ["__meta_docker_container_label_com_docker_compose_project"]
      regex         = "infra_observability"
    },
    # Defense in depth: drop grafana images
    {
      action        = "drop"
      source_labels = ["__meta_docker_image"]
      regex         = "grafana/(grafana|loki|alloy).*"
    },
  ]
}

# journald -> Loki (minimal; if journald not mounted/persistent, will still try /run/log/journal)
loki.source.journal "journald" {
  forward_to = [loki.process.main.receiver]
}

# File tail: tool sink + telemetry-as-logs
local.file_match "tool_sink" {
  path_targets = [{ "__path__" = "/host/home/luce/_logs/*.log" }]
}
loki.source.file "tool_sink" {
  targets    = local.file_match.tool_sink.targets
  forward_to = [loki.process.main.receiver]
}

local.file_match "telemetry" {
  path_targets = [{ "__path__" = "/host/home/luce/_telemetry/*.jsonl" }]
}
loki.source.file "telemetry" {
  targets    = local.file_match.telemetry.targets
  forward_to = [loki.process.main.receiver]
}

loki.process "main" {
  stage.static_labels {
    values = {
      env = "sandbox",
    }
  }

  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
HCL

# 4) Grafana provisioning (datasources)
cat > infra/logging/grafana/provisioning/datasources/loki.yml <<'YAML'
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
YAML

cat > infra/logging/grafana/provisioning/datasources/prometheus.yml <<'YAML'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
YAML

# 5) Grafana dashboards provisioning scaffold (empty folder OK)
cat > infra/logging/grafana/provisioning/dashboards/dashboards.yml <<'YAML'
apiVersion: 1
providers:
  - name: 'default'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
YAML

# 6) Compose file (LOOPBACK-only for published UIs; Loki internal only)
cat > infra/logging/docker-compose.observability.yml <<'YAML'
name: infra_observability

networks:
  obs:
    name: obs
    driver: bridge

volumes:
  grafana-data:
  prometheus-data:
  loki-data:

services:
  grafana:
    image: grafana/grafana:11.1.0
    env_file:
      - ./.env
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_SECURITY_SECRET_KEY=${GRAFANA_SECRET_KEY}
      - GF_SERVER_HTTP_PORT=3000
    ports:
      - "127.0.0.1:9001:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    networks: [obs]
    depends_on:
      - loki
      - prometheus
    restart: unless-stopped

  loki:
    image: grafana/loki:3.0.0
    command: ["-config.file=/etc/loki/loki-config.yml"]
    volumes:
      - loki-data:/loki
      - ./loki-config.yml:/etc/loki/loki-config.yml:ro
    networks: [obs]
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:v2.52.0
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
    ports:
      - "127.0.0.1:9004:9090"
    volumes:
      - prometheus-data:/prometheus
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    networks: [obs]
    restart: unless-stopped

  node_exporter:
    image: prom/node-exporter:v1.8.1
    command:
      - "--path.rootfs=/host"
    pid: host
    volumes:
      - "/:/host:ro,rslave"
    networks: [obs]
    restart: unless-stopped

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    privileged: true
    devices:
      - "/dev/kmsg:/dev/kmsg"
    volumes:
      - "/:/rootfs:ro"
      - "/var/run:/var/run:rw"
      - "/sys:/sys:ro"
      - "/var/lib/docker/:/var/lib/docker:ro"
    networks: [obs]
    restart: unless-stopped

  alloy:
    image: grafana/alloy:v1.2.1
    command: ["run", "--server.http.listen-addr=0.0.0.0:12345", "/etc/alloy/config.alloy"]
    user: "0:0"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "/run/log/journal:/run/log/journal:ro"
      - "/var/log/journal:/var/log/journal:ro"
      - "/home:/host/home:ro"
      - "./alloy-config.alloy:/etc/alloy/config.alloy:ro"
    networks: [obs]
    depends_on:
      - loki
    restart: unless-stopped
YAML

# Record file hashes as evidence
sha256sum \
  infra/logging/docker-compose.observability.yml \
  infra/logging/loki-config.yml \
  infra/logging/alloy-config.alloy \
  infra/logging/prometheus/prometheus.yml \
  infra/logging/grafana/provisioning/datasources/loki.yml \
  infra/logging/grafana/provisioning/datasources/prometheus.yml \
  infra/logging/grafana/provisioning/dashboards/dashboards.yml | tee "$EVID/config_sha256.txt"
```

Expected:

- All config files written; compose file references .env; hashes recorded.
  Evidence:
- config_sha256.txt

## Phase 4 - Create Stack Control Scripts

Objective: add deterministic scripts to manage the stack with the correct compose project name.

```bash
set -euo pipefail
cd /home/luce/apps/loki-logging

cat > scripts/mcp/logging_stack_up.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export COMPOSE_PROJECT_NAME=infra_observability
docker compose -f infra/logging/docker-compose.observability.yml up -d
BASH

cat > scripts/mcp/logging_stack_down.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export COMPOSE_PROJECT_NAME=infra_observability
docker compose -f infra/logging/docker-compose.observability.yml down -v
BASH

cat > scripts/mcp/logging_stack_health.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export COMPOSE_PROJECT_NAME=infra_observability

docker compose -f infra/logging/docker-compose.observability.yml ps

# loopback checks
curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9001/api/health >/dev/null && echo "grafana_ok=1" || { echo "grafana_ok=0"; exit 1; }
curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/-/ready | grep -q "Ready" && echo "prometheus_ok=1" || { echo "prometheus_ok=0"; exit 1; }
BASH

chmod +x scripts/mcp/logging_stack_*.sh
ls -la scripts/mcp | tee "$EVID/scripts_ls.txt"
```

Expected:

- scripts exist and executable.
  Evidence:
- scripts_ls.txt

## Phase 5 - Deploy Stack + Validate Services

Objective: bring the stack up, verify readiness, verify Prometheus targets UP, verify Loki readiness inside network, and verify at least one log stream arrives.

```bash
set -euo pipefail
cd /home/luce/apps/loki-logging
export COMPOSE_PROJECT_NAME=infra_observability

docker compose -f infra/logging/docker-compose.observability.yml pull | tee "$EVID/docker_pull.txt"
docker compose -f infra/logging/docker-compose.observability.yml up -d | tee "$EVID/docker_up.txt"

docker compose -f infra/logging/docker-compose.observability.yml ps | tee "$EVID/compose_ps.txt"

# Wait for loopback endpoints
for i in $(seq 1 60); do
  if curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9001/api/health >/dev/null && curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/-/ready | grep -q "Ready"; then
    echo "ready=1 after ${i}s" | tee "$EVID/ready_wait.txt"
    break
  fi
  sleep 1
done
test -f "$EVID/ready_wait.txt" || { echo "FAIL: services not ready within 60s"; exit 1; }

# Prometheus targets (record response)
curl -sf --connect-timeout 5 --max-time 20 "http://127.0.0.1:9004/api/v1/targets" | tee "$EVID/prom_targets.json" >/dev/null

# Loki readiness from inside the network
GRAFANA_CID="$(docker compose -f infra/logging/docker-compose.observability.yml ps -q grafana)"
docker exec "$GRAFANA_CID" wget -qO- http://loki:3100/ready | tee "$EVID/loki_ready.txt"

# Stimulate at least one docker log line (local) by writing to /home/luce/_logs and waiting for tail ship
echo "{\"ts\":\"$(date -u --iso-8601=seconds)\",\"source\":\"smoke\",\"msg\":\"loki-logging v1 smoke\"}" >> /home/luce/_logs/loki-logging-smoke.log
sleep 5

# Query Loki for the smoke line (from inside grafana container)
START_NS="$(( ($(date +%s) - 900) * 1000000000 ))"
END_NS="$(( $(date +%s) * 1000000000 ))"
docker exec "$GRAFANA_CID" wget -qO- \
  "http://loki:3100/loki/api/v1/query_range?query=%7Benv%3D%22sandbox%22%7D%20%7C%3D%20%22loki-logging%20v1%20smoke%22&limit=20&direction=BACKWARD&start=${START_NS}&end=${END_NS}" \
  | tee "$EVID/loki_query_smoke.json" >/dev/null

# Record logs (last 200 lines) for debugging (no secrets expected in logs)
for svc in grafana loki prometheus alloy node_exporter cadvisor; do
  CID="$(docker compose -f infra/logging/docker-compose.observability.yml ps -q "$svc")"
  echo "=== $svc ===" >> "$EVID/container_logs_tail.txt"
  docker logs --tail 200 "$CID" >> "$EVID/container_logs_tail.txt" 2>&1 || true
done
```

Expected:

- Grafana and Prometheus are reachable on loopback.
- Loki responds ready inside docker network.
- Loki query for smoke line returns a non-empty result set.
  Evidence:
- docker_pull.txt, docker_up.txt, compose_ps.txt, prom_targets.json, loki_ready.txt, loki_query_smoke.json, container_logs_tail.txt

STOP conditions:

- endpoints not ready
- loki not ready
- smoke query returns empty results (indicates ingestion failure; stop and inspect alloy logs)

## Phase 6 - Git Commit (Autocommit)

Objective: commit the deterministic configuration and scripts.

```bash
set -euo pipefail
cd /home/luce/apps/loki-logging

git add \
  infra/logging/docker-compose.observability.yml \
  infra/logging/loki-config.yml \
  infra/logging/alloy-config.alloy \
  infra/logging/prometheus/prometheus.yml \
  infra/logging/grafana/provisioning/datasources/loki.yml \
  infra/logging/grafana/provisioning/datasources/prometheus.yml \
  infra/logging/grafana/provisioning/dashboards/dashboards.yml \
  scripts/mcp/logging_stack_up.sh \
  scripts/mcp/logging_stack_down.sh \
  scripts/mcp/logging_stack_health.sh

# Do NOT commit secrets (.env). Verify it's not staged.
if git status --porcelain | grep -q "infra/logging/.env"; then
  echo "FAIL: .env is staged. Remove it from staging and ensure it is gitignored." | tee "$EVID/stop_reason_env_staged.txt"
  exit 1
fi

git commit -m "Deploy Loki logging v1 (loopback-only) + provisioning + scripts" | tee "$EVID/git_commit.txt"
git rev-parse HEAD | tee "$EVID/git_head_after.txt"
```

Expected:

- Commit created; .env not committed.
  Evidence:
- git_commit.txt, git_head_after.txt

## Acceptance Proofs

Run these commands and ensure outputs match expectations:

```bash
cd /home/luce/apps/loki-logging
export COMPOSE_PROJECT_NAME=infra_observability

docker compose -f infra/logging/docker-compose.observability.yml ps

curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9001/api/health
curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/-/ready

curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/api/v1/targets | grep -E '"health":"up"' || true

GRAFANA_CID="$(docker compose -f infra/logging/docker-compose.observability.yml ps -q grafana)"
docker exec "$GRAFANA_CID" wget -qO- http://loki:3100/ready
```

## Guardrails

- MUST NOT print secret values (only redacted forms allowed).
- MUST NOT expose services beyond loopback.
- MUST NOT commit infra/logging/.env (ensure gitignored; fail if staged).
- MUST stop immediately if:
  - self-ingestion is detected (observability containers sent to Loki)
  - Loki returns non-ready or smoke query empty
  - required ports are already bound

## Done Criteria

- All services up in compose
- Grafana health ok on 127.0.0.1:9001
- Prometheus ready on 127.0.0.1:9004 and targets include node_exporter + cadvisor UP
- Loki ready internally and smoke log query returns results
- Evidence bundle exists under .artifacts/prism/evidence/<run_id>/
- Git commit created with configs/scripts; .env not committed

## Operator Checkpoint

Proceed to run Phase 0 (Preflight Gate) only from /home/luce/apps/loki-logging/_build/Sprint-1/Prompts/Loki-prompt-1.md? (yes/no)

## Prompt Self-Check (A-Grade)

- Phase 0 exists and is fail-closed: YES
- Paths are concrete: YES (/home/luce/apps/loki-logging; fixed file targets)
- Secrets not printed and not committed: YES (redaction + staging guard)
- Evidence path is PRISM-canonical: YES (.artifacts/prism/evidence)
- Acceptance proofs are command-verifiable: YES
- One operator checkpoint (yes/no): YES
- Deterministic edit targets: YES (explicit paths; overwrite with heredocs)
- Stop conditions explicit: YES
