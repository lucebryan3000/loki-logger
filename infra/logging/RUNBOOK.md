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
- Provisioned alerts are the canonical failure signals.

## Proven queries (do not change without proof)
- E2E marker (15m):
  `sum(count_over_time({log_source="rsyslog_syslog"} |~ "MARKER=" [15m]))`
- Total activity (5m):
  `sum(count_over_time({log_source=~".+"}[5m]))`

## Dashboards (provisioned)
- Pipeline Health: `infra/logging/grafana/dashboards/pipeline-health.json`
- Host + Container Overview: `infra/logging/grafana/dashboards/host-container-overview.json`

## Alerts (provisioned)
- Rules file: `infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml`
- Rules UIDs:
  - `logging-e2e-marker-missing`
  - `logging-total-ingest-down`

## Reduction Pass (R/C/V)
- Reduction objective: keep one canonical operator source and remove doc duplication.
- Consolidation target: move alert criteria into this runbook and avoid parallel checklist drift.
- Validation gates: Loki ready, Prom ready, E2E script PASS, Grafana alert rules API readable.
