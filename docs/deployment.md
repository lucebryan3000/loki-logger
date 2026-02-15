# Deployment

## Prerequisites

1. **Docker and Docker Compose installed:**
   ```bash
   docker --version  # >= 20.10
   docker compose version  # >= v2.0
   ```

2. **Secrets file exists:**
   ```bash
   ls -l .env
   # Expected: -rw------- 1 luce luce (mode 600)
   ```

   If missing, create from example:
   ```bash
   cp .env.example .env
   chmod 600 .env
   # Edit with your credentials
   ```

3. **Port availability:**
   ```bash
   # Check ports 9001 (Grafana) and 9004 (Prometheus) are free
   ss -tln | grep -E ':(9001|9004)'
   # No output = ports available
   ```

## Initial Deployment

### Using Control Scripts (Recommended)

```bash
# Deploy the stack
./scripts/prod/mcp/logging_stack_up.sh

# Verify health
./scripts/prod/mcp/logging_stack_health.sh
```

**Expected output (health check):**
```
grafana_ok=1
prometheus_ready_ok=1
prometheus_targets_ok=1
loki_ready_ok=1
overall=pass
```

### Manual Deployment

```bash
# Pull latest images
docker compose -p logging -f infra/logging/docker-compose.observability.yml pull

# Start stack (detached)
docker compose -p logging -f infra/logging/docker-compose.observability.yml up -d

# Verify all containers running
docker compose -p logging -f infra/logging/docker-compose.observability.yml ps
```

**Expected container states:**
```
NAME                                  STATUS
logging-alloy-1           Up
logging-docker-metrics-1  Up (healthy)
logging-grafana-1         Up
logging-loki-1            Up
logging-host-monitor-1    Up
logging-prometheus-1      Up
```

## Post-Deployment Validation

### 1. Service Health Checks

```bash
# Grafana
curl -sf http://127.0.0.1:9001/api/health || echo "FAILED"

# Prometheus
curl -sf http://127.0.0.1:9004/-/ready || echo "FAILED"
curl -sf http://127.0.0.1:9004/-/healthy || echo "FAILED"
```

### 2. Grafana Login

```bash
# Open browser
open http://127.0.0.1:9001
# Or: xdg-open http://127.0.0.1:9001

# Login with credentials from .env:
# Username: GRAFANA_ADMIN_USER
# Password: GRAFANA_ADMIN_PASSWORD
```

**First-time setup:**
1. Navigate to **Connections → Data sources**
2. Verify **Loki** and **Prometheus** are listed (auto-provisioned)
3. Test both data sources (should show "Data source is working")

### 3. Log Ingestion Verification

Navigate to **Grafana → Explore → Loki** and run:

```logql
# Broad query to verify any logs are being ingested
{env=~".+"} | limit 10
```

**Expected:** 10+ log lines from various sources (Docker, files, journal)

**If no results:** Check [troubleshooting.md](troubleshooting.md#no-logs-in-loki).

### 4. Metrics Verification

Navigate to **Grafana → Explore → Prometheus** and run:

```promql
up
```

**Expected:** Targets with `up=1`:
- `job="prometheus"` (self)
- `job="host-monitor"`
- `job="docker-metrics"`

## Compose Project Conventions

- **Project name:** `logging` (enforced by operator command contract)
- **Network:** `obs` (explicit name for stable DNS)
- **Container naming:** `logging-<service>-1`

**Canonical compose contract:**
```bash
docker compose -p logging -f infra/logging/docker-compose.observability.yml <subcommand>
```

Use the contract above in docs and operator commands to avoid project/file drift.

## Redeployment

### Update Single Service

```bash
# Example: Update Alloy config and reload
docker compose -p logging -f infra/logging/docker-compose.observability.yml up -d --force-recreate alloy
```

**Services requiring restart for config changes:**
- `alloy` (alloy-config.alloy)
- `loki` (loki-config.yml)
- `prometheus` (prometheus.yml)
- `grafana` (provisioning changes)

### Full Stack Restart

```bash
# Stop all services
./scripts/prod/mcp/logging_stack_down.sh

# Start fresh
./scripts/prod/mcp/logging_stack_up.sh
```

**Data persistence:** Volumes (`grafana-data`, `loki-data`, `prometheus-data`) are **not deleted** on down/up. Logs and metrics are preserved.

### Update Images (Upgrade)

```bash
# Pull new image versions
docker compose -p logging -f infra/logging/docker-compose.observability.yml pull

# Recreate containers with new images
docker compose -p logging -f infra/logging/docker-compose.observability.yml up -d

# Verify versions
docker compose -p logging -f infra/logging/docker-compose.observability.yml ps --format "table {{.Service}}\t{{.Image}}"
```

See [maintenance.md](maintenance.md#upgrades) for version compatibility notes.

## Port Configuration

Default ports are defined in `.env`:

```bash
GRAFANA_HOST=0.0.0.0
GRAFANA_PORT=9001

PROM_HOST=0.0.0.0
PROM_PORT=9004
```

To change ports or bind address:
1. Edit `.env`
2. Restart services: `docker compose -p logging -f infra/logging/docker-compose.observability.yml up -d`

**Security:** Default binding is `0.0.0.0` (all interfaces) for headless LAN access. Ensure UFW is active to restrict access. Set to `127.0.0.1` for loopback-only access.

## Volume Management

### Inspect Volumes

```bash
docker volume ls | grep logging
```

**Expected:**
```
logging_grafana-data
logging_loki-data
logging_prometheus-data
```

### Volume Sizes

```bash
docker system df -v | grep logging
```

**Typical sizes:**
- `grafana-data`: ~50MB
- `loki-data`: ~1-5GB (depends on log volume)
- `prometheus-data`: ~500MB-2GB (15 days retention)

### Reset Stack (Destructive)

**Warning:** This deletes all logs, metrics, and Grafana dashboards.

```bash
# Stop and remove containers + volumes
docker compose -p logging -f infra/logging/docker-compose.observability.yml down -v

# Verify volumes deleted
docker volume ls | grep logging
# (should return nothing)

# Redeploy from scratch
docker compose -p logging -f infra/logging/docker-compose.observability.yml up -d
```

## Firewall Considerations

Services bind to `0.0.0.0` by default. UFW should be active to restrict access:

```bash
# Verify UFW is active
sudo ufw status verbose

# Ensure rules restrict access to trusted IPs/subnets
sudo ufw allow from 192.168.1.0/24 to any port 9001
sudo ufw allow from 192.168.1.0/24 to any port 9004
```

See [security.md](security.md#firewall-ufw) for details.

## Environment Variables

**Required in `.env`:**
- `GRAFANA_ADMIN_USER` — Admin username
- `GRAFANA_ADMIN_PASSWORD` — Admin password (min 8 chars)
- `GRAFANA_SECRET_KEY` — Session encryption key (32+ random chars)

**Optional in `.env`:**
- `GRAFANA_HOST` — Bind address (default: 0.0.0.0)
- `GRAFANA_PORT` — External port (default: 9001)
- `PROM_HOST` — Bind address (default: 0.0.0.0)
- `PROM_PORT` — External port (default: 9004)
- `HOST_HOME` — Host home directory for Alloy mounts (default: /home)

**Never commit `.env` to git.** Use `.env.example` as template.

## Log File Preparation

Alloy monitors these paths (mounted at `/host/home/luce`):

- `/home/luce/_logs/*.log`
- `/home/luce/_telemetry/*.jsonl`
- `/home/luce/apps/vLLM/_data/mcp-logs/*.log`

**Ensure directories exist:**
```bash
mkdir -p /home/luce/_logs /home/luce/_telemetry
chmod 755 /home/luce/_logs /home/luce/_telemetry
```

**Permissions:** Alloy runs as root inside container. Files must be readable by host user (luce).

## Troubleshooting Deployment Issues

### Containers Not Starting

```bash
# Check logs
docker compose -p logging -f infra/logging/docker-compose.observability.yml logs <service>

# Common issues:
# - Port already in use (check with `ss -tln`)
# - Missing .env file
# - Config syntax errors (Alloy, Prometheus)
```

### Alloy Config Parse Errors

```bash
docker logs logging-alloy-1
```

**Common mistakes:**
- Using `#` comments instead of `//`
- Malformed HCL syntax
- Incorrect path targets

See [troubleshooting.md](troubleshooting.md#alloy-config-errors).

### Grafana Not Accessible

```bash
# Check container status
docker ps | grep grafana

# Check port binding
ss -tln | grep 9001

# Test from host
curl -v http://127.0.0.1:9001/api/health
```

### Prometheus Retention Not Applied

**Symptom:** Changed `retention` in `prometheus.yml`, but old data still retained.

**Cause:** Retention is **CLI-only** (`--storage.tsdb.retention.time=15d` in compose file).

**Fix:** Edit compose file, not `prometheus.yml`. Restart Prometheus.

## Next Steps

After successful deployment:
1. Review [operations.md](operations.md) for common operational tasks
2. Run validation proofs: [validation.md](validation.md)
3. Generate evidence: `./scripts/prod/prism/evidence.sh`
4. Set up retention policies: [maintenance.md](maintenance.md)
