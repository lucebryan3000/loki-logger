# Architecture

## Data Flow Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Log Sources (7 total)                   │
├─────────────────────────────────────────────────────────────┤
│ • Systemd journal → rsyslog (imjournal) → TCP:1514          │
│ • Docker containers (vllm, hex projects)                    │
│ • VS Code Server logs (.vscode-server/**/*.log)             │
│ • CodeSwarm MCP logs (_data/mcp-logs/*.log)                 │
│ • NVIDIA telemetry (vLLM/logs/telemetry/nvidia/*.jsonl)     │
│ • Telemetry (_telemetry/*.jsonl)                            │
│ • Tool logs (_logs/*.log)                                   │
└─────────────────────────────────────────────────────────────┘
                 ↓ (file tail)         ↓ (rsyslog TCP)
                         ┌────────┐
                         │ Alloy  │  (Log ingestion agent)
                         └────────┘  loki.source.{file,docker,syslog}
                              ↓      Adds labels: env, log_source
                         ┌────────┐
                         │  Loki  │  (Log aggregation & storage)
                         └────────┘  Retention: 720h (30 days)
                              ↓
                         ┌─────────┐
                         │ Grafana │  (Query interface)
                         └─────────┘  http://<host>:9001


┌─────────────────────────────────────────────────────────────┐
│                      Metrics Sources                        │
├─────────────────────────────────────────────────────────────┤
│ • Node Exporter (host metrics)                              │
│ • cAdvisor (container metrics)                              │
│ • Prometheus (self-monitoring)                              │
└─────────────────────────────────────────────────────────────┘
                              ↓
                      ┌──────────────┐
                      │ Prometheus   │  (Metrics scraping & storage)
                      └──────────────┘  Retention: 15d (CLI-enforced)
                              ↓
                         ┌─────────┐
                         │ Grafana │  (Dashboards & alerts)
                         └─────────┘
```

## Component Details

### Grafana (grafana/grafana:11.1.0)
**Purpose:** Unified query interface for logs and metrics

- **Exposed port:** 0.0.0.0:9001 → 3000 (container)
- **Authentication:** Admin credentials from `.env` (GRAFANA_ADMIN_USER, GRAFANA_ADMIN_PASSWORD)
- **Data sources:** Loki (http://loki:3100), Prometheus (http://prometheus:9090)
- **Provisioning:** Auto-configured via `/etc/grafana/provisioning/`
- **Persistence:** `grafana-data` volume at `/var/lib/grafana`

**Health check:**
```bash
curl -sf http://127.0.0.1:9001/api/health
```

### Loki (grafana/loki:3.0.0)
**Purpose:** Log aggregation, indexing, and querying

- **Exposed port:** None (internal only at http://loki:3100)
- **Storage:** `loki-data` volume at `/loki` (chunks, index, compactor state)
- **Config:** `infra/logging/loki-config.yml` (mounted read-only)
- **Schema:** v13 (TSDB + filesystem object store)
- **Retention:** 720h (30 days) enforced by compactor
- **Compaction:** Every 10m with 2h delete delay

**Key config values:**
- `retention_period: 720h`
- `max_label_names_per_series: 15`
- `reject_old_samples: false` (allows backfill)

**Query endpoint (internal):**
```bash
# From within obs network:
curl 'http://loki:3100/loki/api/v1/query_range?query={env=~".+"}&start=...'
```

### Prometheus (prom/prometheus:v2.52.0)
**Purpose:** Metrics collection, alerting, and time-series storage

- **Exposed port:** 0.0.0.0:9004 → 9090 (container)
- **Storage:** `prometheus-data` volume at `/prometheus`
- **Config:** `infra/logging/prometheus/prometheus.yml` (mounted read-only)
- **Retention:** 15d (**CLI flag only:** `--storage.tsdb.retention.time=15d`)
- **Scrape targets:** host-monitor, docker-metrics, prometheus (self)

**Health checks:**
```bash
curl -sf http://127.0.0.1:9004/-/ready
curl -sf http://127.0.0.1:9004/-/healthy
```

**Critical:** Retention **cannot** be set in `prometheus.yml`. It is enforced via CLI args in compose.

### Alloy (grafana/alloy:v1.2.1)
**Purpose:** Log ingestion agent (Grafana's replacement for Promtail)

- **Exposed ports:**
  - None (HTTP UI at 12345 internal only)
  - 127.0.0.1:1514 (rsyslog → Alloy syslog listener, TCP, localhost only)
- **Config:** `infra/logging/alloy-config.alloy` (mounted read-only)
- **Runs as:** root (user: "0:0") for Docker socket access
- **Mounts:**
  - `/var/run/docker.sock` (Docker logs)
  - `/host/home` (file-based logs under /home/luce)
  - `alloy-positions:/tmp` (persistent file positions & syslog cursor)

**Log pipelines (7 sources):**
1. **Journald (via rsyslog):** Host rsyslog → TCP:1514 → `loki.source.syslog` → `loki.process.journald` → Loki
2. **Docker containers:** `loki.source.docker` → `loki.process.docker` → Loki (filtered: vllm, hex projects)
3. **VS Code Server:** `loki.source.file` → `loki.process.vscode` → Loki
4. **CodeSwarm MCP:** `loki.source.file` → `loki.process.codeswarm` → Loki
5. **NVIDIA telemetry:** `loki.source.file` → `loki.process.nvidia_telem` → Loki
6. **Telemetry (.jsonl):** `loki.source.file` → `loki.process.main` → Loki
7. **Tool logs:** `loki.source.file` → `loki.process.main` → Loki

**Label injection (all processors):**
- All logs: `env=sandbox`
- Dedicated processors add: `log_source=journald|docker|vscode_server|codeswarm_mcp|nvidia_telem`

**Redaction:** All processors have 3 canonical stages (bearer tokens, cookies, API keys)

**Syntax gotcha:** Alloy uses `//` for comments, **not** `#` (HCL-style config)

### rsyslog (system service)
**Purpose:** Relay systemd journal to Alloy syslog listener

- **Config:** `/etc/rsyslog.d/50-loki-alloy.conf`
- **Module:** `imjournal` (systemd journal input)
- **Forward target:** `127.0.0.1:1514` (TCP, RFC5424 format)
- **Why:** `loki.source.journal` is buggy/unreliable; rsyslog is production-grade, battle-tested
- **Health check:** `sudo systemctl status rsyslog`

### Node Exporter (prom/node-exporter:v1.8.1)
**Purpose:** Host-level metrics (CPU, memory, disk, network)

- **Exposed port:** None (internal 9100)
- **Mount:** `/:host:ro` (read-only root filesystem)
- **PID:** `host` (see host processes)
- **Scraped by:** Prometheus at `http://host-monitor:9100/metrics`

### cAdvisor (gcr.io/cadvisor/cadvisor:v0.49.1)
**Purpose:** Container-level metrics (CPU, memory, network per container)

- **Exposed port:** None (internal 8080)
- **Privileged:** true (requires host-level access)
- **Mounts:** `/rootfs`, `/var/run`, `/sys`, `/var/lib/docker`
- **Scraped by:** Prometheus at `http://docker-metrics:8080/metrics`

## Network Architecture

### Docker Network: `obs`
**Type:** Bridge
**Name:** `obs` (explicit name for stable DNS)

**Services on `obs` network:**
- grafana
- loki
- prometheus
- alloy
- host-monitor
- docker-metrics

**DNS resolution:**
- `http://loki:3100` (Loki API)
- `http://prometheus:9090` (Prometheus API)
- `http://grafana:3000` (Grafana internal)
- `http://host-monitor:9100` (Node Exporter metrics)
- `http://docker-metrics:8080` (cAdvisor metrics)

### Port Exposure

| Service | Internal Port | External Binding | Access |
|---------|---------------|------------------|--------|
| Grafana | 3000 | 0.0.0.0:9001 | All interfaces (UFW-protected) |
| Prometheus | 9090 | 0.0.0.0:9004 | All interfaces (UFW-protected) |
| Loki | 3100 | None | Internal only |
| Alloy | 12345 | None | Internal only |
| Node Exporter | 9100 | None | Internal only |
| cAdvisor | 8080 | None | Internal only |

**Security posture:** Only Grafana and Prometheus are externally accessible, bound to **all interfaces** (0.0.0.0) and protected by UFW firewall rules.

## Persistence

### Docker Volumes

| Volume | Service | Mount Point | Purpose |
|--------|---------|-------------|---------|
| `grafana-data` | grafana | `/var/lib/grafana` | Dashboards, users, settings |
| `loki-data` | loki | `/loki` | Chunks, index, compactor state |
| `prometheus-data` | prometheus | `/prometheus` | Time-series database |

**Backup/restore:** See [maintenance.md](maintenance.md#backup-and-restore).

### Config Files (Read-Only Mounts)

| Service | Config File | Mount Point |
|---------|-------------|-------------|
| Loki | `infra/logging/loki-config.yml` | `/etc/loki/loki-config.yml` |
| Prometheus | `infra/logging/prometheus/prometheus.yml` | `/etc/prometheus/prometheus.yml` |
| Alloy | `infra/logging/alloy-config.alloy` | `/etc/alloy/config.alloy` |
| Grafana | `infra/logging/grafana/provisioning/` | `/etc/grafana/provisioning/` |

**Config change application:**
```bash
# Prometheus/Loki/Grafana changes
docker compose -p logging -f infra/logging/docker-compose.observability.yml restart <service>

# Alloy supports config reload without recreate
docker kill -s HUP logging-alloy-1
```

## Label Schema

### Standard Labels (All Logs)

| Label | Source | Example Values |
|-------|--------|----------------|
| `env` | Alloy static label | `sandbox` |

### Docker-Specific Labels

| Label | Source | Example |
|-------|--------|---------|
| `stack` | Docker relabel | `vllm`, `hex` |
| `service` | Docker relabel | `codeswarm-mcp` |
| `source_type` | Docker relabel | `docker` |
| `container_name` | Docker metadata | `logging-grafana-1` |
| `image` | Docker metadata | `grafana/grafana:11.1.0` |
| `compose_project` | Docker metadata | `vllm`, `hex` |

### File-Based Log Labels

| Label | Source | Example |
|-------|--------|---------|
| `filename` | Alloy file match | `/host/home/luce/_logs/example.log` |
| `log_source` | Alloy process pipeline | `codeswarm_mcp` |

### Query Examples

```logql
# All logs from sandbox environment
{env="sandbox"}

# Docker container logs only
{env="sandbox", container_name=~".+"}

# CodeSwarm MCP logs with specific label
{env="sandbox", log_source="codeswarm_mcp"}

# Telemetry logs containing "error"
{env="sandbox", filename=~".*_telemetry.*"} |= "error"

# Broad query (any environment)
{env=~".+"}
```

**Critical:** Never use `{}` as a query selector. Always include at least one label.

## Service Dependencies

```
grafana
 ├─ depends_on: loki
 └─ depends_on: prometheus

alloy
 └─ depends_on: loki

loki
 └─ (no dependencies)

prometheus
 └─ (no dependencies)

host-monitor
 └─ (no dependencies)

docker-metrics
 └─ (no dependencies)
```

**Startup order:**
1. loki, prometheus (parallel)
2. alloy, host-monitor, docker-metrics (parallel, after loki)
3. grafana (after loki + prometheus)

## Configuration Files

### Primary Configs
- [infra/logging/docker-compose.observability.yml](../infra/logging/docker-compose.observability.yml) — Stack definition
- [infra/logging/loki-config.yml](../infra/logging/loki-config.yml) — Loki schema, retention, compaction
- [infra/logging/alloy-config.alloy](../infra/logging/alloy-config.alloy) — Log ingestion pipelines
- [infra/logging/prometheus/prometheus.yml](../infra/logging/prometheus/prometheus.yml) — Scrape targets, alerting

### Secrets
- `.env` — Grafana credentials, port overrides (mode 600, gitignored)

See [snippets/](snippets/) for canonical config excerpts.

## Resource Requirements

**Typical footprint (6 containers):**
- CPU: ~2-5% idle, ~10-15% under active ingestion
- Memory: ~1.5-2GB total
- Disk: ~100MB/day for logs (varies by volume)
- Retention: 30 days logs + 15 days metrics ≈ 3-5GB total

**Host requirements:**
- Docker 20.10+
- Docker Compose v2.0+
- 4GB+ RAM
- 10GB+ free disk space

See [reference.md](reference.md#resource-limits) for tuning parameters.
