# Quick Access URLs

**Headless Ubuntu Host:** `<HOST_IP>` (set in `.env`; LAN IP of the machine running the stack)

## Authoritative Sources

Use these files as the contract for current behavior and runtime checks:

- `infra/logging/docker-compose.observability.yml`
- `infra/logging/alloy-config.alloy`
- `infra/logging/prometheus/rules/loki_logging_rules.yml`
- `infra/logging/prometheus/rules/sprint3_minimum_alerts.yml`
- `infra/logging/grafana/dashboards/*.json`
- `scripts/prod/mcp/logging_stack_health.sh`
- `scripts/prod/mcp/logging_stack_audit.sh`
- `docs/query-contract.md`

## Web Interfaces (LAN Access)

### Grafana
- **URL:** http://`<HOST_IP>`:9001
- **Login:** See `infra/logging/.env` for credentials
- **Default:** admin / (password from .env)
- **Use for:** Log queries, dashboards, visualization

### Prometheus
- **URL:** http://`<HOST_IP>`:9004
- **Login:** None (no authentication)
- **Use for:** Metrics queries, target monitoring, PromQL

## Network Configuration

**Binding:** 0.0.0.0 (all interfaces)
**Access:** LAN only (your subnet, e.g. 192.168.1.0/24)
**Firewall:** UFW rules allow ports 9001, 9004 from LAN

## Firewall Rules (UFW)

```bash
# View current rules
sudo ufw status numbered

# Expected (subnet matches your LAN):
# [X] 9001    ALLOW IN    <LAN_SUBNET>    # Grafana LAN
# [Y] 9004    ALLOW IN    <LAN_SUBNET>    # Prometheus LAN
```

## Health Checks

**From host (SSH):**
```bash
# Quick health gate
./scripts/prod/mcp/logging_stack_health.sh

# Deep audit report
./scripts/prod/mcp/logging_stack_audit.sh _build/Sprint-3/reference/native_audit.json
```

**Or using localhost:**
```bash
curl -sf http://127.0.0.1:9001/api/health
curl -sf http://127.0.0.1:9004/-/ready
docker run --rm --network obs curlimages/curl:8.6.0 -sf http://loki:3100/ready
```

## Common Queries

**In Grafana → Explore → Loki:**

```logql
# All logs
{env="sandbox"}

# Docker container logs
{env="sandbox", container_name=~".+"}

# Errors only
{env="sandbox"} |= "error"

# CodeSwarm MCP logs
{env="sandbox", log_source="codeswarm_mcp"}
```

**In Prometheus → Graph:**

```promql
# Recording-rule based target health
sprint3:targets_up:count
sprint3:targets_down:count

# Scrape failure rate
sprint3:prometheus_scrape_failures:rate5m

# Container memory usage
topk(10, sprint3:container_memory_workingset_bytes)
```

## Stack Control (SSH)

```bash
# Health check
./scripts/prod/mcp/logging_stack_health.sh

# Audit
./scripts/prod/mcp/logging_stack_audit.sh _build/Sprint-3/reference/native_audit.json

# View logs
docker compose -p logging -f infra/logging/docker-compose.observability.yml logs -f

# Restart service
docker compose -p logging -f infra/logging/docker-compose.observability.yml restart grafana

# Stop stack
./scripts/prod/mcp/logging_stack_down.sh

# Start stack
./scripts/prod/mcp/logging_stack_up.sh
```

## Accessing from Different Devices

### From Laptop/Desktop (Same LAN)
- Open browser
- Navigate to http://`<HOST_IP>`:9001
- Login with credentials

### From Mobile (Same LAN)
- Open browser
- Navigate to http://`<HOST_IP>`:9001
- Login with credentials
- Use Grafana mobile view

### From Remote (VPN/WireGuard)
- Ensure VPN connected to your LAN subnet
- Navigate to http://`<HOST_IP>`:9001

### NOT Accessible
- ❌ From internet (no port forwarding)
- ❌ From other networks without VPN
- ❌ Direct host access (headless, no GUI)

## Documentation

- **Full docs:** [docs/](docs/)
- **README:** [README.md](README.md)
- **Operations:** [docs/operations.md](docs/operations.md)
- **Troubleshooting:** [docs/troubleshooting.md](docs/troubleshooting.md)
- **Query contract:** [docs/query-contract.md](docs/query-contract.md)

---

**Last updated:** 2026-02-19
**Host IP:** Set in `.env` — replace `<HOST_IP>` with your machine's LAN address
**Network:** Your LAN subnet (e.g. 192.168.1.0/24)
