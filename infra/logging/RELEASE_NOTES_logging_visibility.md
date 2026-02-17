# Logging Visibility — Release Notes

## What shipped
- Pipeline Health dashboard v2 (provisioned)
  - Adds $log_source drilldown: `label_values(log_source)`
  - Adds E2E marker stat (15m): `sum(count_over_time({log_source="rsyslog_syslog"} |~ "MARKER=" [15m]))`
  - Commit: 3e6292e

- Host + Container Overview dashboard (provisioned)
  - Uses cgroup id selector because `image!=""` was empty on this host:
    - CPU: `topk(10, rate(container_cpu_usage_seconds_total{id=~"/system.slice/docker-.*\\.scope"}[5m]))`
    - Mem: `topk(10, container_memory_working_set_bytes{id=~"/system.slice/docker-.*\\.scope"})`
  - Commit: f0c0570

- Hourly E2E guardrail
  - systemd timer: `logging-e2e-check.timer`
  - Validated PASS: marker present in journald and found in Loki with `{log_source="rsyslog_syslog"}`

## Proof pointers
- Grafana provisioning: `meta.provisioned=true` and `meta.provisionedExternalId` matches JSON filename
- Loki query proofs: Q1..Q4 non-empty, including MARKER= panel query
- Prometheus proofs: node/cadvisor families present and key panels return non-empty results
