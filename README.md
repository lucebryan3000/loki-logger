# Loki Logging Stack

Production-grade log aggregation and observability stack for local development. Centralized logging from Docker containers, file-based sources, and custom telemetry streams with metrics collection and unified Grafana dashboards.

## What's Deployed

This repository runs a complete observability stack on `localhost`:

| Service | URL | Purpose |
|---------|-----|---------|
| **Grafana** | http://127.0.0.1:9001 | Dashboards, log queries, visualization |
| **Prometheus** | http://127.0.0.1:9004 | Metrics collection and querying |
| **Loki** | Internal only | Log storage and aggregation |
| **Alloy** | Internal only | Log ingestion from multiple sources |
| **Node Exporter** | Internal only | Host-level metrics (CPU, memory, disk) |
| **cAdvisor** | Internal only | Container-level metrics |

**Network:** All services run on isolated Docker network `obs`
**Compose project:** `infra_observability`
**Data retention:** 30 days (logs), 15 days (metrics)

## Getting Started

### Quick Access

```bash
# Open Grafana (login with credentials from infra/logging/.env)
open http://127.0.0.1:9001

# Check stack health
./scripts/mcp/logging_stack_health.sh

# View all logs
docker compose -f infra/logging/docker-compose.observability.yml logs -f

# Generate evidence/proof archive
./scripts/prism/evidence.sh
```

### First-Time Setup

If you haven't deployed yet, see [docs/deployment.md](docs/deployment.md) for full deployment instructions.

**Prerequisites:**
- Docker 20.10+
- Docker Compose v2.0+
- 4GB+ RAM, 10GB+ free disk

**Deploy:**
```bash
# Start the stack
./scripts/mcp/logging_stack_up.sh

# Verify all services running
./scripts/mcp/logging_stack_health.sh
```

### Querying Logs in Grafana

1. Open http://127.0.0.1:9001
2. Navigate to **Explore** (compass icon)
3. Select **Loki** data source
4. Run a query:

```logql
# All logs from sandbox environment
{env="sandbox"}

# Docker container logs only
{env="sandbox", container_name=~".+"}

# Search for errors
{env="sandbox"} |= "error"

# CodeSwarm MCP logs
{env="sandbox", log_source="codeswarm_mcp"}
```

**Important:** Always use non-empty label selectors. Never query `{}` (will fail).

See [docs/operations.md](docs/operations.md#log-queries-logql) for more query examples.

### Log Sources

Alloy automatically ingests logs from:

- **Docker containers** (via `/var/run/docker.sock`)
- **Systemd journal** (`/var/log/journal`)
- **File-based logs:**
  - `/home/luce/_logs/*.log` (general application logs)
  - `/home/luce/_telemetry/*.jsonl` (structured telemetry)
  - `/home/luce/apps/vLLM/_data/mcp-logs/*.log` (CodeSwarm MCP logs)

All logs are labeled with `env=sandbox`, `host=codeswarm`, and additional source-specific labels.

## Common Operations

```bash
# Health check
./scripts/mcp/logging_stack_health.sh

# Restart a service (e.g., after config change)
docker compose -f infra/logging/docker-compose.observability.yml restart alloy

# Stop the stack
./scripts/mcp/logging_stack_down.sh

# Start the stack
./scripts/mcp/logging_stack_up.sh

# View service logs
docker logs infra_observability-grafana-1 --tail 100
docker logs infra_observability-loki-1 --tail 100
```

## Documentation

**Full documentation:** [docs/](docs/)

Quick links:
- **[docs/README.md](docs/README.md)** — Documentation quickstart
- **[docs/INDEX.md](docs/INDEX.md)** — Complete table of contents
- **[docs/operations.md](docs/operations.md)** — Runbooks and common tasks
- **[docs/troubleshooting.md](docs/troubleshooting.md)** — Common issues and fixes
- **[docs/validation.md](docs/validation.md)** — Validation proofs and health checks

**By topic:**
- Architecture: [docs/architecture.md](docs/architecture.md)
- Deployment: [docs/deployment.md](docs/deployment.md)
- Security: [docs/security.md](docs/security.md)
- Maintenance: [docs/maintenance.md](docs/maintenance.md)
- Reference: [docs/reference.md](docs/reference.md)

## Troubleshooting

### No logs in Loki

```bash
# Check Alloy is running
docker ps | grep alloy

# Check Alloy logs for errors
docker logs infra_observability-alloy-1 --tail 50

# Verify log files exist and are readable
ls -lh /home/luce/_logs/
```

### Grafana login fails

```bash
# Check credentials
grep GRAFANA_ADMIN infra/logging/.env

# Reset password
docker exec -it infra_observability-grafana-1 \
  grafana cli admin reset-admin-password <new-password>
```

### Empty query results

- Use non-empty selector: `{env=~".+"}` not `{}`
- Check time range in Grafana (top-right time picker)
- Allow 10-15 seconds for log ingestion delay

**Full troubleshooting guide:** [docs/troubleshooting.md](docs/troubleshooting.md)

## Configuration

### Environment Variables

Secrets and configuration are in `infra/logging/.env` (mode 600, gitignored):

```bash
# View example config
cat infra/logging/.env.example

# Edit actual config (never commit this file)
nano infra/logging/.env
```

**Required variables:**
- `GRAFANA_ADMIN_USER` — Admin username
- `GRAFANA_ADMIN_PASSWORD` — Admin password (min 8 chars)
- `GRAFANA_SECRET_KEY` — Session encryption key (32+ random chars)

**Optional variables:**
- `GRAFANA_HOST` / `GRAFANA_PORT` — Binding address and port
- `PROM_HOST` / `PROM_PORT` — Prometheus binding
- `HOST_HOME` — Host home directory for Alloy mounts

**Root `.env.example`** is a generic template for other projects, not used by this stack.

### Configuration Files

| File | Purpose |
|------|---------|
| `infra/logging/docker-compose.observability.yml` | Stack definition |
| `infra/logging/loki-config.yml` | Loki retention and storage |
| `infra/logging/alloy-config.alloy` | Log ingestion pipelines |
| `infra/logging/prometheus/prometheus.yml` | Metrics scrape targets |
| `infra/logging/.env` | Secrets (mode 600) |

**Config snippets:** [docs/snippets/](docs/snippets/)

## Repository Structure

```
/home/luce/apps/loki-logging/
├── infra/logging/                # Stack configuration
│   ├── docker-compose.observability.yml
│   ├── .env                      # Secrets (mode 600, gitignored)
│   ├── .env.example              # Loki stack template
│   ├── loki-config.yml
│   ├── alloy-config.alloy
│   ├── grafana/
│   │   ├── provisioning/         # Auto-provisioned data sources
│   │   └── dashboards/
│   └── prometheus/
│       ├── prometheus.yml
│       └── rules/
├── scripts/
│   ├── mcp/                      # Control scripts
│   │   ├── logging_stack_up.sh
│   │   ├── logging_stack_down.sh
│   │   └── logging_stack_health.sh
│   └── prism/
│       └── evidence.sh           # Evidence/proof generation
├── docs/                         # Full documentation
│   ├── README.md                 # Docs quickstart
│   ├── INDEX.md                  # Complete table of contents
│   ├── overview.md
│   ├── architecture.md
│   ├── deployment.md
│   ├── operations.md
│   ├── validation.md
│   ├── troubleshooting.md
│   ├── security.md
│   ├── maintenance.md
│   ├── reference.md
│   ├── quality-checklist.md
│   ├── archive/                  # Historical snapshots
│   └── snippets/                 # Config excerpts
├── temp/evidence/                # Evidence archives (gitignored)
├── .env -> infra/logging/.env    # Symlink for convenience
└── .env.example                  # Generic template (not Loki-specific)
```

## Security

- **Loopback-only binding:** Grafana and Prometheus bound to 127.0.0.1 (no network access)
- **Internal-only Loki:** No exposed ports, accessible only from Docker `obs` network
- **Secrets in .env:** Mode 600, never committed to git
- **No secrets in evidence:** Evidence files never contain passwords or keys

**Full security documentation:** [docs/security.md](docs/security.md)

## Maintenance

### Retention

- **Logs (Loki):** 30 days (720h)
- **Metrics (Prometheus):** 15 days

Change retention in:
- Loki: `infra/logging/loki-config.yml` → `retention_period`
- Prometheus: `infra/logging/docker-compose.observability.yml` → CLI flag `--storage.tsdb.retention.time`

### Backups

```bash
# Backup Grafana dashboards
mkdir -p ~/backups/grafana/$(date +%Y%m%d)
docker run --rm \
  -v infra_observability_grafana-data:/data:ro \
  -v ~/backups/grafana/$(date +%Y%m%d):/backup \
  alpine tar czf /backup/grafana-data.tar.gz -C /data .
```

**Full maintenance guide:** [docs/maintenance.md](docs/maintenance.md)

## Validation

Run strict validation proofs to confirm stack operation:

```bash
# 1. Health checks
curl -sf http://127.0.0.1:9001/api/health
curl -sf http://127.0.0.1:9004/-/ready

# 2. Generate test log
echo "validation_$(date +%s)" >> /home/luce/_logs/test.log

# 3. Wait for ingestion
sleep 15

# 4. Query in Grafana (manual)
# {env="sandbox", filename=~".*test.log"} |= "validation_"

# 5. Generate evidence archive
./scripts/prism/evidence.sh
```

**Full validation checklist:** [docs/validation.md](docs/validation.md)

## Common Gotchas

1. **Empty Loki selectors fail** — Always use `{env=~".+"}` or similar, never `{}`
2. **Alloy uses `//` comments** — Not `#` (HCL syntax, not YAML)
3. **Prometheus retention is CLI-only** — Cannot be set in `prometheus.yml`
4. **Ingestion delay is normal** — Allow 10-15 seconds for logs to appear
5. **Loki is internal-only** — No http://127.0.0.1:3100 access (use Grafana)
6. **Config changes require restart** — `docker compose restart <service>` after editing configs
7. **Frozen query window** — Check Grafana time picker (use relative ranges like "Last 15 minutes")

**Full list:** [docs/troubleshooting.md](docs/troubleshooting.md#common-pitfalls)

## Evidence and Proof System

Generate cryptographically verifiable evidence of stack operation for audit/compliance:

```bash
# Generate evidence archive
./scripts/prism/evidence.sh

# Output: temp/evidence/loki-<timestamp>/
# Contains: stack state, health checks, query proofs, config hashes
```

Evidence files **never contain secrets** from `.env`.

**Documentation:** [docs/operations.md](docs/operations.md#evidence-generation)

## Support

- **Documentation:** [docs/](docs/)
- **Quality checklist:** [docs/quality-checklist.md](docs/quality-checklist.md)
- **Troubleshooting:** [docs/troubleshooting.md](docs/troubleshooting.md)

**Upstream projects:**
- Grafana Loki: https://github.com/grafana/loki
- Grafana: https://github.com/grafana/grafana
- Prometheus: https://github.com/prometheus/prometheus
- Grafana Alloy: https://github.com/grafana/alloy

## License

See repository for license information.

---

**Quick start:** [docs/README.md](docs/README.md) | **Full documentation:** [docs/INDEX.md](docs/INDEX.md)
