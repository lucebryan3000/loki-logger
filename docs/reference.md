# Reference

Stable reference data for the Loki logging stack.

## Port Assignments

| Service | Internal Port | External Binding | Protocol | Purpose |
|---------|---------------|------------------|----------|---------|
| Grafana | 3000 | 127.0.0.1:9001 | HTTP | Web UI, API |
| Prometheus | 9090 | 127.0.0.1:9004 | HTTP | Web UI, API |
| Loki | 3100 | None (internal) | HTTP | Push/query API |
| Alloy | 12345 | None (internal) | HTTP | Admin UI |
| Node Exporter | 9100 | None (internal) | HTTP | Metrics endpoint |
| cAdvisor | 8080 | None (internal) | HTTP | Metrics endpoint |

**Loopback-only services:** Grafana, Prometheus (127.0.0.1 binding prevents network access)

**Internal-only services:** Loki, Alloy, Node Exporter, cAdvisor (no exposed ports)

## Environment Variables (.env)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GRAFANA_ADMIN_USER` | Yes | - | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | Yes | - | Grafana admin password (min 8 chars) |
| `GRAFANA_SECRET_KEY` | Yes | - | Session encryption key (32+ random chars) |
| `GRAFANA_HOST` | No | 127.0.0.1 | Grafana bind address |
| `GRAFANA_PORT` | No | 9001 | Grafana external port |
| `PROM_HOST` | No | 127.0.0.1 | Prometheus bind address |
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
│   ├── mcp/
│   │   ├── logging_stack_up.sh            # Deploy stack
│   │   ├── logging_stack_down.sh          # Stop stack
│   │   └── logging_stack_health.sh        # Health checks
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
| Grafana | `infra/logging/grafana/provisioning/` | `/etc/grafana/provisioning/` |

**All configs mounted read-only (`:ro`).** Changes require container restart.

### Log Source Paths

| Source | Host Path | Container Path (Alloy) | Label |
|--------|-----------|------------------------|-------|
| Tool logs | `/home/luce/_logs/*.log` | `/host/home/luce/_logs/*.log` | `filename` |
| Telemetry | `/home/luce/_telemetry/*.jsonl` | `/host/home/luce/_telemetry/*.jsonl` | `filename` |
| CodeSwarm MCP | `/home/luce/apps/vLLM/_data/mcp-logs/*.log` | `/host/home/luce/apps/vLLM/_data/mcp-logs/*.log` | `log_source=codeswarm_mcp` |
| Docker logs | `/var/run/docker.sock` | `/var/run/docker.sock` | `container_name` |
| Systemd journal | `/var/log/journal`, `/run/log/journal` | Same | `job=journald` |

## Docker Resources

### Compose Project

- **Project name:** `infra_observability`
- **Network:** `obs` (bridge)
- **Volumes:** `grafana-data`, `loki-data`, `prometheus-data`

### Container Names

| Service | Container Name |
|---------|----------------|
| Grafana | `infra_observability-grafana-1` |
| Loki | `infra_observability-loki-1` |
| Prometheus | `infra_observability-prometheus-1` |
| Alloy | `infra_observability-alloy-1` |
| Node Exporter | `infra_observability-node_exporter-1` |
| cAdvisor | `infra_observability-cadvisor-1` |

### Volume Mount Points

| Volume | Service | Container Path | Purpose |
|--------|---------|----------------|---------|
| `grafana-data` | grafana | `/var/lib/grafana` | Dashboards, users, settings |
| `loki-data` | loki | `/loki` | Chunks, index, compactor state |
| `prometheus-data` | prometheus | `/prometheus` | Time-series database (TSDB) |

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
| `env` | Alloy static label | `sandbox`, `dev`, `prod` | Yes |
| `host` | Auto-detected | `codeswarm` | Yes |
| `job` | Alloy source name | `dockerlogs`, `tool_sink`, `telemetry` | Yes |

### Docker-Specific Labels

| Label | Source | Example | Required for Docker Logs |
|-------|--------|---------|--------------------------|
| `container_name` | Docker metadata | `infra_observability-grafana-1` | Yes |
| `image` | Docker metadata | `grafana/grafana:11.1.0` | No |
| `compose_project` | Docker metadata | `infra_observability` | No |

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

**Authentication:** None (loopback trusted)

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
{env="sandbox", container_name="infra_observability-grafana-1"}

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
# All targets up
up

# Failed targets
up == 0

# CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory available
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Loki ingestion rate
rate(loki_distributor_lines_received_total[5m])

# Container memory usage
container_memory_usage_bytes{name=~".+"}

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
docker compose -f infra/logging/docker-compose.observability.yml ps

# Stack health script
./scripts/mcp/logging_stack_health.sh
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
docker logs infra_observability-<service>-1 --tail 50
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

**Generated by:** `./scripts/prism/evidence.sh`

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
- [snippets/](snippets/) — Config file excerpts
