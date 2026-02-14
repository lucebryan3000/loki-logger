# Maintenance

## Retention Policies

### Loki Retention (Logs)

**Current retention:** 720h (30 days)

**Configuration:** `infra/logging/loki-config.yml`

```yaml
limits_config:
  retention_period: 720h  # 30 days
```

**How retention works:**
- Compactor runs every 10 minutes
- Deletes chunks older than retention period
- Deletion is delayed by 2 hours after compaction

**Change retention:**
1. Edit `infra/logging/loki-config.yml`:
   ```yaml
   limits_config:
     retention_period: 1440h  # 60 days
   ```
2. Restart Loki:
   ```bash
   docker compose -p logging -f infra/logging/docker compose.observability.yml restart loki
   ```

**Verify retention is active:**
```bash
docker logs logging-loki-1 | grep -i retention
```

**Expected output:**
```
level=info msg="retention enabled"
```

**Immediate cleanup (force compaction):**
Compaction runs automatically every 10 minutes. No manual trigger needed.

### Prometheus Retention (Metrics)

**Current retention:** 15 days

**Configuration:** CLI flag in `docker-compose.observability.yml`

```yaml
services:
  prometheus:
    command:
      - "--storage.tsdb.retention.time=15d"
```

**Change retention:**
1. Edit `infra/logging/docker compose -p logging.observability.yml`:
   ```yaml
   command:
     - "--storage.tsdb.retention.time=30d"
   ```
2. Restart Prometheus:
   ```bash
   docker compose -p logging -f infra/logging/docker compose.observability.yml up -d prometheus
   ```

**Verify retention:**
```bash
curl -s http://127.0.0.1:9004/api/v1/status/runtimeinfo | jq '.data.storageRetention'
```

**Critical:** Prometheus retention **cannot** be set in `prometheus.yml`. Must use CLI flag.

## Evidence Rotation

Evidence files accumulate in `temp/evidence/` over time.

**Cleanup old evidence:**
```bash
# Find evidence older than 30 days
find temp/evidence -type d -mtime +30

# Delete evidence older than 30 days
find temp/evidence -type d -mtime +30 -exec rm -rf {} +
```

**Automated cleanup (cron):**
```bash
# Add to crontab
crontab -e

# Run cleanup weekly (Sunday 2am)
0 2 * * 0 find /home/luce/apps/loki-logging/temp/evidence -type d -mtime +30 -exec rm -rf {} + 2>/dev/null
```

**Archive important evidence:**
```bash
# Move to permanent location before cleanup
mkdir -p /home/luce/archives/loki-evidence
mv temp/evidence/loki-20260212T* /home/luce/archives/loki-evidence/
```

## Backup and Restore

### Backup Strategy

**What to back up:**
1. **Config files** (committed to git, no backup needed if version-controlled)
2. **Grafana dashboards** (stored in `grafana-data` volume)
3. **Secrets** (`.env` file, encrypted off-site)

**What NOT to back up:**
- Loki data (30-day retention, ephemeral)
- Prometheus data (15-day retention, ephemeral)

**Rationale:** Logs and metrics are time-series data with short retention. Long-term backup is not needed for local dev stack.

### Backup Grafana Dashboards

```bash
# Create backup directory
mkdir -p /home/luce/backups/grafana/$(date +%Y%m%d)

# Export Grafana volume
docker run --rm \
  -v logging_grafana-data:/data:ro \
  -v /home/luce/backups/grafana/$(date +%Y%m%d):/backup \
  alpine tar czf /backup/grafana-data.tar.gz -C /data .

# Verify backup
ls -lh /home/luce/backups/grafana/$(date +%Y%m%d)/
```

### Restore Grafana Dashboards

```bash
# Stop Grafana
docker compose -p logging -f infra/logging/docker compose.observability.yml stop grafana

# Restore from backup
docker run --rm \
  -v logging_grafana-data:/data \
  -v /home/luce/backups/grafana/20260212:/backup:ro \
  alpine sh -c 'rm -rf /data/* && tar xzf /backup/grafana-data.tar.gz -C /data'

# Start Grafana
docker compose -p logging -f infra/logging/docker compose.observability.yml start grafana
```

### Backup Secrets (.env)

```bash
# Encrypt .env file
gpg --symmetric --cipher-algo AES256 .env

# Move encrypted file to safe location
mv .env.gpg /home/luce/backups/secrets/

# Verify original .env is not committed to git
git check-ignore .env
```

**Restore secrets:**
```bash
# Decrypt
gpg --decrypt /home/luce/backups/secrets/.env.gpg > .env

# Set permissions
chmod 600 .env
```

## Upgrades

### Image Version Upgrades

**Check current versions:**
```bash
docker compose -p logging -f infra/logging/docker compose.observability.yml images
```

**Upgrade process:**
1. **Check release notes:**
   - Grafana: https://github.com/grafana/grafana/releases
   - Loki: https://github.com/grafana/loki/releases
   - Prometheus: https://github.com/prometheus/prometheus/releases
   - Alloy: https://github.com/grafana/alloy/releases

2. **Update compose file:**
   ```yaml
   services:
     grafana:
       image: grafana/grafana:11.2.0  # Updated from 11.1.0
   ```

3. **Pull new images:**
   ```bash
   docker compose -p logging -f infra/logging/docker compose.observability.yml pull
   ```

4. **Recreate containers:**
   ```bash
   docker compose -p logging -f infra/logging/docker compose.observability.yml up -d
   ```

5. **Verify health:**
   ```bash
   ./scripts/prod/mcp/logging_stack_health.sh
   ```

**Rollback if issues:**
```bash
# Revert compose file to old version
git checkout infra/logging/docker compose -p logging.observability.yml

# Redeploy old version
docker compose up -d
```

### Version Compatibility

**Known compatible versions (tested):**
- Grafana 11.x + Loki 3.x
- Prometheus 2.x + Node Exporter 1.x
- Alloy 1.x + Loki 3.x

**Breaking changes to watch:**
- Loki 2.x → 3.x: Schema config changes (requires migration)
- Grafana 10.x → 11.x: Dashboard JSON format changes
- Alloy replaces Promtail (different config syntax)

**Upgrade order (minimize downtime):**
1. Upgrade Grafana (visualizations)
2. Upgrade Prometheus (metrics)
3. Upgrade Loki (logs storage)
4. Upgrade Alloy (log ingestion)

**Reason:** Grafana/Prometheus can tolerate brief Loki downtime. Alloy depends on Loki.

## Disk Space Management

### Monitor Disk Usage

```bash
# Check Docker volumes
docker system df -v | grep logging

# Check volume sizes
docker volume inspect logging_loki-data --format '{{.Mountpoint}}' | xargs du -sh
docker volume inspect logging_prometheus-data --format '{{.Mountpoint}}' | xargs du -sh
docker volume inspect logging_grafana-data --format '{{.Mountpoint}}' | xargs du -sh
```

**Typical sizes:**
- Grafana: 50-100 MB
- Loki: 1-5 GB (30 days logs)
- Prometheus: 500 MB - 2 GB (15 days metrics)

**Alert thresholds:**
- Warning: Loki >5 GB or Prometheus >3 GB
- Critical: Loki >10 GB or Prometheus >5 GB

### Clean Up Disk Space

**Reduce Loki data:**
1. Lower retention: Edit `loki-config.yml` → `retention_period: 360h` (15 days)
2. Restart Loki: `docker compose restart loki`
3. Wait for compaction (runs every 10 min)

**Reduce Prometheus data:**
1. Lower retention: Edit compose file → `--storage.tsdb.retention.time=7d`
2. Restart Prometheus: `docker compose up -d prometheus`

**Emergency cleanup (delete all data):**
```bash
# WARNING: This deletes all logs and metrics
docker compose -p logging -f infra/logging/docker compose.observability.yml down -v

# Redeploy
docker compose up -d
```

### Prune Docker System

```bash
# Remove unused images, containers, networks
docker system prune -a --volumes

# Remove only stopped containers and unused images
docker system prune -a
```

**Warning:** This affects **all Docker resources**, not just observability stack.

## Resource Tuning

### Memory Limits

Add resource limits to prevent runaway memory usage:

```yaml
services:
  loki:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 512M

  prometheus:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
```

**Apply changes:**
```bash
docker compose up -d
```

### Query Limits (Loki)

Prevent expensive queries from consuming resources:

```yaml
# infra/logging/loki-config.yml
limits_config:
  max_query_length: 721h               # Max time range per query
  max_query_lookback: 720h             # Max lookback from now
  max_entries_limit_per_query: 5000    # Max results per query
  max_streams_per_user: 10000          # Max active streams
```

**Restart Loki after changes:**
```bash
docker compose restart loki
```

## Log File Management

### Log File Growth

Alloy monitors file-based logs in:
- `/home/luce/_logs/*.log`
- `/home/luce/_telemetry/*.jsonl`
- `/home/luce/apps/vLLM/_data/mcp-logs/*.log`

**Prevent unbounded growth:**
```bash
# Check log file sizes
du -sh /home/luce/_logs/*
du -sh /home/luce/_telemetry/*

# Truncate large logs (keep last 10k lines)
for log in /home/luce/_logs/*.log; do
  tail -10000 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
done
```

**Automated rotation (logrotate):**
```bash
# Create logrotate config
sudo nano /etc/logrotate.d/luce-logs

# Add:
/home/luce/_logs/*.log {
  daily
  rotate 7
  compress
  missingok
  notifempty
  create 644 luce luce
}
```

## Health Monitoring

### Scheduled Health Checks

```bash
# Add to crontab
crontab -e

# Check health every 5 minutes
*/5 * * * * /home/luce/apps/loki-logging/scripts/prod/mcp/logging_stack_health.sh || echo "Stack health failed at $(date)" >> /home/luce/logs/stack-health.log
```

### Alerting (Optional)

Set up Prometheus Alertmanager for automated alerts:

1. **Add Alertmanager to compose:**
   ```yaml
   services:
     alertmanager:
       image: prom/alertmanager:v0.27.0
       ports:
         - "127.0.0.1:9093:9093"
       volumes:
         - ./prometheus/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
       networks: [obs]
   ```

2. **Configure alert rules** (`prometheus/rules/alerts.yml`)
3. **Update Prometheus config** to point to Alertmanager

See [Prometheus Alerting Docs](https://prometheus.io/docs/alerting/latest/overview/) for setup.

## Maintenance Checklist (Monthly)

- [ ] Check disk usage (`docker system df -v`)
- [ ] Review retention policies (logs/metrics still appropriate?)
- [ ] Backup Grafana dashboards
- [ ] Check for image updates (security patches)
- [ ] Rotate evidence files (delete >30 days)
- [ ] Review Grafana access logs (audit user activity)
- [ ] Test restore procedure (backup is useless if you can't restore)
- [ ] Verify health checks passing
- [ ] Check for container restart loops (`docker compose ps`)

## Troubleshooting Maintenance Tasks

### Compaction Not Running

**Symptom:** Loki data grows beyond retention period

**Diagnosis:**
```bash
docker logs logging-loki-1 | grep -i compactor
```

**Expected:**
```
level=info msg="compactor started"
level=info msg="retention enabled"
```

**If not running:**
- Check `loki-config.yml` → `retention_enabled: true`
- Verify compactor config is valid
- Restart Loki: `docker compose restart loki`

### Prometheus TSDB Corruption

**Symptom:** Prometheus fails to start with "corruption" errors

**Diagnosis:**
```bash
docker logs logging-prometheus-1 | grep -i corrupt
```

**Fix:**
```bash
# Stop Prometheus
docker compose stop prometheus

# Remove corrupted TSDB (loses metrics data)
docker volume rm logging_prometheus-data

# Recreate volume and restart
docker compose up -d prometheus
```

**Prevention:** Ensure adequate disk space before TSDB fills up.

## Next Steps

- Review [operations.md](operations.md) for operational tasks
- See [security.md](security.md) for secrets rotation
- Check [reference.md](reference.md) for configuration options
