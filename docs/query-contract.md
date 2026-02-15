# Query Contract (Single Source of Truth)

This contract defines canonical query IDs for Sprint-3 health and operations.

Use these IDs across:
- Prometheus rules (`infra/logging/prometheus/rules/*.yml`)
- Grafana dashboard panels (`infra/logging/grafana/dashboards/*.json`)
- Operator/Codex machine checks (Prometheus/Loki/Grafana APIs)

Do not create parallel health semantics outside this contract.

## Canonical Sources

- Prometheus datasource: `Prometheus`
- Loki datasource: `Loki`
- Compose project: `logging`
- Compose file: `infra/logging/docker-compose.observability.yml`

## Prometheus Contract IDs

| Query ID | Source | Expression | Dashboard panel | Alert link |
|---|---|---|---|---|
| `prom_targets_up_count` | Prometheus | `sprint3:targets_up:count` | `prometheus-health.json` -> `Targets Up (count)` | Supports `PrometheusTargetDown` inverse |
| `prom_targets_down_count` | Prometheus | `sprint3:targets_down:count` | API/machine checks | `PrometheusTargetDown`, `TargetDown` |
| `prom_scrape_failure_rate_5m` | Prometheus | `sprint3:prometheus_scrape_failures:rate5m` | `prometheus-health.json` -> `Scrape failures (rate)` | `PrometheusScrapeFailure` |
| `loki_ingestion_error_rate_5m` | Prometheus | `sprint3:loki_ingestion_errors:rate5m` | `prometheus-health.json` -> `Loki ingestion errors (rate)` | Supports `LokiIngestionErrors` |
| `loki_ingestion_error_increase_10m` | Prometheus | `sprint3:loki_ingestion_errors:increase10m` | API/machine checks | `LokiIngestionErrors` |
| `host_cpu_usage_percent` | Prometheus | `sprint3:host_cpu_usage_percent` | `host_overview.json` -> `CPU Usage % (instance)` | `NodeCPUHigh` |
| `host_memory_usage_percent` | Prometheus | `sprint3:host_memory_usage_percent` | `host_overview.json` -> `Memory Usage % (instance)` | `NodeMemoryHigh` |
| `host_disk_usage_percent` | Prometheus | `sprint3:host_disk_usage_percent` | `host_overview.json` -> `Disk Usage % (mountpoint)` | `NodeDiskSpaceLow` |
| `container_cpu_usage_cores_rate_5m` | Prometheus | `sprint3:container_cpu_usage_cores:rate5m` | `containers_overview.json` -> `Top 10 Containers by CPU (rate)` | none |
| `container_memory_workingset_bytes` | Prometheus | `sprint3:container_memory_workingset_bytes` | `containers_overview.json` -> `Top 10 Containers by Memory (working set)` | none |

## Loki Contract IDs

| Query ID | Source | Expression | Dashboard panel | Alert link |
|---|---|---|---|---|
| `loki_log_volume_5m` | Loki | `sum(count_over_time({env=~".+"}[5m]))` | `loki-health.json` -> `Log volume (count_over_time)` | none |
| `alloy_error_logs` | Loki | `{env=~".+"} |= "level=error"` | `alloy-health.json` -> `Alloy Errors (Loki)` | manual triage |
| `nvidia_alert_stream` | Loki | `{log_source="nvidia_telem",telemetry_tier="alerts"}` | `gpu-overview.json` -> `NVIDIA Alerts` | manual triage |
| `nvidia_raw_stream` | Loki | `{log_source="nvidia_telem",telemetry_tier="raw30"}` | `gpu-overview.json` -> `NVIDIA Raw30` | manual triage |

## Native API Checks (for operators and Codex)

Use direct API checks only:

- Grafana health: `GET /api/health`
- Prometheus ready: `GET /-/ready`
- Prometheus targets: `GET /api/v1/targets`
- Prometheus rules: `GET /api/v1/rules`
- Prometheus query: `GET /api/v1/query?query=<expr>`
- Loki ready: `GET /ready` (inside `obs` network or container exec)
- Loki query range: `GET /loki/api/v1/query_range`

## Change Rules

When adding/removing a health signal:

1. Add/update Prometheus recording rule (or Loki query ID).
2. Update this contract table.
3. Point dashboard panel to the canonical query ID/expression.
4. Point alerts to the same recording rules where applicable.
5. Update UAT checks to validate the same contract IDs.
