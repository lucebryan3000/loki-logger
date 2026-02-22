# ADR failure re-evaluation and remediation scope

- generated_utc: 2026-02-18T18:11:14Z
- source_run: loki-ops-candidates-20260218T180548Z
- failed_items: 18

## Decision legend
- `remediate_now`: in-scope for next execution tranche
- `defer`: valid issue, but scheduled after critical/runtime blockers
- `n_a`: intentional for sandbox policy or currently non-defective

## Decisions
- `ADR-006-CRIT-UFW-BYPASS` => `remediate_now`
  - observed: `public_grafana_or_prom_ports`
  - rationale: Public Grafana/Prom ports are open; bind loopback or add auth gate.
- `ADR-010-CRIT-GRAFANA-EOL` => `defer`
  - observed: `grafana_11_1_0_present`
  - rationale: Major upgrade wave; execute in dedicated compatibility window.
- `ADR-005-HIGH-NO-ALLOY-PIPELINE-ALERT` => `remediate_now`
  - observed: `alloy_alert_missing`
  - rationale: Add explicit alloy/loki write-drop alert rule.
- `ADR-005-HIGH-NO-ALERT-ROUTING` => `n_a`
  - observed: `routing_files_missing`
  - rationale: Sandbox rules-only posture; delivery routing intentionally not configured.
- `ADR-006-HIGH-PROM-NO-AUTH` => `remediate_now`
  - observed: `prom_web_config_missing`
  - rationale: Prometheus currently public; add loopback bind and/or web auth config.
- `ADR-004-MED-NO-INGEST-LIMITS` => `remediate_now`
  - observed: `ingestion_limits_missing`
  - rationale: Add Loki ingestion rate and burst limits.
- `ADR-005-MED-DUP-TARGETDOWN` => `remediate_now`
  - observed: `targetdown_count=2`
  - rationale: Keep one TargetDown rule, remove duplicate semantics.
- `ADR-005-MED-NO-LOKI-DISK-ALERT` => `remediate_now`
  - observed: `loki_disk_alert_missing`
  - rationale: Add Loki storage pressure alert.
- `ADR-003-MED-REDACTION-DUPLICATED` => `defer`
  - observed: `bearer_redaction_occurrences=8`
  - rationale: Refactor duplicate redaction blocks after correctness fixes.
- `ADR-002-MED-EXPORTER-HEALTHCHECKS` => `defer`
  - observed: `exporter_healthchecks_missing`
  - rationale: Low-risk hardening; add after critical exposure/alert fixes.
- `ADR-008-MED-DASHBOARD-EDITABLE-TRUE` => `n_a`
  - observed: `editable_true`
  - rationale: Operator policy keeps provisioned dashboards editable in this sandbox.
- `ADR-008-MED-SUBDIR-SCAN` => `n_a`
  - observed: `folders_from_structure_missing`
  - rationale: Subdir dashboards currently provisioned and verified; no current defect signal.
- `ADR-009-MED-ALLOY-HOME-MOUNT` => `remediate_now`
  - observed: `alloy_home_mount_present`
  - rationale: Reduce mount scope from /home to /home/luce.
- `ADR-013-MED-DISKFULL-UNDEFINED` => `remediate_now`
  - observed: `diskfull_doc_missing`
  - rationale: Document disk-full behavior and operator actions in RUNBOOK.
- `ADR-013-MED-WAL-RETRY-UNDEFINED` => `remediate_now`
  - observed: `wal_retry_doc_missing`
  - rationale: Document WAL/retry semantics and outage expectations.
- `ADR-013-MED-NO-GRACEFUL-SHUTDOWN-DOC` => `remediate_now`
  - observed: `graceful_shutdown_doc_missing`
  - rationale: Add graceful shutdown procedure to RUNBOOK.
- `ADR-069-HIGH-DEFAULT-EMAIL-NO-SMTP` => `n_a`
  - observed: `smtp_config_missing`
  - rationale: Sandbox has no SMTP target; keep rules-only and document expected behavior.
- `ADR-069-HIGH-NO-CUSTOM-ROUTES` => `n_a`
  - observed: `notification_routes_missing`
  - rationale: Same sandbox routing posture; defer until production notification policy exists.

## Next execution tranche (ordered)
- Precondition complete: expected-empty policy updated for rsyslog forward-error health panel.
- `ADR-006-CRIT-UFW-BYPASS`
- `ADR-005-HIGH-NO-ALLOY-PIPELINE-ALERT`
- `ADR-006-HIGH-PROM-NO-AUTH`
- `ADR-004-MED-NO-INGEST-LIMITS`
- `ADR-005-MED-DUP-TARGETDOWN`
- `ADR-005-MED-NO-LOKI-DISK-ALERT`
- `ADR-009-MED-ALLOY-HOME-MOUNT`
- `ADR-013-MED-DISKFULL-UNDEFINED`
- `ADR-013-MED-WAL-RETRY-UNDEFINED`
- `ADR-013-MED-NO-GRACEFUL-SHUTDOWN-DOC`
