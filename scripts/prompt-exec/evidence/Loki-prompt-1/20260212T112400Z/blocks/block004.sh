#!/usr/bin/env bash
set -euo pipefail
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T112400Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
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
      host = sys.env("HOSTNAME"),
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
      - ./infra/logging/.env
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_SECURITY_SECRET_KEY=${GRAFANA_SECRET_KEY}
      - GF_SERVER_HTTP_PORT=3000
    ports:
      - "127.0.0.1:9001:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./infra/logging/grafana/provisioning:/etc/grafana/provisioning:ro
      - ./infra/logging/grafana/dashboards:/var/lib/grafana/dashboards:ro
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
      - ./infra/logging/loki-config.yml:/etc/loki/loki-config.yml:ro
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
      - ./infra/logging/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
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
    image: grafana/alloy:1.2.1
    command: ["run", "--server.http.listen-addr=0.0.0.0:12345", "/etc/alloy/config.alloy"]
    user: "0:0"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "/run/log/journal:/run/log/journal:ro"
      - "/var/log/journal:/var/log/journal:ro"
      - "/home:/host/home:ro"
      - "./infra/logging/alloy-config.alloy:/etc/alloy/config.alloy:ro"
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
