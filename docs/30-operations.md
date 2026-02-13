# Operations

## Common Tasks

### Health Checks

**Automated health check:**
```bash
./scripts/mcp/logging_stack_health.sh
```

**Expected output:**
```
grafana_ok=1
prometheus_ok=1
```

**Manual health checks:**
```bash
# Grafana
curl -sf http://127.0.0.1:9001/api/health
# Expected: {"commit":"...","database":"ok","version":"11.1.0"}

# Prometheus
curl -sf http://127.0.0.1:9004/-/ready
# Expected: Prometheus Server is Ready.

curl -sf http://127.0.0.1:9004/-/healthy
# Expected: Prometheus Server is Healthy.
```

**Container status:**
```bash
docker compose -f infra/logging/docker-compose.observability.yml ps
```

**All containers should show `Up` status.** If any container is restarting or exited, check logs.

### Viewing Logs

**All stack logs:**
```bash
docker compose -f infra/logging/docker-compose.observability.yml logs -f
```

**Single service logs:**
```bash
docker logs -f infra_observability-alloy-1
docker logs -f infra_observability-loki-1
docker logs -f infra_observability-grafana-1
```

**Last 100 lines:**
```bash
docker logs --tail 100 infra_observability-alloy-1
```

### Restarting Services

**Single service:**
```bash
cd infra/logging
docker compose restart <service>
```

**Common restart scenarios:**
- **Alloy:** Config changes in `alloy-config.alloy`
- **Loki:** Config changes in `loki-config.yml`
- **Prometheus:** Config changes in `prometheus/prometheus.yml`

**Full stack restart:**
```bash
./scripts/mcp/logging_stack_down.sh
./scripts/mcp/logging_stack_up.sh
```

### Force Recreate (Config Reload)

When config changes don't apply after restart:

```bash
cd infra/logging
docker compose up -d --force-recreate <service>
```

**Example: Reload Alloy config:**
```bash
docker compose -f infra/logging/docker-compose.observability.yml up -d --force-recreate alloy
```

**Note:** `--force-recreate` stops and destroys the container, then creates a new one. **Ephemeral state is lost** (e.g., Alloy log file positions).

## Log Queries (LogQL)

### Basic Queries

**All logs from sandbox environment:**
```logql
{env="sandbox"}
```

**Last 5 minutes of logs:**
```logql
{env="sandbox"} | limit 100
```

**Search for specific text:**
```logql
{env="sandbox"} |= "error"
```

**Case-insensitive search:**
```logql
{env="sandbox"} |~ "(?i)error"
```

**Exclude specific text:**
```logql
{env="sandbox"} != "health check"
```

### Docker Container Logs

**Specific container:**
```logql
{env="sandbox", container_name="infra_observability-grafana-1"}
```

**All Grafana containers:**
```logql
{env="sandbox", container_name=~".*grafana.*"}
```

**Docker logs only (exclude file sources):**
```logql
{env="sandbox", container_name=~".+"}
```

### File-Based Logs

**Telemetry logs:**
```logql
{env="sandbox", filename=~".*_telemetry.*"}
```

**Tool sink logs:**
```logql
{env="sandbox", filename=~".*_logs.*"}
```

**CodeSwarm MCP logs:**
```logql
{env="sandbox", log_source="codeswarm_mcp"}
```

**Specific proof pattern:**
```logql
{env="sandbox", log_source="codeswarm_mcp"} |= "codeswarm_mcp_proof_"
```

### Advanced Queries

**JSON parsing (for structured logs):**
```logql
{env="sandbox"} | json | level="error"
```

**Line format (extract fields):**
```logql
{env="sandbox"} | logfmt | status >= 500
```

**Rate of errors per minute:**
```logql
rate({env="sandbox"} |= "error" [1m])
```

**Count logs by container:**
```logql
sum by (container_name) (count_over_time({env="sandbox"}[5m]))
```

### Query Best Practices

1. **Always use label selectors:** Never query `{}` (empty selector)
2. **Narrow time range:** Use Grafana's time picker or `start`/`end` params
3. **Limit results:** Add `| limit 100` to large queries
4. **Use dynamic end time:** Avoid frozen query windows (see [50-troubleshooting.md](50-troubleshooting.md#frozen-query-window))

**Good query:**
```logql
{env="sandbox", container_name=~".*loki.*"} |= "error" | limit 50
```

**Bad query (will fail or timeout):**
```logql
{} |= "error"  # ❌ Empty selector
```

## Metrics Queries (PromQL)

### Service Health

**All Prometheus targets:**
```promql
up
```

**Expected output:**
- `up{job="prometheus"} = 1`
- `up{job="node_exporter"} = 1`
- `up{job="cadvisor"} = 1`

**Failed targets:**
```promql
up == 0
```

### Node Metrics

**CPU usage:**
```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Memory usage:**
```promql
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100
```

**Disk usage:**
```promql
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100
```

### Container Metrics

**CPU by container:**
```promql
rate(container_cpu_usage_seconds_total{name=~".+"}[5m])
```

**Memory by container:**
```promql
container_memory_usage_bytes{name=~".+"}
```

**Network I/O:**
```promql
rate(container_network_receive_bytes_total[5m])
rate(container_network_transmit_bytes_total[5m])
```

### Loki-Specific Metrics

**Ingestion rate (lines/sec):**
```promql
rate(loki_distributor_lines_received_total[5m])
```

**Active streams:**
```promql
loki_ingester_streams
```

**Failed ingestion:**
```promql
rate(loki_discarded_samples_total[5m])
```

## Evidence Generation

The `prism/evidence.sh` script generates **cryptographically verifiable proofs** of stack operation.

**Run evidence capture:**
```bash
./scripts/prism/evidence.sh
```

**Output location:**
```
temp/evidence/loki-<timestamp>/
├── stack-state.txt          # Container status
├── grafana-health.json      # Grafana API health
├── prometheus-ready.txt     # Prometheus readiness
├── loki-query-proof.json    # Loki query results
├── config-hashes.txt        # SHA256 of configs
└── manifest.json            # Evidence metadata
```

**Evidence use cases:**
1. **Audit trail:** Prove ingestion was working at specific time
2. **Compliance:** Show log retention and query capability
3. **Debugging:** Snapshot of stack state for troubleshooting
4. **Validation:** Confirm label contract compliance

**Evidence best practices:**
- Run after deployment to establish baseline
- Run before/after config changes
- Run during incident response
- Store in version control (temp/ is gitignored, move to docs/evidence/ if needed)

**Security:** Evidence **never contains secret values** from `.env`.

## Grafana Administration

### Accessing Grafana

```bash
# Open in browser
open http://127.0.0.1:9001

# Credentials from .env
grep GRAFANA_ADMIN infra/logging/.env
```

### Common Admin Tasks

**Reset admin password:**
```bash
docker exec -it infra_observability-grafana-1 grafana cli admin reset-admin-password <new-password>
```

**List users:**
```bash
docker exec -it infra_observability-grafana-1 grafana cli admin users list
```

**Backup dashboards:**
```bash
docker cp infra_observability-grafana-1:/var/lib/grafana /tmp/grafana-backup
```

**Restore dashboards:**
```bash
docker cp /tmp/grafana-backup/. infra_observability-grafana-1:/var/lib/grafana
docker compose -f infra/logging/docker-compose.observability.yml restart grafana
```

### Data Source Validation

1. Navigate to **Connections → Data sources**
2. Click **Loki** → **Test** (should show "Data source is working")
3. Click **Prometheus** → **Test** (should show "Data source is working")

**If test fails:**
- Check Loki/Prometheus are running (`docker compose ps`)
- Verify internal network connectivity (`docker network inspect obs`)
- Check Loki URL is `http://loki:3100` (not 127.0.0.1)

## Prometheus Administration

### Accessing Prometheus UI

```bash
open http://127.0.0.1:9004
```

**Status → Targets:** Shows all scrape targets and their health
**Status → Configuration:** Shows active prometheus.yml
**Status → Runtime & Build Information:** Shows retention, uptime, version

### Reload Configuration

**Without restart (hot reload):**
```bash
curl -X POST http://127.0.0.1:9004/-/reload
```

**Note:** Hot reload only works if `--web.enable-lifecycle` flag is enabled (not enabled by default in this stack).

**Recommended:** Use restart for config changes:
```bash
docker compose -f infra/logging/docker-compose.observability.yml restart prometheus
```

### Query API (Direct)

```bash
# Instant query
curl -G http://127.0.0.1:9004/api/v1/query \
  --data-urlencode 'query=up'

# Range query
curl -G http://127.0.0.1:9004/api/v1/query_range \
  --data-urlencode 'query=up' \
  --data-urlencode 'start=2024-01-01T00:00:00Z' \
  --data-urlencode 'end=2024-01-01T01:00:00Z' \
  --data-urlencode 'step=15s'
```

## Alloy Operations

### Config Syntax Validation

**Test config before applying:**
```bash
docker run --rm -v $(pwd)/infra/logging/alloy-config.alloy:/etc/alloy/config.alloy:ro \
  grafana/alloy:v1.2.1 \
  fmt --config.file=/etc/alloy/config.alloy
```

**Common syntax errors:**
- Using `#` comments instead of `//`
- Missing semicolons (not required in Alloy, but watch for parse errors)
- Incorrect HCL syntax

### Viewing Alloy UI (Internal Only)

Alloy has a built-in UI on port 12345 (internal only, no external binding).

**Access via curl (from another container on `obs` network):**
```bash
docker run --rm --network obs alpine/curl:latest \
  curl -s http://alloy:12345
```

**Not recommended for regular use.** Use Grafana for log queries.

### Force Alloy Re-ingestion

**Symptom:** Logs missing after Alloy restart (position state lost).

**Solution:** Alloy uses `tail_from_end = true` by default. To force re-read from beginning:
1. Stop Alloy: `docker compose stop alloy`
2. Edit config: Set `tail_from_end = false` temporarily
3. Restart: `docker compose up -d alloy`
4. Revert config: Set `tail_from_end = true`
5. Restart again: `docker compose up -d --force-recreate alloy`

**Better approach:** Generate new log entries instead of re-ingesting old ones.

## Retention Management

### Loki Retention

**Current retention:** 720h (30 days)

**Check retention in Loki config:**
```bash
grep retention_period infra/logging/loki-config.yml
```

**Verify compactor is running:**
```bash
docker logs infra_observability-loki-1 | grep -i compactor
```

**Expected log lines:**
```
level=info ts=... caller=compactor.go:... msg="compactor started"
level=info ts=... caller=compactor.go:... msg="retention enabled"
```

**Manually trigger compaction (not needed, runs every 10m):**
```bash
# Compaction happens automatically; no manual trigger needed
```

See [70-maintenance.md](70-maintenance.md#retention-policies) for changing retention.

### Prometheus Retention

**Current retention:** 15 days (enforced via CLI flag)

**Verify retention:**
```bash
curl -s http://127.0.0.1:9004/api/v1/status/runtimeinfo | grep -i retention
```

**Change retention:**
1. Edit `infra/logging/docker-compose.observability.yml`
2. Update `--storage.tsdb.retention.time=15d` to desired value
3. Restart Prometheus

**Warning:** Changing retention does **not** retroactively delete data. Old data expires naturally.

## Monitoring Stack Health

### Key Indicators

**All services running:**
```bash
docker compose -f infra/logging/docker-compose.observability.yml ps | grep -c "Up"
# Expected: 6 (alloy, cadvisor, grafana, loki, node_exporter, prometheus)
```

**No restart loops:**
```bash
docker compose ps --format "table {{.Service}}\t{{.Status}}" | grep -i restarting
# Expected: no output
```

**Disk space available:**
```bash
df -h /var/lib/docker
# Ensure >10GB free for log ingestion
```

**Loki ingestion rate (>0 lines/sec):**
```promql
rate(loki_distributor_lines_received_total[5m])
```

**Prometheus scrape success:**
```promql
up == 1
```

### Alerting (Optional)

Prometheus alerting is configured but not enabled by default.

**To enable alerts:**
1. Add `alertmanager` service to compose file
2. Configure `infra/logging/prometheus/alertmanager.yml`
3. Update `prometheus.yml` with Alertmanager endpoint

See [Prometheus Alerting Docs](https://prometheus.io/docs/alerting/latest/overview/) for setup.

## Runbook: Ingestion Failure

**Symptom:** No new logs appearing in Grafana

**Diagnosis:**
1. Check Alloy is running: `docker ps | grep alloy`
2. Check Alloy logs: `docker logs infra_observability-alloy-1 | tail -50`
3. Check Loki is accessible: `curl http://loki:3100/ready` (from container on `obs` network)
4. Verify log files exist: `ls -lh /home/luce/_logs/`

**Common causes:**
- Alloy config syntax error (container won't start)
- Loki disk full (ingestion rejected)
- Log file permissions (Alloy can't read)
- Network partition (Alloy can't reach Loki on `obs` network)

**Fix:**
- Syntax: Validate config, fix errors, restart
- Disk: Free space, restart Loki
- Permissions: `chmod 644 /home/luce/_logs/*.log`
- Network: `docker network inspect obs` (verify Alloy and Loki are connected)

See [50-troubleshooting.md](50-troubleshooting.md#no-logs-in-loki) for detailed steps.

## Runbook: High Memory Usage

**Symptom:** Loki or Prometheus consuming >2GB RAM

**Diagnosis:**
```bash
docker stats --no-stream | grep -E "loki|prometheus"
```

**Common causes:**
- Large query result sets (unbounded queries)
- High ingestion rate (too many logs)
- Retention too long (disk pressure causes memory spikes)

**Fix:**
- Add query limits in Loki config (`max_query_length`, `max_query_lookback`)
- Reduce retention period
- Increase compaction frequency
- Add more memory to host (or reduce other workloads)

See [70-maintenance.md](70-maintenance.md#resource-tuning) for tuning parameters.

## Next Steps

- **Validation:** Run strict validation proofs ([40-validation.md](40-validation.md))
- **Troubleshooting:** See common issues ([50-troubleshooting.md](50-troubleshooting.md))
- **Security:** Review exposure posture ([60-security.md](60-security.md))
- **Maintenance:** Set up retention and backups ([70-maintenance.md](70-maintenance.md))
