# Validation

This document provides **strict validation proofs** to confirm the logging stack is operational and meets the label contract requirements.

## Validation Levels

1. **L1: Service Health** — Services are running and responsive
2. **L2: Data Ingestion** — Logs and metrics are being collected
3. **L3: Query Capability** — Data is queryable with correct labels
4. **L4: Label Contract** — All required labels are present and correct

**Pass criteria:** All L1-L4 checks must pass for stack to be considered fully operational.

## L1: Service Health

### Grafana Health

```bash
curl -sf http://127.0.0.1:9001/api/health
```

**Expected response:**
```json
{
  "commit": "...",
  "database": "ok",
  "version": "11.1.0"
}
```

**Pass criteria:** HTTP 200, `database: "ok"`

### Prometheus Ready

```bash
curl -sf http://127.0.0.1:9004/-/ready
```

**Expected response:**
```
Prometheus Server is Ready.
```

**Pass criteria:** HTTP 200, contains "Ready"

### Prometheus Healthy

```bash
curl -sf http://127.0.0.1:9004/-/healthy
```

**Expected response:**
```
Prometheus Server is Healthy.
```

**Pass criteria:** HTTP 200, contains "Healthy"

### Container Status

```bash
docker compose -f infra/logging/docker-compose.observability.yml ps --format "table {{.Service}}\t{{.Status}}"
```

**Expected output:**
```
SERVICE         STATUS
alloy           Up
docker-metrics  Up (healthy)
grafana         Up
loki            Up
host-monitor    Up
prometheus      Up
```

**Pass criteria:** All services show `Up` status (no `Restarting` or `Exited`)

## L2: Data Ingestion

### Loki Ingestion Rate (PromQL)

Run in Grafana → Explore → Prometheus:

```promql
rate(loki_distributor_lines_received_total[5m])
```

**Expected:** Value > 0 (indicates logs are being ingested)

**Pass criteria:** At least one sample with value > 0 in the last 5 minutes

### Prometheus Targets Up

Run in Grafana → Explore → Prometheus:

```promql
up
```

**Expected output:**
```
up{instance="docker-metrics:8080", job="docker-metrics"} = 1
up{instance="host-monitor:9100", job="host-monitor"} = 1
up{instance="prometheus:9090", job="prometheus"} = 1
```

**Pass criteria:** All `up` metrics = 1 (no targets down)

### Docker Logs Ingested

Run in Grafana → Explore → Loki:

```logql
{env="sandbox", container_name=~".+"} | limit 10
```

**Expected:** 10 log lines from Docker containers

**Pass criteria:** At least 5 log lines returned within last 5 minutes

## L3: Query Capability

### Broad Query (Any Logs)

```logql
{env=~".+"} | limit 10
```

**Expected:** 10 log lines from any source

**Pass criteria:** At least 5 log lines returned

### File-Based Logs (Tool Sink)

First, generate a test log:
```bash
echo "validation_proof_$(date +%s)" >> /home/luce/_logs/test.log
```

Wait 10-15 seconds for ingestion, then query:
```logql
{env="sandbox", filename=~".*_logs.*"} |= "validation_proof_"
```

**Expected:** The test log line appears

**Pass criteria:** At least one match containing `validation_proof_`

### Telemetry Logs

If telemetry is active (external system dependency), query:
```logql
{env="sandbox", filename=~".*_telemetry.*"} |= "telemetry tick"
```

**Expected:** Telemetry heartbeat logs

**Pass criteria:** At least one match (if telemetry source is active)

**Note:** This test may fail if external telemetry system is not running. Not a blocker for stack validation.

### CodeSwarm MCP Logs (Label Contract)

Generate a proof log:
```bash
echo "codeswarm_mcp_proof_$(date +%s)" >> /home/luce/apps/vLLM/_data/mcp-logs/proof.log
```

Wait 10-15 seconds, then query:
```logql
{env="sandbox", log_source="codeswarm_mcp"} |= "codeswarm_mcp_proof_"
```

**Expected:** The proof log with correct label `log_source=codeswarm_mcp`

**Pass criteria:** At least one match with label `log_source="codeswarm_mcp"` visible in Grafana

## L4: Label Contract Validation

### Required Labels Present

For each log entry, verify these labels exist (view in Grafana by expanding a log line):

**All logs must have:**
- `env` (e.g., `sandbox`, `dev`, `prod`)
- `host` (e.g., `codeswarm`)
- `job` (e.g., `dockerlogs`, `tool_sink`, `telemetry`)

**Docker logs must have:**
- `container_name` (e.g., `logging-grafana-1`)
- `image` (e.g., `grafana/grafana:11.1.0`)

**File-based logs must have:**
- `filename` (e.g., `/host/home/luce/_logs/test.log`)

**CodeSwarm MCP logs must have:**
- `log_source` = `codeswarm_mcp`

### Label Uniqueness (No Duplicates)

Run aggregation query to verify label cardinality:

```promql
count by (env, log_source) (loki_ingester_streams)
```

**Expected:** Each unique `(env, log_source)` combination appears once

**Pass criteria:** No unexpected duplicate label combinations

### Empty Selector Rejection

Intentionally run invalid query:
```logql
{}
```

**Expected:** Error message (Loki rejects empty selectors)

**Pass criteria:** Query fails with error (not just returns no results)

## Automated Validation Script

The health check script provides basic L1 validation:

```bash
./scripts/prod/mcp/logging_stack_health.sh
```

**Expected output:**
```
grafana_ok=1
prometheus_ok=1
```

**Exit code:** 0 on success, 1 on failure

## Evidence Generation (Proof Archive)

Generate a full validation proof archive:

```bash
./scripts/prod/prism/evidence.sh
```

**Output location:** `temp/evidence/loki-<timestamp>/`

**Evidence includes:**
- Container status snapshot
- Grafana health JSON
- Prometheus readiness
- Loki query results (with label validation)
- Config file hashes (SHA256)

**Use cases:**
- Audit trail for compliance
- Baseline for regression testing
- Incident response snapshots

## Validation Checklist

Run this checklist after deployment or major changes:

- [ ] L1: Grafana health endpoint returns HTTP 200
- [ ] L1: Prometheus ready endpoint returns HTTP 200
- [ ] L1: All 6 containers show `Up` status
- [ ] L2: Loki ingestion rate > 0 lines/sec
- [ ] L2: All Prometheus targets `up=1`
- [ ] L2: Docker logs queryable in Loki
- [ ] L3: Broad query `{env=~".+"}` returns results
- [ ] L3: File-based logs appear within 15 seconds
- [ ] L3: CodeSwarm MCP logs have `log_source` label
- [ ] L4: All logs have `env`, `host`, `job` labels
- [ ] L4: Empty selector `{}` is rejected

**Full pass:** All items checked

## Common Validation Failures

### No Logs in Loki (L2/L3 Failure)

**Symptom:** Queries return no results despite containers running

**Diagnosis:**
1. Check Alloy logs: `docker logs logging-alloy-1 | grep -i error`
2. Verify log files exist: `ls -lh /home/luce/_logs/`
3. Check Loki reachability: `docker exec logging-alloy-1 curl -s http://loki:3100/ready`

**Fix:** See [troubleshooting.md](troubleshooting.md#no-logs-in-loki)

### Missing Labels (L4 Failure)

**Symptom:** Logs appear but lack expected labels (e.g., `log_source` missing)

**Diagnosis:**
1. Check Alloy config: `grep -A5 "stage.static_labels" infra/logging/alloy-config.alloy`
2. Verify correct pipeline: Ensure logs go through right `loki.process` block

**Fix:**
- Update Alloy config to add missing labels
- Restart Alloy: `docker compose up -d --force-recreate alloy`

### Prometheus Targets Down (L2 Failure)

**Symptom:** `up=0` for one or more targets

**Diagnosis:**
1. Check target container: `docker ps | grep <target>`
2. Test endpoint manually: `curl http://<target>:9100/metrics` (from `obs` network)

**Fix:**
- Restart failed service: `docker compose restart <service>`
- Check network connectivity: `docker network inspect obs`

## Regression Testing

After upgrades or config changes, re-run full validation:

```bash
# 1. Health check
./scripts/prod/mcp/logging_stack_health.sh

# 2. Generate test logs
echo "regression_test_$(date +%s)" >> /home/luce/_logs/test.log

# 3. Wait for ingestion
sleep 15

# 4. Query in Grafana
# {env="sandbox"} |= "regression_test_"

# 5. Generate evidence
./scripts/prod/prism/evidence.sh
```

**Compare evidence archives:** Diff current evidence against baseline to detect regressions.

## Next Steps

After validation passes:
- Review [operations.md](operations.md) for operational runbooks
- Set up [maintenance.md](maintenance.md) retention and backups
- Review [troubleshooting.md](troubleshooting.md) for common issues
