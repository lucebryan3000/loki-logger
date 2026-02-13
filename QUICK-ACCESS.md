# Quick Access URLs

**Headless Ubuntu Host:** 192.168.1.150

## Web Interfaces (LAN Access)

### Grafana
- **URL:** http://192.168.1.150:9001
- **Login:** See `infra/logging/.env` for credentials
- **Default:** admin / (password from .env)
- **Use for:** Log queries, dashboards, visualization

### Prometheus
- **URL:** http://192.168.1.150:9004
- **Login:** None (no authentication)
- **Use for:** Metrics queries, target monitoring, PromQL

## Network Configuration

**Binding:** 0.0.0.0 (all interfaces)
**Access:** LAN only (192.168.1.0/24)
**Firewall:** UFW rules allow ports 9001, 9004 from LAN

## Firewall Rules (UFW)

```bash
# View current rules
sudo ufw status numbered

# Expected:
# [X] 9001    ALLOW IN    192.168.1.0/24    # Grafana LAN
# [Y] 9004    ALLOW IN    192.168.1.0/24    # Prometheus LAN
```

## Health Checks

**From host (SSH):**
```bash
curl -sf http://192.168.1.150:9001/api/health
curl -sf http://192.168.1.150:9004/-/ready
```

**Or using localhost:**
```bash
curl -sf http://127.0.0.1:9001/api/health
curl -sf http://127.0.0.1:9004/-/ready
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
# All targets up/down
up

# Loki ingestion rate
rate(loki_distributor_lines_received_total[5m])

# Container memory usage
container_memory_usage_bytes{name=~".+"}
```

## Stack Control (SSH)

```bash
# Health check
./scripts/mcp/logging_stack_health.sh

# View logs
docker compose -f infra/logging/docker-compose.observability.yml logs -f

# Restart service
docker compose -f infra/logging/docker-compose.observability.yml restart grafana

# Stop stack
./scripts/mcp/logging_stack_down.sh

# Start stack
./scripts/mcp/logging_stack_up.sh
```

## Accessing from Different Devices

### From Laptop/Desktop (Same LAN)
- Open browser
- Navigate to http://192.168.1.150:9001
- Login with credentials

### From Mobile (Same LAN)
- Open browser
- Navigate to http://192.168.1.150:9001
- Login with credentials
- Use Grafana mobile view

### From Remote (VPN/WireGuard)
- Ensure VPN connected to 192.168.1.0/24 network
- Same URLs as above

### NOT Accessible
- ❌ From internet (no port forwarding)
- ❌ From other networks without VPN
- ❌ Direct host access (headless, no GUI)

## Documentation

- **Full docs:** [docs/](docs/)
- **README:** [README.md](README.md)
- **Operations:** [docs/operations.md](docs/operations.md)
- **Troubleshooting:** [docs/troubleshooting.md](docs/troubleshooting.md)

---

**Last updated:** 2026-02-13
**Host IP:** 192.168.1.150
**Network:** 192.168.1.0/24
