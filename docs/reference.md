# Reference

Stable reference data for the Loki logging stack.

## Port Assignments

| Service | Internal Port | External Binding | Protocol | Purpose |
|---------|---------------|------------------|----------|---------|
| Grafana | 3000 | 0.0.0.0:9001 | HTTP | Web UI, API |
| Prometheus | 9090 | 0.0.0.0:9004 | HTTP | Web UI, API |
| Loki | 3100 | 127.0.0.1:3200 | HTTP | Push/query API |
| Alert sink | 8080 | None (internal) | HTTP | Local Grafana webhook receiver |
| Alloy | 12345 | None (internal) | HTTP | Admin UI |
| Alloy (syslog) | 1514 | 127.0.0.1:1514 | TCP | rsyslog → Alloy syslog listener |
| Node Exporter | 9100 | None (internal) | HTTP | Metrics endpoint |
| cAdvisor | 8080 | None (internal) | HTTP | Metrics endpoint |

**LAN-accessible services:** Grafana, Prometheus (default `0.0.0.0` binding)

**Loopback/internal services:** Loki (`127.0.0.1` only), alert-sink, Alloy, Node Exporter, cAdvisor

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

**Total: 13 active log sources**

| Source | Type | Host Path | Container/Method | Labels |
|--------|------|-----------|------------------|--------|
| rsyslog syslog relay | TCP syslog | `/etc/rsyslog.d/50-loki-alloy.conf` → 1514 | rsyslog → TCP:1514 → `loki.source.syslog` | `log_source=rsyslog_syslog`, `source_type=syslog`, `syslog_channel`, `security_domain` |
| Docker containers | Docker socket | `/var/run/docker.sock` | `/var/run/docker.sock` | `log_source=docker`, `stack`, `service`, `source_type` |
| Journald | Journal API | (systemd journal) | `loki.source.journal` | `log_source=journald` |
| Tool logs | File tail | `/home/luce/_logs/*.log` | `/host/home/luce/_logs/*.log` | `log_source=tool_sink`, `filename` |
| Telemetry | File tail | `/home/luce/_telemetry/*.jsonl` | `/host/home/luce/_telemetry/*.jsonl` | `log_source=telemetry`, `filename` |
| GPU telemetry | File tail | `/home/luce/_telemetry/gpu/gpu-live.csv`, `gpu-proc.csv` | `/host/home/luce/_telemetry/gpu/` | `log_source=gpu_telemetry`, `source_type=gpu_csv` |
| NVIDIA telemetry | File tail | `/home/luce/apps/vLLM/logs/telemetry/nvidia/*.jsonl` | `/host/home/luce/apps/vLLM/logs/telemetry/nvidia/` | `log_source=nvidia_telem`, `source_type=file`, `telemetry_tier=raw30` |
| CodeSwarm MCP | File tail | `/home/luce/apps/vLLM/_data/mcp-logs/*.log` | `/host/home/luce/apps/vLLM/_data/mcp-logs/*.log` | `log_source=codeswarm_mcp`, `mcp_level`, `service_name` |
| VS Code Server | File tail | `/home/luce/.vscode-server/**/*.log` | `/host/home/luce/.vscode-server/**/*.log` | `log_source=vscode_server`, `filename` |
| Codex TUI | File tail | `/home/luce/.codex/log/codex-tui.log` | `/host/home/luce/.codex/log/codex-tui.log` | `log_source=codex_tui`, `source_type=file` |
| Host WireGuard | File tail | `/var/log/wireguard-client-manager.log` | `/host/var/log/wireguard-client-manager.log` | `log_source=host_wireguard`, `source_type=file` |
| Host Codeswarm | File tail | `/var/log/codeswarm.log` | `/host/var/log/codeswarm.log` | `log_source=host_codeswarm`, `source_type=file` |
| Host APT | File tail | `/var/log/apt/history.log` | `/host/var/log/apt/history.log` | `log_source=host_apt`, `source_type=file` |

**Architecture notes:**
- **Two systemd paths are active:** direct `loki.source.journal` and rsyslog relay (`imjournal` → TCP:1514).
- **Docker:** Filtered to vllm and hex compose projects only
- **File sources:** Tailed via loki.source.file with position tracking; host `/var/log` mounted at `/host/var/log`
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
| Alert sink | `logging-alert-sink-1` |
| Alloy | `logging-alloy-1` |
| Node Exporter | `logging-host-monitor-1` |
| cAdvisor | `logging-docker-metrics-1` |

### Volume Mount Points

| Volume | Service | Container Path | Purpose |
|--------|---------|----------------|---------|
| `grafana-data` | grafana | `/var/lib/grafana` | Dashboards, users, settings |
| `loki-data` | loki | `/loki` | Chunks, index, compactor state |
| `prometheus-data` | prometheus | `/prometheus` | Time-series database (TSDB) |
| `alloy-positions` | alloy | `/var/lib/alloy` | File tail positions, syslog cursor tracking |

### Resource Limits (Current Compose)

Resource limits are currently set in compose using `mem_limit` + `cpus` (not `deploy.resources`):

| Service | `mem_limit` | `cpus` |
|---------|-------------|--------|
| grafana | `1g` | `0.50` |
| loki | `2g` | `1.00` |
| alert-sink | `128m` | `0.10` |
| prometheus | `2g` | `1.00` |
| alloy | `1g` | `0.75` |
| host-monitor | `1g` | `1.00` |
| docker-metrics | `2g` | `2.00` |

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

### File-Based Log Labels

| Label | Source | Example | Required for File Logs |
|-------|--------|---------|------------------------|
| `filename` | Alloy file match | `/host/home/luce/_logs/test.log` | Yes |
| `log_source` | Alloy/static listener labels | `docker`, `journald`, `rsyslog_syslog`, `codeswarm_mcp`, `vscode_server`, `tool_sink`, `telemetry`, `gpu_telemetry`, `nvidia_telem`, `codex_tui`, `host_wireguard`, `host_codeswarm`, `host_apt` | Yes (source-specific value) |

### Source-Specific Labels

| Label | Source | Values | Notes |
|-------|--------|--------|-------|
| `syslog_channel` | rsyslog_syslog | `general`, `ufw`, `auth`, `kernel`, `cron`, `other` | Set by syslog content matching in `loki.process.main` |
| `security_domain` | rsyslog_syslog (matching lines) | `firewall`, `auth` | Set on UFW and auth syslog lines |
| `mcp_level` | codeswarm_mcp | (JSON `level` field) | Extracted from structured MCP JSON logs |
| `service_name` | codeswarm_mcp, rsyslog_syslog | (value varies) | Extracted from JSON or syslog unit name |
| `telemetry_tier` | nvidia_telem | `raw30` | Static label on all NVIDIA telemetry files |
| `source_type` | multiple | `docker`, `syslog`, `file`, `gpu_csv` | `gpu_csv` on GPU telemetry streams |

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

### Loki (Loopback + Internal)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/ready` | GET | Readiness check |
| `/loki/api/v1/push` | POST | Log ingestion (from Alloy) |
| `/loki/api/v1/query` | GET | Instant query |
| `/loki/api/v1/query_range` | GET | Range query |
| `/loki/api/v1/labels` | GET | List labels |

**Base URL (internal):** http://loki:3100
**Base URL (host loopback):** http://127.0.0.1:3200

**Access:** `obs` Docker network and host loopback only (not LAN-exposed by default)

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

### Prometheus Scrape Targets

| Job | Target | Notes |
|-----|--------|-------|
| prometheus | `prometheus:9090` | Self-monitoring |
| host-monitor | `host-monitor:9100` | Node Exporter (host metrics) |
| docker-metrics | `docker-metrics:8080` | cAdvisor (container metrics) |
| loki | `loki:3100` | Loki metrics |
| alloy | `alloy:12345` | Alloy metrics |
| wireguard | `172.20.0.1:9586` | WireGuard exporter on host (via Docker bridge gateway) |
| grafana | `grafana:3000` | Grafana metrics |

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
| Grafana | `grafana/grafana` | 11.5.2 | Docker Hub |
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
{env="sandbox", log_source="docker"}

# Specific compose service
{env="sandbox", service="codeswarm-mcp"}

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
