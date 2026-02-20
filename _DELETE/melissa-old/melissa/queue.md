# Melissa Queue — melissa-queue-20260220T022153Z

- total: 28
- continue_on_fail: true

| idx | id | type | status | attempt | target |
|---:|---|---|---|---:|---|
| 1 | FIX:alloy_positions_storage | fix_config | done | 1 | infra/logging/docker-compose.observability.yml |
| 2 | FIX:journald_mounts | fix_config | done | 1 | infra/logging/docker-compose.observability.yml |
| 3 | FIX:grafana_alert_timing | fix_config | done | 1 | infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml |
| 4 | FIX:prom_dead_rules_replace | fix_config | pending | 0 | infra/logging/prometheus/rules/loki_logging_rules.yml |
| 5 | FIX:loki_port_bind_local | fix_runtime | pending | 0 | infra/logging/docker-compose.observability.yml |
| 6 | FIX:grafana_metrics_scrape | fix_config | pending | 0 | infra/logging/prometheus/prometheus.yml |
| 7 | ADD:backup_script | script_add | pending | 0 | infra/logging/scripts/backup_volumes.sh |
| 8 | ADD:restore_script | script_add | pending | 0 | infra/logging/scripts/restore_volumes.sh |
| 9 | FIX:resource_limits_alloy_health | fix_config | pending | 0 | infra/logging/docker-compose.observability.yml |
| 10 | SRC:codeswarm_mcp | dashboard_tune | pending | 0 | infra/logging/grafana/dashboards/sources/codeswarm-src-codeswarm_mcp.json |
| 11 | SRC:codex_tui | dashboard_tune | pending | 0 | infra/logging/grafana/dashboards/sources/codeswarm-src-codex_tui.json |
| 12 | SRC:docker | dashboard_tune | pending | 0 | infra/logging/grafana/dashboards/sources/codeswarm-src-docker.json |
| 13 | SRC:gpu_telemetry | dashboard_tune | pending | 0 | infra/logging/grafana/dashboards/sources/codeswarm-src-gpu_telemetry.json |
| 14 | SRC:rsyslog_syslog | dashboard_tune | pending | 0 | infra/logging/grafana/dashboards/sources/codeswarm-src-rsyslog_syslog.json |
| 15 | SRC:telemetry | dashboard_tune | pending | 0 | infra/logging/grafana/dashboards/sources/codeswarm-src-telemetry.json |
| 16 | SRC:vscode_server | dashboard_tune | pending | 0 | infra/logging/grafana/dashboards/sources/codeswarm-src-vscode_server.json |
| 17 | AUDIT:per_dashboard_breakdown | audit_verify | pending | 0 | infra/logging/scripts/dashboard_query_audit.sh |
| 18 | VERIFY:parity_checks | audit_verify | pending | 0 | infra/logging/scripts/verify_grafana_authority.sh |
| 19 | VERIFY:adoption_checks | audit_verify | pending | 0 | infra/logging/scripts/verify_grafana_authority.sh |
| 20 | DOC:editing_policy | doc_update | pending | 0 | infra/logging/RUNBOOK.md |
| 21 | DOC:adoption_policy | doc_update | pending | 0 | infra/logging/RUNBOOK.md |
| 22 | DOC:label_contract_expected_empty | doc_update | pending | 0 | infra/logging/RUNBOOK.md |
| 23 | VERIFY:loki_binding_local | verify | pending | 0 | infra/logging/docker-compose.observability.yml |
| 24 | VERIFY:prom_rule_metric_live | verify | pending | 0 | infra/logging/prometheus/rules/loki_logging_rules.yml |
| 25 | VERIFY:queue_state_integrity | verify | pending | 0 | _build/melissa/queue.json |
| 26 | VERIFY:endpoint_health_snapshot | verify | pending | 0 | _build/melissa/runtime.log |
| 27 | VERIFY:audit_gate_snapshot | verify | pending | 0 | _build/logging/dashboard_audit_latest.json |
| 28 | VERIFY:verifier_gate_snapshot | verify | pending | 0 | _build/logging/verify_grafana_authority_latest.json |
