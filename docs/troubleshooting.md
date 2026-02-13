# Troubleshooting

This document maps **symptoms → causes → fixes** for common issues with the Loki logging stack.

## Quick Diagnostic Commands

```bash
# Container status
docker compose -f infra/logging/docker-compose.observability.yml ps

# Recent logs (all services)
docker compose -f infra/logging/docker-compose.observability.yml logs --tail 50

# Health checks
curl -sf http://127.0.0.1:9001/api/health || echo "Grafana FAILED"
curl -sf http://127.0.0.1:9004/-/ready || echo "Prometheus FAILED"

# Loki ingestion rate
curl -G http://127.0.0.1:9004/api/v1/query \
  --data-urlencode 'query=rate(loki_distributor_lines_received_total[5m])'
```

## Symptom: No Logs in Loki

### Cause 1: Alloy Not Running

**Diagnosis:**
```bash
docker ps | grep alloy
# If no output, container is not running
```

**Check logs:**
```bash
docker logs logging-alloy-1
```

**Common errors:**
- `error parsing config: ...` — Config syntax error
- `permission denied` — Socket/journal mount permissions

**Fix:**
```bash
# Validate config syntax (use // not # for comments)
grep "^#" infra/logging/alloy-config.alloy
# If any matches, replace with //

# Restart Alloy
docker compose -f infra/logging/docker-compose.observability.yml up -d --force-recreate alloy
```

### Cause 2: Loki Not Reachable

**Diagnosis:**
```bash
# From Alloy container
docker exec logging-alloy-1 curl -s http://loki:3100/ready
```

**Expected:** `ready` (or similar success message)

**If fails:**
- Check Loki is running: `docker ps | grep loki`
- Check network: `docker network inspect obs | grep -E "alloy|loki"`

**Fix:**
```bash
# Restart Loki
docker compose -f infra/logging/docker-compose.observability.yml restart loki

# Verify network membership
docker inspect logging-alloy-1 | grep -A5 Networks
docker inspect logging-loki-1 | grep -A5 Networks
# Both should show "obs" network
```

### Cause 3: Log Files Not Readable

**Diagnosis:**
```bash
# Check file permissions
ls -lh /home/luce/_logs/

# Test read access
sudo -u luce cat /home/luce/_logs/*.log | head -5
```

**If permission denied:** Files must be readable by host user (Alloy mounts as `/host/home/luce`)

**Fix:**
```bash
chmod 644 /home/luce/_logs/*.log
chmod 755 /home/luce/_logs
```

### Cause 4: Ingestion Delay

**Symptom:** Logs appear 30+ seconds after creation

**Normal delay:** 10-15 seconds (Alloy batch interval + Loki ingestion)

**Diagnosis:**
```bash
# Generate test log
echo "test_$(date +%s)" >> /home/luce/_logs/test.log

# Wait 15 seconds
sleep 15

# Query in Grafana
# {env="sandbox", filename=~".*test.log"} |= "test_"
```

**If still no results after 30 seconds:**
- Check Alloy logs: `docker logs logging-alloy-1 --tail 50`
- Check Loki logs: `docker logs logging-loki-1 | grep -i error`

**Fix:**
- Restart Alloy: `docker compose restart alloy`
- If persistent, check disk space: `df -h /var/lib/docker`

## Symptom: Alloy Config Parse Errors

### Cause: Invalid Comment Syntax

**Error message:**
```
error parsing config: unexpected token '#'
```

**Cause:** Alloy uses `//` for line comments, **not** `#` (HCL syntax, not YAML)

**Fix:**
```bash
# Find invalid comments
grep "^#" infra/logging/alloy-config.alloy

# Replace with //
sed -i 's|^#|//|g' infra/logging/alloy-config.alloy

# Restart
docker compose -f infra/logging/docker-compose.observability.yml up -d --force-recreate alloy
```

### Cause: Invalid HCL Syntax

**Error message:**
```
error parsing config: unexpected token at line X
```

**Diagnosis:**
```bash
# Validate config structure
docker run --rm -v $(pwd)/infra/logging/alloy-config.alloy:/etc/alloy/config.alloy:ro \
  grafana/alloy:v1.2.1 \
  fmt --config.file=/etc/alloy/config.alloy
```

**Common mistakes:**
- Missing closing braces `}`
- Incorrect nesting (e.g., `stage.static_labels` outside `loki.process` block)
- Invalid attribute names

**Fix:**
- Compare against [snippets/alloy-config.alloy](snippets/alloy-config.alloy)
- Restore from git: `git checkout infra/logging/alloy-config.alloy`

## Symptom: Empty Loki Query Results

### Cause 1: Empty Selector

**Query:**
```logql
{}
```

**Error:** Query rejected or times out

**Cause:** Loki requires **non-empty label selectors**

**Fix:**
```logql
# Use at least one label
{env=~".+"}

# Or be more specific
{env="sandbox"}
```

### Cause 2: Frozen Query Window

**Symptom:** Query returns results, but refreshing shows same data (not updating)

**Cause:** Grafana time picker is set to absolute time range (e.g., "Last hour" frozen at specific timestamp)

**Diagnosis:**
- Check Grafana time picker (top-right)
- If shows static timestamps (not "Last 5 minutes"), window is frozen

**Fix:**
- Click time picker → Select "Last 5 minutes" (or other relative range)
- OR click refresh icon to update absolute window to current time

### Cause 3: Incorrect Labels

**Query:**
```logql
{env="production"}
```

**Result:** No data (but `{env="sandbox"}` works)

**Cause:** Label value mismatch (all logs have `env=sandbox` in this deployment)

**Diagnosis:**
```bash
# Check Alloy config for label values
grep -A5 "stage.static_labels" infra/logging/alloy-config.alloy
```

**Fix:**
- Use correct label value: `{env="sandbox"}`
- Or update Alloy config to use desired `env` value

### Cause 4: Time Range Too Narrow

**Symptom:** Query returns no results, but logs exist

**Cause:** Grafana time picker set to very short range (e.g., "Last 1 minute") and no logs in that window

**Fix:**
- Expand time range: "Last 15 minutes" or "Last 1 hour"
- Generate new test log and wait 15 seconds before querying

## Symptom: Prometheus Retention Not Applied

### Cause: Config File Ignored

**Symptom:** Changed `retention` in `prometheus.yml`, but data still expires after 15 days

**Cause:** Prometheus retention is **CLI-only** (`--storage.tsdb.retention.time` flag). Config file setting is ignored.

**Diagnosis:**
```bash
# Check current retention
curl -s http://127.0.0.1:9004/api/v1/status/runtimeinfo | grep retention

# Check CLI args
docker inspect logging-prometheus-1 | grep -A10 Args
```

**Fix:**
1. Edit `infra/logging/docker-compose.observability.yml`
2. Update command: `--storage.tsdb.retention.time=30d` (or desired value)
3. Restart: `docker compose up -d prometheus`

**Do NOT edit `prometheus.yml`** — retention setting there has no effect.

## Symptom: Grafana Login Fails

### Cause 1: Wrong Credentials

**Diagnosis:**
```bash
# Check credentials from .env
grep GRAFANA_ADMIN .env
```

**Fix:**
- Use correct username/password from `.env`
- If forgotten, reset password:
  ```bash
  docker exec -it logging-grafana-1 \
    grafana cli admin reset-admin-password <new-password>
  ```

### Cause 2: Grafana Not Running

**Diagnosis:**
```bash
docker ps | grep grafana
curl -sf http://127.0.0.1:9001/api/health
```

**Fix:**
```bash
docker compose -f infra/logging/docker-compose.observability.yml restart grafana
```

## Symptom: High CPU/Memory Usage

### Cause 1: Unbounded Loki Query

**Symptom:** Loki container using >2GB RAM during query

**Diagnosis:**
```bash
docker stats --no-stream | grep loki
```

**Cause:** Large query without limits (e.g., `{env=~".+"}` over 7 days with no `| limit`)

**Fix:**
- Add query limits in Loki config:
  ```yaml
  limits_config:
    max_query_length: 721h  # Max query window
    max_query_lookback: 720h  # Max lookback from now
    max_entries_limit_per_query: 5000
  ```
- Restart Loki: `docker compose restart loki`

### Cause 2: High Ingestion Rate

**Symptom:** Alloy or Loki CPU >50%

**Diagnosis:**
```promql
# Check ingestion rate (lines/sec)
rate(loki_distributor_lines_received_total[5m])
```

**If >1000 lines/sec:** Consider rate limiting or sampling

**Fix:**
- Reduce log verbosity at source (application config)
- Add sampling in Alloy (drop percentage of logs)
- Increase Loki resources (memory, CPU)

## Symptom: Container Restart Loops

### Diagnosis

```bash
# Check restart count
docker compose ps --format "table {{.Service}}\t{{.Status}}"

# View recent logs
docker logs --tail 100 logging-<service>-1
```

**Common restart causes:**
- Config syntax error (container fails to start)
- Out of memory (OOMKilled)
- Crash due to disk full
- Dependency failure (e.g., Grafana restarts if Loki is down)

### Fix by Service

**Alloy:**
- Check config syntax (see [Alloy Config Parse Errors](#symptom-alloy-config-parse-errors))
- Verify socket mount: `ls -l /var/run/docker.sock`

**Loki:**
- Check disk space: `df -h /var/lib/docker`
- Check config: `docker run --rm -v $(pwd)/infra/logging/loki-config.yml:/etc/loki/loki-config.yml:ro grafana/loki:3.0.0 -config.file=/etc/loki/loki-config.yml -verify-config`

**Prometheus:**
- Check config: `curl -X POST http://127.0.0.1:9004/-/reload` (requires `--web.enable-lifecycle`)
- Check disk space (TSDB corruption on full disk)

**Grafana:**
- Check dependencies: Ensure Loki and Prometheus are running
- Check disk space (sqlite DB corruption on full disk)

## Symptom: Loki Query Timeout

### Cause: Large Time Range

**Error message (in Grafana):**
```
Error: context deadline exceeded
```

**Cause:** Query spans too much data (e.g., 30 days without filtering)

**Fix:**
- Narrow time range: Use "Last 1 hour" instead of "Last 30 days"
- Add more specific labels: `{env="sandbox", container_name="loki"}` instead of `{env=~".+"}`
- Add text filter: `{env="sandbox"} |= "error"` (more efficient than broad scan)

### Cause: Loki Resource Limits

**Diagnosis:**
```bash
docker stats --no-stream | grep loki
# If CPU at 100% or memory near limit, Loki is overloaded
```

**Fix:**
- Add resource limits in compose file:
  ```yaml
  services:
    loki:
      deploy:
        resources:
          limits:
            memory: 4G
            cpus: '2.0'
  ```
- Restart: `docker compose up -d loki`

## Symptom: Labels Missing from Logs

### Cause: Wrong Pipeline in Alloy

**Symptom:** CodeSwarm MCP logs don't have `log_source=codeswarm_mcp` label

**Diagnosis:**
```bash
# Check which pipeline processes CodeSwarm logs
grep -A10 "codeswarm_mcp" infra/logging/alloy-config.alloy
```

**Expected:**
```
loki.source.file "codeswarm_mcp" {
  ...
  forward_to = [loki.process.codeswarm.receiver]  # Must go to codeswarm pipeline
}
```

**Fix:**
- Ensure `forward_to` points to correct `loki.process` block
- Verify `loki.process.codeswarm` has correct `stage.static_labels`
- Restart: `docker compose up -d --force-recreate alloy`

## Symptom: Evidence Script Fails

### Cause: Services Not Running

**Error:**
```bash
./scripts/prism/evidence.sh
# curl: (7) Failed to connect to 127.0.0.1:9001
```

**Fix:**
```bash
# Start stack first
./scripts/mcp/logging_stack_up.sh

# Wait 30 seconds for services to initialize
sleep 30

# Retry evidence
./scripts/prism/evidence.sh
```

### Cause: Loki Has No Data

**Symptom:** Evidence script runs but Loki query returns empty

**Diagnosis:**
```bash
# Check if any logs exist
docker exec -it logging-grafana-1 \
  curl -G 'http://loki:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={env=~".+"}' \
  --data-urlencode 'limit=1'
```

**Fix:**
- Generate test logs: `echo "proof_$(date +%s)" >> /home/luce/_logs/test.log`
- Wait 15 seconds: `sleep 15`
- Retry evidence script

## Common Pitfalls

### 1. Alloy Comment Syntax
**Wrong:** `# This is a comment`
**Right:** `// This is a comment`

### 2. Empty Loki Selectors
**Wrong:** `{}`
**Right:** `{env=~".+"}`

### 3. Prometheus Retention Config
**Wrong:** Setting `retention` in `prometheus.yml`
**Right:** Using `--storage.tsdb.retention.time` CLI flag in compose

### 4. Frozen Query Window
**Issue:** Grafana time picker stuck on absolute time
**Fix:** Select relative time range (e.g., "Last 15 minutes")

### 5. Ingestion Delay
**Issue:** Expecting instant log appearance
**Reality:** Allow 10-15 seconds for logs to appear after creation

### 6. Loki Internal-Only
**Issue:** Trying to access Loki at http://127.0.0.1:3100
**Reality:** Loki is **internal-only** (http://loki:3100 from `obs` network)

### 7. Config Changes Not Applied
**Issue:** Editing config but not restarting service
**Fix:** Always restart after config changes:
```bash
docker compose up -d --force-recreate <service>
```

## Escalation Path

If issue persists after troubleshooting:

1. **Collect diagnostic data:**
   ```bash
   # Container status
   docker compose ps > /tmp/compose-ps.txt

   # All logs (last 500 lines)
   docker compose logs --tail 500 > /tmp/compose-logs.txt

   # System resources
   df -h > /tmp/disk.txt
   free -h > /tmp/memory.txt

   # Evidence snapshot
   ./scripts/prism/evidence.sh
   ```

2. **Review logs for errors:**
   ```bash
   grep -i error /tmp/compose-logs.txt
   ```

3. **Check GitHub issues:**
   - Grafana Loki: https://github.com/grafana/loki/issues
   - Grafana Alloy: https://github.com/grafana/alloy/issues
   - Prometheus: https://github.com/prometheus/prometheus/issues

4. **Reset to known-good state:**
   ```bash
   # Stop stack
   docker compose -f infra/logging/docker-compose.observability.yml down

   # Restore configs from git
   git checkout infra/logging/*.yml infra/logging/*.alloy

   # Redeploy
   docker compose -f infra/logging/docker-compose.observability.yml up -d
   ```

## Next Steps

- Review [operations.md](operations.md) for operational runbooks
- See [validation.md](validation.md) for validation proofs
- Check [reference.md](reference.md) for config reference
