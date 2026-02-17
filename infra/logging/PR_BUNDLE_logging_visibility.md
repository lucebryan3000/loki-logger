# PR Bundle — Logging Visibility

Branch: logging-configuration

## Summary
This PR ships two provisioned Grafana dashboards and a lightweight hourly E2E guardrail to ensure the rsyslog→Alloy→Loki pipeline stays queryable.

## Commits
- 3e6292e — grafana: enhance pipeline health dashboard
- f0c0570 — grafana: add host + container overview dashboard

## Verification
- Loki: /ready OK; MARKER= panel query non-empty (15m)
- Prometheus: /-/healthy OK; node + cadvisor series non-empty
- Grafana: dashboards provisioned (API save blocked), external IDs match JSON
- systemd: logging-e2e-check.timer enabled; service run PASS

## Files
- infra/logging/grafana/dashboards/pipeline-health.json
- infra/logging/grafana/dashboards/host-container-overview.json
- infra/logging/RELEASE_NOTES_logging_visibility.md
