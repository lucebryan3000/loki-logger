# Alerts Checklist — Logging Pipeline

> Supplemental notes only. Canonical source: `infra/logging/RUNBOOK.md`.


These alerts are intentionally lightweight. They reference queries already proven in this environment.

## Alert 1 — E2E marker missing (15m)
Trigger if the marker count drops to 0 for 15m.
- LogQL:
  `sum(count_over_time({log_source="rsyslog_syslog"} |~ "MARKER=" [15m]))`
- Condition:
  `== 0`

## Alert 2 — Total ingest appears down (5m)
Trigger if total stream activity drops to 0 for 5m.
- LogQL:
  `sum(count_over_time({log_source=~".+"}[5m]))`
- Condition:
  `== 0`

## Alert 3 — Host telemetry scrape down
Trigger if node/cadvisor targets go down.
- PromQL examples:
  - `min(up{job=~"node.*"}) == 0`
  - `min(up{job=~"cadvisor|docker.*"}) == 0`
