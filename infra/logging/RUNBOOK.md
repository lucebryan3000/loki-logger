# Grafana as Authority — Logging Runbook

## Source of truth
Grafana is the operator surface. Loki is the log store/query engine. Prometheus is the telemetry source for infra signals.

## Architecture
journald -> rsyslog -> Alloy (syslog TCP 1514 localhost) -> Loki -> Grafana

## The authoritative checks (run in order)
1) Readiness
- Loki: `curl -fsS http://127.0.0.1:3200/ready`
- Prom: `curl -fsS http://127.0.0.1:9004/-/healthy`

2) E2E pipeline
- Run: `sudo /usr/local/bin/logging-e2e-check.sh`
- Timer: `systemctl status logging-e2e-check.timer`

3) Grafana confirms visibility
- Provisioned dashboards are the canonical view.
- Provisioned alert rules are the canonical failure signals.

## Proven queries (do not change without proof)
- E2E marker (15m):
  `sum(count_over_time({log_source="rsyslog_syslog"} |~ "MARKER=" [15m]))`
- Total activity (5m):
  `sum(count_over_time({log_source=~".+"}[5m]))`

## Dashboards (provisioned)
- Pipeline Health: `infra/logging/grafana/dashboards/pipeline-health.json`
- Host + Container Overview: `infra/logging/grafana/dashboards/host-container-overview.json`

## Alert posture (authoritative)
- Rules file: `infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml`
- Notification routing file: `infra/logging/grafana/provisioning/alerting/logging-notification-routing.yml`
- Rule UIDs:
  - `logging-e2e-marker-missing`
  - `logging-total-ingest-down`
- Delivery posture: **Grafana-only canonical routing**.
  - Contact point: `logging-ops` (file-provisioned).
  - Prometheus `alertmanagers: []` is intentional in sandbox; alert delivery ownership is Grafana.
  - Rule policy: use explicit `noDataState`/`execErrState` and `A -> B(reduce) -> C(threshold)` structure for all provisioned rules.

## Reduction Pass (R/C/V)
- Reduction objective: keep one canonical operator source and remove doc duplication.
- Consolidation target: move alert criteria into this runbook and avoid parallel checklist drift.
- Validation gates: Loki ready, Prom ready, E2E script PASS, Grafana alert rules API readable.

## Auditability completeness rules
- `Source Index` dashboard must be provisioned: `codeswarm-source-index`.
- Per-source dashboards must match the current `log_source` cardinality.
- Second-dimension dashboards must match chosen dimension values:
  - chosen dimension file: `_build/logging/chosen_dimension.txt`
  - chosen values file: `_build/logging/dimension_values.txt`
  - dimension index UID pattern: `codeswarm-dim-index-<dimension>`
  - per-value UID pattern: `codeswarm-dim-<dimension>-<slug>`

## Expected-empty semantics (deterministic)
- Empty error-signature panels are not failures when they use regex:
  - `(?i)(error|fail|exception|panic)`
- These are classified as `expected_empty_panels` by `dashboard_query_audit.sh`.
- Hard failures are only unexpected empty panels (`empty_panels > 0`) or query errors.

## Adopted dashboards editing policy
Dashboards that are plugin-owned or otherwise non-editable in Grafana UI are adopted into repo provisioning.

- Source of truth: `infra/logging/grafana/dashboards/adopted/`
- Discoverability: Grafana search API with `tag=adopted`
- Edit path: change JSON in repo, then let provisioning reload (or single Grafana restart if needed)
- Guardrail: do not edit/delete plugin-owned originals in place; maintain CodeSwarm copies only


## Adoption policy
Plugin or non-editable dashboards are adopted into infra/logging/grafana/dashboards/adopted with CodeSwarm tags.

## Label contract and expected-empty semantics
Canonical label contract is log_source. Audit failure is only unexpected empty panels; expected-empty panels are tracked but not blocking.

## Noise suppression governance
Noise suppression is allowed only for known-resolved historical flaps that drown active incidents.

- Current suppression class: `atlas_mcp_flap`
- Pipeline location: `infra/logging/alloy-config.alloy` (`loki.process "main"` match+drop block)
- Scope: only the historical module-missing + systemd exit-code spam pattern
- Guardrails:
  - suppress by exact/targeted regex, never broad source-level drops
  - keep a named `noise_class` label on suppression blocks for auditability
  - review every 30 days or when service ownership changes
  - if suppression hides a reintroduced regression, remove suppression first and re-evaluate root cause


## Disk-full behavior
If host or container storage approaches full, prioritize preserving Grafana/Loki availability:
- Run `docker system df` and check `_build/logging/dashboard_audit_latest.json` for signal loss.
- Reduce retention only via config files and restart controlled services once.
- Avoid destructive cleanup of `loki-data`/`prometheus-data` volumes unless restoring from backup.


## WAL and retry expectations

Prometheus WAL and Loki retry paths can absorb brief downstream interruptions, but not sustained disk exhaustion.

### When Loki is unavailable

Alloy buffers writes internally. Depending on backpressure settings, writes may be delayed or dropped.

**Canonical loss indicators (query in Prometheus):**
```promql
loki_write_dropped_entries_total
loki_write_failures_discarded_total
```

**Recovery steps:**
1. Check Loki readiness: `curl -fsS http://127.0.0.1:3200/ready`
2. Check Alloy logs for backpressure errors:
   ```bash
   docker compose -p logging -f infra/logging/docker-compose.observability.yml logs alloy --tail 50 | grep -i "drop\|discard\|backpressure\|fail"
   ```
3. If Loki is down, restart it:
   ```bash
   docker compose -p logging -f infra/logging/docker-compose.observability.yml restart loki
   ```
4. Wait 30 seconds, re-check readiness. If still down, check disk: `docker system df`
5. After Loki recovers, Alloy will resume writes automatically. No manual replay needed.
6. Verify ingestion resumed: query `{log_source=~".+"}` in Grafana Explore for recent entries.

### When Prometheus WAL is degraded

Prometheus WAL lives in the `prometheus-data` volume. It buffers 2 hours of samples by default.

**Symptoms:** Gaps in metrics dashboards, scrape targets showing stale data.

**Recovery steps:**
1. Check Prometheus health: `curl -fsS http://127.0.0.1:9004/-/healthy`
2. Check for WAL corruption in logs:
   ```bash
   docker compose -p logging -f infra/logging/docker-compose.observability.yml logs prometheus --tail 50 | grep -i "wal\|corrupt\|error"
   ```
3. If WAL is corrupted, stop Prometheus, clear WAL directory, and restart:
   ```bash
   docker compose -p logging -f infra/logging/docker-compose.observability.yml stop prometheus
   docker volume inspect logging_prometheus-data  # confirm volume name
   # Only if corruption confirmed — this loses in-flight data:
   docker run --rm -v logging_prometheus-data:/data alpine rm -rf /data/wal
   docker compose -p logging -f infra/logging/docker-compose.observability.yml start prometheus
   ```
4. Prometheus will rebuild WAL from new scrapes. Expect 1-2 scrape cycles before data is visible.

### Disk exhaustion prevention

- Monitor: `df -h /var/lib/docker`
- Alert threshold: 85% full → act before reaching 95%
- Emergency: stop stack, remove old containers/images with `docker system prune`, restart


## Graceful shutdown procedure
For controlled maintenance:
1. Run hard gates (`dashboard_query_audit.sh`, `verify_grafana_authority.sh`) and capture baseline artifacts.
2. Stop services with non-destructive down flow first (`logging_stack_down.sh` without purge).
3. Restart stack and re-run hard gates before declaring healthy.
