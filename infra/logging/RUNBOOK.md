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
- Rule UIDs:
  - `logging-e2e-marker-missing`
  - `logging-total-ingest-down`
- Delivery posture: **rules-only fallback**.
  - Reason: current Grafana provisioning contact point is placeholder (`email receiver` with `<example@email.com>`) and policy points to default receiver; no deterministic real receiver endpoint is evidenced.
  - Action: keep rules provisioned from file; do not provision notifications until a concrete receiver is provided.

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


## Disk-full behavior
If host or container storage approaches full, prioritize preserving Grafana/Loki availability:
- Run `docker system df` and check `_build/logging/dashboard_audit_latest.json` for signal loss.
- Reduce retention only via config files and restart controlled services once.
- Avoid destructive cleanup of `loki-data`/`prometheus-data` volumes unless restoring from backup.


## WAL and retry expectations
Prometheus WAL and Loki retry paths can absorb brief downstream interruptions, but not sustained disk exhaustion.
- During Loki unavailability, expect delayed or dropped writes depending on backpressure.
- Treat `loki_write_dropped_entries_total` and `loki_write_failures_discarded_total` as canonical loss indicators.


## Graceful shutdown procedure
For controlled maintenance:
1. Run hard gates (`dashboard_query_audit.sh`, `verify_grafana_authority.sh`) and capture baseline artifacts.
2. Stop services with non-destructive down flow first (`logging_stack_down.sh` without purge).
3. Restart stack and re-run hard gates before declaring healthy.
