# Loki Logging Stack

Production-grade logging and observability stack for local development. Centralized log aggregation from Docker containers, file-based sources, and custom telemetry streams, with metrics collection and unified dashboards.

## Quick Start

### Prerequisites
- Docker 20.10+
- Docker Compose v2.0+
- 4GB+ RAM, 10GB+ free disk

### Deploy Stack

```bash
# Deploy all services
./scripts/prod/mcp/logging_stack_up.sh

# Verify health
./scripts/prod/mcp/logging_stack_health.sh
```

**Expected output:**
```
grafana_ok=1
prometheus_ok=1
```

### Access Grafana

```bash
# Open in browser
open http://127.0.0.1:9001

# Login with credentials from .env
# Default: admin / (password from .env)
```

**First-time setup:**
1. Navigate to **Explore** (compass icon in sidebar)
2. Select **Loki** data source
3. Run query: `{env="sandbox"} | limit 10`
4. Verify logs appear

### Query Logs

In Grafana → Explore → Loki:

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

### Generate Evidence

```bash
# Create proof archive of stack operation
./scripts/prod/prism/evidence.sh

# Output: temp/evidence/loki-<timestamp>/
```

## What's Inside

| Service | Purpose | Access |
|---------|---------|--------|
| **Grafana** | Visualization, dashboards, query interface | http://127.0.0.1:9001 |
| **Prometheus** | Metrics collection and alerting | http://127.0.0.1:9004 |
| **Loki** | Log aggregation and storage | Internal only |
| **Alloy** | Log ingestion agent | Internal only |
| **Node Exporter** | Host metrics | Internal only |
| **cAdvisor** | Container metrics | Internal only |

**Data flow:**
```
Logs/Metrics → Alloy/Prometheus → Loki/Prometheus → Grafana
```

## Log Sources

Alloy ingests logs from:
- Docker containers (via `/var/run/docker.sock`)
- Systemd journal (`/var/log/journal`)
- File-based logs:
  - `/home/luce/_logs/*.log`
  - `/home/luce/_telemetry/*.jsonl`
  - `/home/luce/apps/vLLM/_data/mcp-logs/*.log`

## Key Features

- **30-day log retention** (configurable)
- **15-day metrics retention** (configurable)
- **Label-based filtering** (env, host, container_name, log_source)
- **Evidence generation** (cryptographically verifiable proofs)
- **LAN-accessible** (0.0.0.0 binding, UFW-protected)
- **Internal-only Loki** (no external API exposure)

## Common Operations

```bash
# Health check
./scripts/prod/mcp/logging_stack_health.sh

# View all logs
docker compose -p logging -f infra/logging/docker compose.observability.yml logs -f

# Restart service
docker compose -p logging -f infra/logging/docker compose.observability.yml restart <service>

# Stop stack
./scripts/prod/mcp/logging_stack_down.sh

# Start stack
./scripts/prod/mcp/logging_stack_up.sh
```

## Validation

Run strict validation proofs:

```bash
# 1. Health checks
curl -sf http://127.0.0.1:9001/api/health
curl -sf http://127.0.0.1:9004/-/ready

# 2. Generate test log
echo "validation_$(date +%s)" >> /home/luce/_logs/test.log

# 3. Wait for ingestion (10-15 seconds)
sleep 15

# 4. Query in Grafana
# {env="sandbox", filename=~".*test.log"} |= "validation_"
```

See [validation.md](validation.md) for full validation checklist.

## Troubleshooting

### No logs in Loki
- Check Alloy is running: `docker ps | grep alloy`
- Check Alloy logs: `docker logs logging-alloy-1 --tail 50`
- Verify log files exist: `ls -lh /home/luce/_logs/`

### Grafana login fails
- Check credentials: `grep GRAFANA_ADMIN .env`
- Reset password: `docker exec -it logging-grafana-1 grafana cli admin reset-admin-password <new-password>`

### Empty query results
- Use non-empty selector: `{env=~".+"}` not `{}`
- Check time range (Grafana time picker, top-right)
- Allow 10-15 seconds for ingestion delay

See [troubleshooting.md](troubleshooting.md) for full troubleshooting guide.

## Documentation

- **[INDEX.md](INDEX.md)** — Full table of contents
- **[overview.md](overview.md)** — Concepts, scope, guardrails
- **[architecture.md](architecture.md)** — Data flow, components, networks
- **[deployment.md](deployment.md)** — Deploy, redeploy, upgrades
- **[operations.md](operations.md)** — Runbooks, queries, admin tasks
- **[validation.md](validation.md)** — Strict validation proofs
- **[troubleshooting.md](troubleshooting.md)** — Symptoms → causes → fixes
- **[security.md](security.md)** — Exposure posture, secrets handling
- **[maintenance.md](maintenance.md)** — Retention, backups, upgrades
- **[reference.md](reference.md)** — Ports, labels, paths, env vars

## Common Gotchas

1. **Empty Loki selectors fail** — Always use `{env=~".+"}` or similar
2. **Alloy uses `//` comments** — Not `#` (HCL syntax, not YAML)
3. **Prometheus retention is CLI-only** — Not configurable in `prometheus.yml`
4. **Ingestion delay is normal** — Allow 10-15 seconds for logs to appear
5. **Loki is internal-only** — No http://127.0.0.1:3100 (use Grafana instead)

See [troubleshooting.md](troubleshooting.md#common-pitfalls) for full list.

## Security

- **UFW-protected LAN access:** Grafana and Prometheus bound to 0.0.0.0
- **Internal-only Loki:** No external API exposure
- **Secrets in .env:** Mode 600, gitignored, never logged
- **No secrets in evidence:** Evidence files never contain passwords/keys

See [security.md](security.md) for security posture and best practices.

## Maintenance

### Retention
- **Logs (Loki):** 30 days (720h)
- **Metrics (Prometheus):** 15 days

### Backups
- **Grafana dashboards:** `docker cp logging-grafana-1:/var/lib/grafana /backup`
- **Configs:** Version-controlled in git
- **Logs/metrics:** Ephemeral (short retention, no long-term backup)

### Upgrades
```bash
# Pull new images
docker compose -p logging -f infra/logging/docker compose.observability.yml pull

# Recreate containers
docker compose up -d

# Verify health
./scripts/prod/mcp/logging_stack_health.sh
```

See [maintenance.md](maintenance.md) for full maintenance procedures.

## Repository Structure

```
/home/luce/apps/loki-logging/
├── infra/logging/              # Stack configs
│   ├── docker-compose.observability.yml
│   ├── .env                    # Secrets (mode 600)
│   ├── loki-config.yml
│   ├── alloy-config.alloy
│   └── prometheus/
├── scripts/
│   ├── mcp/                    # Control scripts
│   │   ├── logging_stack_up.sh
│   │   ├── logging_stack_down.sh
│   │   └── logging_stack_health.sh
│   └── prism/
│       └── evidence.sh         # Evidence generation
├── docs/                       # Documentation (you are here)
└── temp/evidence/              # Evidence archives
```

## Support

**Documentation issues:** Check [quality-checklist.md](quality-checklist.md) for validation

**Stack issues:** See [troubleshooting.md](troubleshooting.md)

**Upstream projects:**
- Grafana Loki: https://github.com/grafana/loki
- Grafana: https://github.com/grafana/grafana
- Prometheus: https://github.com/prometheus/prometheus
- Alloy: https://github.com/grafana/alloy

## License

See repository root for license information.
