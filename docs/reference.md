# Reference

Stable reference data for the Loki logging stack.

## Port Assignments

| Service | Internal Port | External Binding | Protocol | Purpose |
|---------|---------------|------------------|----------|---------|
| Grafana | 3000 | 0.0.0.0:9001 | HTTP | Web UI, API |
| Prometheus | 9090 | 0.0.0.0:9004 | HTTP | Web UI, API |
| Loki | 3100 | None (internal) | HTTP | Push/query API |
| Alloy | 12345 | None (internal) | HTTP | Admin UI |
| Alloy (syslog) | 1514 | 127.0.0.1:1514 | TCP | rsyslog → Alloy syslog listener |
| Node Exporter | 9100 | None (internal) | HTTP | Metrics endpoint |
| cAdvisor | 8080 | None (internal) | HTTP | Metrics endpoint |

**LAN-accessible services:** Grafana, Prometheus (0.0.0.0 binding, protected by UFW)

**Internal-only services:** Loki, Alloy, Node Exporter, cAdvisor (no exposed ports)

## Environment Variables (.env)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GRAFANA_ADMIN_USER` | Yes | - | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | Yes | - | Grafana admin password (min 8 chars) |
| `GRAFANA_SECRET_KEY` | Yes | - | Session encryption key (32+ random chars) |
| `GRAFANA_HOST` | No | 0.0.0.0 | Grafana bind address |
| `GRAFANA_PORT` | No | 9001 | Grafana external port |
| `PROM_HOST` | No | 0.0.0.0 | Prometheus bind address |
| `PROM_PORT` | No | 9004 | Prometheus external port |
| `HOST_HOME` | No | /home | Host home directory for Alloy mounts |

**Security:** `.env` must have mode 600 and never be committed to git.

## File Paths

### Repository Structure

```
/home/luce/apps/loki-logging/
├── infra/logging/
│   ├── docker-compose.observability.yml   # Stack definition
│   ├── .env                               # Secrets (mode 600, gitignored)
│   ├── alloy-config.alloy                 # Alloy ingestion config
│   ├── loki-config.yml                    # Loki storage/retention config
│   ├── grafana/
│   │   ├── provisioning/                  # Auto-provisioned data sources
│   │   └── dashboards/                    # Pre-built dashboards
│   └── prometheus/
│       ├── prometheus.yml                 # Scrape targets
│       └── rules/                         # Alert rules
├── scripts/
│   ├── prod/mcp/
│   │   ├── logging_stack_up.sh            # Deploy stack
│   │   ├── logging_stack_down.sh          # Stop stack
│   │   ├── logging_stack_health.sh        # Health checks
│   │   └── logging_stack_audit.sh         # Deep contract audit
│   └── prism/
│       └── evidence.sh                    # Generate evidence archive
├── docs/                                  # Documentation (this file)
└── temp/
    └── evidence/                          # Evidence archives (gitignored)
```

### Config File Locations

| Service | Config File | Mount Point in Container |
|---------|-------------|--------------------------|
| Loki | `infra/logging/loki-config.yml` | `/etc/loki/loki-config.yml` |
| Prometheus | `infra/logging/prometheus/prometheus.yml` | `/etc/prometheus/prometheus.yml` |
| Alloy | `infra/logging/alloy-config.alloy` | `/etc/alloy/config.alloy` |
| rsyslog | `/etc/rsyslog.d/50-loki-alloy.conf` | Host-only (not containerized) |
| Grafana | `infra/logging/grafana/provisioning/` | `/etc/grafana/provisioning/` |

**All configs mounted read-only (`:ro`).** Changes require container restart.

### Log Source Paths

**Total: 7 active log sources**

| Source | Type | Host Path | Container/Method | Labels |
|--------|------|-----------|------------------|--------|
| Systemd journal | rsyslog → syslog | `/var/log/journal` | rsyslog → TCP:1514 → Alloy | `log_source=journald` |
| Docker containers | Docker socket | `/var/run/docker.sock` | `/var/run/docker.sock` | `log_source=docker`, `stack`, `service` |
| VS Code Server | File tail | `/home/luce/.vscode-server/**/*.log` | `/host/home/luce/.vscode-server/**/*.log` | `log_source=vscode_server`, `filename` |
| CodeSwarm MCP | File tail | `/home/luce/apps/vLLM/_data/mcp-logs/*.log` | `/host/home/luce/apps/vLLM/_data/mcp-logs/*.log` | `log_source=codeswarm_mcp`, `filename` |
| NVIDIA telemetry | File tail | `/home/luce/apps/vLLM/logs/telemetry/nvidia/*.jsonl` | `/host/home/luce/apps/vLLM/logs/telemetry/nvidia/*.jsonl` | `log_source=nvidia_telem`, `filename` |
| Telemetry | File tail | `/home/luce/_telemetry/*.jsonl` | `/host/home/luce/_telemetry/*.jsonl` | `filename` |
| Tool logs | File tail | `/home/luce/_logs/*.log` | `/host/home/luce/_logs/*.log` | `filename` |

**Architecture notes:**
- **Systemd journal:** Uses rsyslog as relay (systemd journal → rsyslog imjournal → TCP:1514 → loki.source.syslog)
- **Docker:** Filtered to vllm and hex compose projects only
- **File sources:** Tailed via loki.source.file with position tracking
- **rsyslog config:** `/etc/rsyslog.d/50-loki-alloy.conf` (RFC5424 format, TCP forwarding)

## Docker Resources

### Compose Project

- **Project name:** `logging`
- **Network:** `obs` (bridge)
- **Volumes:** `grafana-data`, `loki-data`, `prometheus-data`, `alloy-positions`

### Container Names

| Service | Container Name |
|---------|----------------|
| Grafana | `logging-grafana-1` |
| Loki | `logging-loki-1` |
| Prometheus | `logging-prometheus-1` |
| Alloy | `logging-alloy-1` |
| Node Exporter | `logging-host-monitor-1` |
| cAdvisor | `logging-docker-metrics-1` |

### Volume Mount Points

| Volume | Service | Container Path | Purpose |
|--------|---------|----------------|---------|
| `grafana-data` | grafana | `/var/lib/grafana` | Dashboards, users, settings |
| `loki-data` | loki | `/loki` | Chunks, index, compactor state |
| `prometheus-data` | prometheus | `/prometheus` | Time-series database (TSDB) |
| `alloy-positions` | alloy | `/tmp` | File tail positions, syslog cursor tracking |

### Resource Limits (Default: None)

No resource limits are set by default. To add limits:

```yaml
services:
  loki:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
```

**Recommended limits for production:**
- Grafana: 1G memory, 0.5 CPU
- Loki: 2G memory, 1.0 CPU
- Prometheus: 2G memory, 1.0 CPU
- Alloy: 512M memory, 0.5 CPU

## Label Schema

### Standard Labels (All Logs)

| Label | Source | Example Values | Required |
|-------|--------|----------------|----------|
| `env` | Alloy static label | `sandbox` | Yes |

### Docker-Specific Labels

| Label | Source | Example | Required for Docker Logs |
|-------|--------|---------|--------------------------|
| `stack` | Docker relabel | `vllm`, `hex` | Yes |
| `service` | Docker relabel | `codeswarm-mcp` | Yes |
| `source_type` | Docker relabel | `docker` | Yes |
| `container_name` | Docker metadata | `logging-grafana-1` | Preferred |
| `image` | Docker metadata | `grafana/grafana:11.1.0` | No |
| `compose_project` | Docker metadata | `vllm`, `hex` | No |

### File-Based Log Labels

| Label | Source | Example | Required for File Logs |
|-------|--------|---------|------------------------|
| `filename` | Alloy file match | `/host/home/luce/_logs/test.log` | Yes |
| `log_source` | Alloy process pipeline | `codeswarm_mcp` (for MCP logs only) | Conditional |

**Critical:** Loki queries **require non-empty selectors**. Always include at least one label (e.g., `{env=~".+"}`).

## API Endpoints

### Grafana

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/health` | GET | Health check |
| `/api/datasources` | GET | List data sources |
| `/api/dashboards/home` | GET | Home dashboard |
| `/login` | GET/POST | Login page/auth |

**Base URL:** http://127.0.0.1:9001

**Authentication:** Cookie-based (username/password login required)

### Prometheus

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/-/ready` | GET | Readiness check |
| `/-/healthy` | GET | Health check |
| `/api/v1/query` | GET/POST | Instant query |
| `/api/v1/query_range` | GET/POST | Range query |
| `/api/v1/targets` | GET | Scrape targets |

**Base URL:** http://127.0.0.1:9004

**Authentication:** None (UFW-protected LAN access)

### Loki (Internal Only)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/ready` | GET | Readiness check |
| `/loki/api/v1/push` | POST | Log ingestion (from Alloy) |
| `/loki/api/v1/query` | GET | Instant query |
| `/loki/api/v1/query_range` | GET | Range query |
| `/loki/api/v1/labels` | GET | List labels |

**Base URL (internal):** http://loki:3100

**Access:** Only from `obs` Docker network (no external exposure)

## Configuration Parameters

### Loki (loki-config.yml)

| Parameter | Current Value | Description |
|-----------|---------------|-------------|
| `retention_period` | 720h (30 days) | Log retention duration |
| `max_label_names_per_series` | 15 | Max labels per log entry |
| `reject_old_samples` | false | Allow backfill of old logs |
| `compaction_interval` | 10m | How often to run compaction |
| `retention_delete_delay` | 2h | Delay before deleting expired data |

**Config file:** `infra/logging/loki-config.yml`

### Prometheus (CLI Flags)

| Flag | Current Value | Description |
|------|---------------|-------------|
| `--config.file` | `/etc/prometheus/prometheus.yml` | Config file path |
| `--storage.tsdb.path` | `/prometheus` | TSDB storage path |
| `--storage.tsdb.retention.time` | 15d | Metrics retention |

**Critical:** Retention **must** be set via CLI flag (not in `prometheus.yml`)

### Alloy (alloy-config.alloy)

**Key parameters:**

| Block | Parameter | Value |
|-------|-----------|-------|
| `logging` | `level` | `info` |
| `loki.write "default"` | `url` | `http://loki:3100/loki/api/v1/push` |
| `loki.process "main"` | `env` static label | `sandbox` |
| `loki.process "codeswarm"` | `log_source` static label | `codeswarm_mcp` |

**Syntax:** HCL-style (use `//` for comments, not `#`)

## Image Versions

| Service | Image | Version | Registry |
|---------|-------|---------|----------|
| Grafana | `grafana/grafana` | 11.1.0 | Docker Hub |
| Loki | `grafana/loki` | 3.0.0 | Docker Hub |
| Prometheus | `prom/prometheus` | v2.52.0 | Docker Hub |
| Alloy | `grafana/alloy` | v1.2.1 | Docker Hub |
| Node Exporter | `prom/node-exporter` | v1.8.1 | Docker Hub |
| cAdvisor | `gcr.io/cadvisor/cadvisor` | v0.49.1 | Google Container Registry |

**Update strategy:** Pin specific versions (not `latest`) to avoid unexpected breaking changes.

## Query Examples

### LogQL (Loki)

```logql
# All logs from sandbox (broad query)
{env="sandbox"}

# Docker container logs only
{env="sandbox", container_name=~".+"}

# Specific container
{env="sandbox", container_name="logging-grafana-1"}

# Search for errors
{env="sandbox"} |= "error"

# Case-insensitive search
{env="sandbox"} |~ "(?i)error"

# JSON parsing
{env="sandbox"} | json | level="error"

# Rate of errors
rate({env="sandbox"} |= "error" [5m])

# CodeSwarm MCP logs with label
{env="sandbox", log_source="codeswarm_mcp"}

# File-based logs
{env="sandbox", filename=~".*_logs.*"}
```

### PromQL (Prometheus)

```promql
# All targets up (recording rule)
sprint3:targets_up:count

# Failed targets (recording rule)
sprint3:targets_down:count

# CPU usage
sprint3:host_cpu_usage_percent

# Memory available
sprint3:host_memory_usage_percent

# Loki ingestion rate
sprint3:loki_ingestion_errors:rate5m

# Container memory usage
topk(10, sprint3:container_memory_workingset_bytes)

# Network I/O
rate(container_network_receive_bytes_total[5m])
```

## Health Check Commands

```bash
# Grafana health
curl -sf http://127.0.0.1:9001/api/health

# Prometheus ready
curl -sf http://127.0.0.1:9004/-/ready

# Prometheus healthy
curl -sf http://127.0.0.1:9004/-/healthy

# All containers running
docker compose -p logging -f infra/logging/docker-compose.observability.yml ps

# Stack health script
./scripts/prod/mcp/logging_stack_health.sh

# Stack audit script
./scripts/prod/mcp/logging_stack_audit.sh _build/Sprint-3/reference/native_audit.json
```

## Common Exit Codes

| Service | Exit Code | Meaning |
|---------|-----------|---------|
| Alloy | 1 | Config parse error |
| Loki | 1 | Config error or startup failure |
| Prometheus | 1 | Config error or TSDB corruption |
| Grafana | 1 | Database init failure |

**Diagnosis:**
```bash
docker logs logging-<service>-1 --tail 50
```

## Host SystemD Services

The CodeSwarm host runs several custom systemd services that interact with or support the logging stack.

### loki-telemetry-writer.service

**Purpose:** Continuously writes structured telemetry data to JSONL files for Loki ingestion

**Status:** Running (enabled)

**Key Details:**
- Script: `/home/luce/apps/loki-logging/scripts/telemetry/telemetry_writer.py`
- Output: `/home/luce/_telemetry/telemetry.jsonl`
- Interval: 10 seconds
- User: `luce`
- Restart: Always (2s delay)

**Integration:** Alloy ingests from `_telemetry/*.jsonl` with label `filename`

**Service File:** `/etc/systemd/system/loki-telemetry-writer.service`

### opencode-serve.service

**Purpose:** Runs OpenCode headless server for LAN-accessible AI coding interface

**Status:** Running (enabled)

**Key Details:**
- Binary: `/home/luce/.local/bin/opencode`
- Port: 8082 (configurable via `OPENCODE_SERVE_PORT`)
- Hostname: 0.0.0.0 (LAN-accessible)
- Working directory: `/home/luce/apps/opencode`
- Config: `/home/luce/.config/opencode/opencode.json`
- Environment: `/home/luce/.config/opencode-service/opencode.env`
- User: `luce`
- Restart: Always (2s delay)

**Logging:** Outputs to systemd journal with identifier `opencode-serve`

**Service File:** `/etc/systemd/system/opencode-serve.service`

### cloudflared.service

**Purpose:** Cloudflare tunnel daemon for secure remote access

**Status:** Running (enabled)

**Key Details:**
- Binary: `/usr/bin/cloudflared`
- Config: `/etc/cloudflared/config.yml`
- User: `root`
- Restart: On failure (5s delay)
- Auto-updates: Disabled (`--no-autoupdate`)

**Integration:** Provides secure tunnel to expose Grafana/Prometheus without direct internet exposure

**Service File:** `/etc/systemd/system/cloudflared.service`

### Decommissioned Services

The following services have been removed from the system (2026-02-14):

**Removed:**
- `codeswarm.service` — Auto-update service for AI coding tools (deprecated)
- `codeswarm-home.service` — Homer dashboard (inactive, directory missing)
- `system-stats-api.service` — Dashboard stats API (failing, script path invalid)
- `cpu-performance.service` — CPU governor setting (boot-time configuration)
- `kbgen-improver.service` — Knowledge base scheduler (never ran, script missing)

**Reason for removal:** All services were either deprecated, failing, or had missing dependencies. Active functionality has been migrated to other services or is no longer needed.

### Service Management Commands

```bash
# Check status
systemctl status <service-name>

# View logs
journalctl -u <service-name> -n 50

# Start/stop
sudo systemctl start <service-name>
sudo systemctl stop <service-name>

# Enable/disable on boot
sudo systemctl enable <service-name>
sudo systemctl disable <service-name>

# Restart
sudo systemctl restart <service-name>

# Reload systemd after editing service files
sudo systemctl daemon-reload
```

## Evidence Archive Structure

```
temp/evidence/loki-<timestamp>/
├── manifest.json              # Evidence metadata
├── stack-state.txt            # Container status
├── grafana-health.json        # Grafana API health
├── prometheus-ready.txt       # Prometheus readiness
├── loki-query-proof.json      # Loki query results (with labels)
└── config-hashes.txt          # SHA256 of config files
```

**Generated by:** `./scripts/prod/prism/evidence.sh`

**Purpose:** Cryptographically verifiable proof of stack operation

## Cross-References

- [overview.md](overview.md) — Stack concepts and scope
- [architecture.md](architecture.md) — Component details and data flow
- [deployment.md](deployment.md) — Deployment procedures
- [operations.md](operations.md) — Operational runbooks
- [validation.md](validation.md) — Validation proofs
- [troubleshooting.md](troubleshooting.md) — Common issues
- [security.md](security.md) — Security posture
- [maintenance.md](maintenance.md) — Retention and backups
- [query-contract.md](query-contract.md) — Canonical query IDs and expressions
- [snippets/](snippets/) — Config file excerpts
