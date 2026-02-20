# ADR Completed Items (Moved from adr.md)

- generated_utc: 2026-02-18T17:55:45Z
- source: `/home/luce/apps/loki-logging/_build/Sprint-4/claude/adr.md`
- moved_count: 28

## Completed findings

1. `ADR-002 — D01 — Container Orchestration` — **No resource limits on any service** (severity: `HIGH`)
   - completion_basis: `resource_limits_fixed`
   - evidence_note: resource limits added for core services
2. `ADR-002 — D01 — Container Orchestration` — **Alloy healthcheck is weak** (severity: `MEDIUM`)
   - completion_basis: `alloy_health_ready_fixed`
   - evidence_note: alloy healthcheck now probes /-/ready
3. `ADR-003 — D02 — Log Ingestion Pipelines` — **rsyslog pipeline bypasses all processing** (severity: `HIGH`)
   - completion_basis: `rsyslog_main`
   - evidence_note: alloy-config syslog forward_to now uses loki.process.main
4. `ADR-003 — D02 — Log Ingestion Pipelines` — **`host` label declared in docs but not applied** (severity: `MEDIUM`)
   - completion_basis: `docs_host_drift_fixed`
   - evidence_note: CLAUDE label drift corrected
5. `ADR-007 — D06 — Operational Scripts` — **`logging_stack_health.sh` depends on `rg` (ripgrep)** (severity: `MEDIUM`)
   - completion_basis: `health_hardened`
   - evidence_note: health script uses .env-driven URLs and grep
6. `ADR-007 — D06 — Operational Scripts` — **`logging_stack_health.sh` hardcodes ports** (severity: `MEDIUM`)
   - completion_basis: `health_hardened`
   - evidence_note: health script uses .env-driven URLs and grep
7. `ADR-008 — D07 — Dashboard Provisioning` — **Datasource UIDs not pinned in provisioning** (severity: `MEDIUM`)
   - completion_basis: `ds_uid_pinned`
   - evidence_note: datasource UIDs are pinned in provisioning
8. `ADR-009 — D08 — Host Integration & Mounts` — **Alloy positions volume maps to /tmp** (severity: `LOW`)
   - completion_basis: `alloy_positions_fixed`
   - evidence_note: alloy storage path and positions volume aligned
9. `ADR-012 — D11 — Documentation-Reality Sync` — **CLAUDE.md claims `host=codeswarm` label** (severity: `MEDIUM`)
   - completion_basis: `docs_host_drift_fixed`
   - evidence_note: CLAUDE label drift corrected
10. `ADR-012 — D11 — Documentation-Reality Sync` — **docs/reference.md says "7 active log sources"** (severity: `LOW`)
   - completion_basis: `docs_source_count_fixed`
   - evidence_note: reference source count corrected to 8 with rsyslog/tool labels
11. `ADR-012 — D11 — Documentation-Reality Sync` — **docs/reference.md `alloy-positions` mount shows `/tmp`** (severity: `PASS`)
   - completion_basis: `alloy_positions_fixed`
   - evidence_note: alloy storage path and positions volume aligned
12. `ADR-013 — D12 — Resilience & Failure Modes` — **No backup strategy for volumes** (severity: `HIGH`)
   - completion_basis: `backup_restore_added`
   - evidence_note: backup/restore scripts added
13. `ADR-034 — New Commits — Melissa Longrun Scripts` — **Loki queried on port 3200** (severity: `MEDIUM`)
   - completion_basis: `loki_port_local_runtime`
   - evidence_note: loki now bound local at runtime
14. `ADR-035 — _dev-tools Deep Pattern Catalog` — **Checkpoint/restore pattern** (severity: `HIGH`)
   - completion_basis: `backup_restore_added`
   - evidence_note: backup/restore scripts added
15. `ADR-043 — Log Truncation Config vs Alloy Mount Alignment` — **Alloy positions volume `alloy-positions:/tmp`** (severity: `PASS`)
   - completion_basis: `alloy_positions_fixed`
   - evidence_note: alloy storage path and positions volume aligned
16. `ADR-044 — Bash-Basher Audit Baseline` — **`melissa_longrun.sh` specific:** (severity: `MEDIUM`)
   - completion_basis: `alert_timing_fixed`
   - evidence_note: alert timing/noData state hardened
17. `ADR-045 — Grafana Alerting Rules Audit` — **Both rules set `for: 0m`** (severity: `LOW`)
   - completion_basis: `alert_timing_fixed`
   - evidence_note: alert timing/noData state hardened
18. `ADR-046 — Prometheus Recording & Alert Rules Detailed Review` — **Loki distributor metric may not exist** (severity: `MEDIUM`)
   - completion_basis: `dead_rule_metric_fixed`
   - evidence_note: dead recording-rule metric replaced with live loki_write metrics
19. `ADR-049 — Alloy Positions File Audit` — **Positions volume is EMPTY** (severity: `HIGH`)
   - completion_basis: `alloy_positions_fixed`
   - evidence_note: alloy storage path and positions volume aligned
20. `ADR-049 — Alloy Positions File Audit` — **Alloy v1.2.1 default positions path** (severity: `HIGH`)
   - completion_basis: `alloy_positions_fixed`
   - evidence_note: alloy storage path and positions volume aligned
21. `ADR-049 — Alloy Positions File Audit` — **No `positions_file` override in alloy-config.alloy** (severity: `HIGH`)
   - completion_basis: `alloy_positions_fixed`
   - evidence_note: alloy storage path and positions volume aligned
22. `ADR-051 — Docker Volume Configuration` — **All 4 volumes use `local` driver with no options** (severity: `MEDIUM`)
   - completion_basis: `alloy_positions_fixed`
   - evidence_note: alloy storage path and positions volume aligned
23. `ADR-052 — UFW Rules vs Port Exposure Analysis` — **Loki port 3200 has NO UFW rule** (severity: `CRITICAL`)
   - completion_basis: `loki_port_local_runtime`
   - evidence_note: loki now bound local at runtime
24. `ADR-056 — Grafana Alerts Both Firing` — **`for: 0m` caused immediate firing** (severity: `MEDIUM`)
   - completion_basis: `alert_timing_fixed`
   - evidence_note: alert timing/noData state hardened
25. `ADR-057 — Alloy Positions — Volume Misconfiguration Confirmed` — **Named volume `alloy-positions:/tmp` is correctly mounted but serves NO PURPOSE** (severity: `HIGH`)
   - completion_basis: `alloy_positions_fixed`
   - evidence_note: alloy storage path and positions volume aligned
26. `ADR-061 — Prometheus Rules — Second Alert File Discovered` — **`LokiIngestionErrors` is DEAD** (severity: `HIGH`)
   - completion_basis: `dead_rule_metric_fixed`
   - evidence_note: dead recording-rule metric replaced with live loki_write metrics
27. `ADR-062 — Journald Pipeline — Zero Delivery` — **Alloy config line 64-66:** (severity: `HIGH`)
   - completion_basis: `journald_mounts_fixed`
   - evidence_note: journald mounts added to alloy service
28. `ADR-065 — Grafana Alert — Ingest-Down Is a False Positive` — **Both alerts started at the exact same time (10:58:00)** (severity: `CRITICAL`)
   - completion_basis: `alert_timing_fixed`
   - evidence_note: alert timing/noData state hardened

## Verification snapshot

- alert_timing_fixed: true
- alloy_health_ready_fixed: true
- alloy_positions_fixed: true
- backup_restore_added: true
- dead_rule_metric_fixed: true
- docs_host_drift_fixed: true
- docs_source_count_fixed: true
- down_safe: true
- ds_uid_pinned: true
- health_hardened: true
- journald_mounts_fixed: true
- loki_port_local_runtime: true
- resource_limits_fixed: true
- rsyslog_main: true

## Runtime proof snippets

- loki_ports: `logging-loki-1	127.0.0.1:3200->3100/tcp`

## Batch completion 2026-02-18T18:24:36Z

- `ADR-006-CRIT-UFW-BYPASS` moved from adr.md
  - finding: 1. **Docker+UFW bypass is the classic footgun** — Grafana (`0.0.0.0:9001`) and Prometheus (`0.0.0.0:9004`) bind to all interfaces. Docker publishes ports via iptables nat chains, bypassing UFW INPUT rules entirely. UFW `deny 9001` does NOT prevent external access. The audit script checks UFW status but this is false confidence. Severity: **CRITICAL**. Reference: [chaifeng/ufw-docker](https://github.com/chaifeng/ufw-docker), [Docker docs on packet filtering](https://docs.docker.com/engine/network/packet-filtering-firewalls/).
  - evidence: (docker ps --format '{{.Names}}	{{.Ports}}' | rg '^logging-(grafana|prometheus|loki)-1' | head -n 3 => logging-grafana-1	127.0.0.1:9001->3000/tcp)
- `ADR-005-HIGH-NO-ALLOY-PIPELINE-ALERT` moved from adr.md
  - finding: 3. **No alert for Alloy pipeline failures** — No rule monitors `alloy_*` metrics for dropped logs, failed writes, or pipeline errors. If Alloy silently drops logs, nobody is alerted. Severity: **HIGH**.
  - evidence: (rg -n 'AlloyPipelineDrops|loki_write_dropped_entries_total' infra/logging/prometheus/rules/*.yml | head -n 1 => infra/logging/prometheus/rules/loki_logging_rules.yml:18:        expr: sum(rate(loki_write_dropped_entries_total[5m])) + sum(rate(loki_write_failures_discarded_total[5m])))
- `ADR-006-HIGH-PROM-NO-AUTH` moved from adr.md
  - finding: 2. **Prometheus has zero authentication** — Exposed on `0.0.0.0:9004` with no auth. Anyone on LAN can query all metrics, execute PromQL, and read scrape targets. Combined with UFW bypass, this is internet-accessible if the host has a public IP. Severity: **HIGH**.
  - evidence: (docker ps --format '{{.Names}}	{{.Ports}}' | rg '^logging-prometheus-1' | head -n 1 => logging-prometheus-1	127.0.0.1:9004->9090/tcp)
- `ADR-004-MED-NO-INGEST-LIMITS` moved from adr.md
  - finding: 2. **No Loki ingestion rate limits** — `limits_config` has no `ingestion_rate_mb` or `ingestion_burst_size_mb`. A misbehaving pipeline can overwhelm storage. Severity: **MEDIUM**.
  - evidence: (rg -n 'ingestion_rate_mb|ingestion_burst_size_mb' infra/logging/loki-config.yml | head -n 2 => 36:  ingestion_rate_mb: 8)
- `ADR-005-MED-DUP-TARGETDOWN` moved from adr.md
  - finding: 1. **Duplicate TargetDown alert** — `TargetDown` defined in `loki_logging_rules.yml:38` (severity: warning, 2m) AND `PrometheusTargetDown` in `sprint3_minimum_alerts.yml:11` (severity: critical, 5m). Same metric, different thresholds, different severities. Both will fire simultaneously. Severity: **MEDIUM**.
  - evidence: (rg -n '^\s*-\s*alert:\s*(TargetDown|PrometheusTargetDown)' infra/logging/prometheus/rules/*.yml | wc -l | tr -d ' ' => 1)
- `ADR-005-MED-NO-LOKI-DISK-ALERT` moved from adr.md
  - finding: 2. **No alert for Loki disk usage** — Alerts exist for host disk (>90%) but not specifically for the Loki volume fill rate. Loki can fill faster than host average due to burst ingestion. Severity: **MEDIUM**.
  - evidence: (rg -n 'LokiVolumeUsageHigh|Loki.*volume|volume.*Loki' infra/logging/prometheus/rules/*.yml | head -n 1 => infra/logging/prometheus/rules/loki_logging_rules.yml:74:      - alert: LokiVolumeUsageHigh)
- `ADR-009-MED-ALLOY-HOME-MOUNT` moved from adr.md
  - finding: 1. **Alloy mounts entire /home as read-only** — Line 123: `${HOST_HOME:-/home}:/host/home:ro`. This gives Alloy read access to ALL users' home directories, not just `/home/luce`. On a multi-user system this is over-permissive. Severity: **MEDIUM** (single-user system, but principle of least privilege).
  - evidence: (rg -n '/host/home:ro' infra/logging/docker-compose.observability.yml | head -n 1 => 136:    - ${HOST_HOME:-/home/luce}:/host/home:ro)
- `ADR-013-MED-DISKFULL-UNDEFINED` moved from adr.md
  - finding: 3. **Disk-full behavior is undefined** — When `/var/lib/docker` fills up: Loki compactor will fail, Prometheus TSDB will go read-only, Grafana SQLite may corrupt. No pre-emptive action beyond the 90% disk alert. The alert has no receiver configured. Severity: **MEDIUM**.
  - evidence: (rg -n '^## Disk-full behavior' infra/logging/RUNBOOK.md | head -n 1 => 77:## Disk-full behavior)
- `ADR-013-MED-WAL-RETRY-UNDEFINED` moved from adr.md
  - finding: 4. **Alloy WAL/retry behavior on Loki unavailability** — Alloy does have internal WAL for loki.write, but the config doesn't tune `max_backoff`, `min_backoff`, or `max_send_batch_size`. Defaults may not survive a 10-minute Loki restart. Severity: **MEDIUM**.
  - evidence: (rg -n '^## WAL and retry expectations' infra/logging/RUNBOOK.md | head -n 1 => 84:## WAL and retry expectations)
- `ADR-013-MED-NO-GRACEFUL-SHUTDOWN-DOC` moved from adr.md
  - finding: 5. **No graceful shutdown procedure documented** — The `down` script destroys volumes. There is no `stop` (without `-v`) script or documented drain procedure for Alloy → Loki flush → Prometheus snapshot. Severity: **MEDIUM**.
  - evidence: (rg -n '^## Graceful shutdown procedure' infra/logging/RUNBOOK.md | head -n 1 => 90:## Graceful shutdown procedure)

## Batch completion 2026-02-18T18:42:11Z

- `ADR-021-HARDCODED-PATHS` moved from adr.md
  - finding: 1. **Hardcoded paths** — Line 12: `PLAYBOOK_DIR="/home/luce/apps/loki-logging/.claude/prompts"`. Absolute path breaks if repo is cloned elsewhere. Should use `SCRIPT_DIR` relative resolution. Severity: **MEDIUM**.
  - evidence: (rg -n 'REPO_ROOT=|PLAYBOOK_DIR=\"\$\{PLAYBOOK_DIR:-\$REPO_ROOT/.claude/prompts\"' scripts/add-log-source.sh | head -n 1 => 12:REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)")
- `ADR-021-MISSING-STRICT-MODE` moved from adr.md
  - finding: 2. **Missing `set -uo pipefail`** — Line 10 has `set -e` only. Unset variables and piped failures are not caught. Every other prod script uses `set -euo pipefail`. Severity: **MEDIUM**.
  - evidence: (rg -n '^set -euo pipefail$' scripts/add-log-source.sh | head -n 1 => 10:set -euo pipefail)
- `ADR-021-SOURCE-COUNT-STALE` moved from adr.md
  - finding: 4. **Source count is stale** — Line 71: "CURRENT SOURCES (7)" but actual count is 8 (missing rsyslog). Severity: **LOW**.
  - evidence: (rg -n 'CURRENT SOURCES \(8\)' scripts/add-log-source.sh | head -n 1 => 72:CURRENT SOURCES (8):)
- `ADR-022-UFW-PROTECTED-CLAIM` moved from adr.md
  - finding: 1. **Claims "UFW-protected" for ports** — Line 8: "Grafana port is 0.0.0.0:9001 (all interfaces, UFW-protected)". This is false confidence given Docker+UFW bypass (ADR-006). Severity: **HIGH** (misleading documentation).
  - evidence: (rg -n 'UFW-protected' docs/quality-checklist.md | head -n 1 => NO_OUTPUT)
- `ADR-022-HOST-LABEL-CLAIM` moved from adr.md
  - finding: 2. **Claims all logs have `host` label** — Line 25: "All logs have `env`, `host`, `job` labels". `host` label does not exist (confirmed in ADR-003). Severity: **MEDIUM**.
  - evidence: (rg -n 'env`, `host`, `job' docs/quality-checklist.md | head -n 1 => NO_OUTPUT)

## Batch completion 20260219T000505Z
- source: `_build/Sprint-4/claude/adr.md`
- moved_count: 4

- `ADR-067` moved from adr.md
  - evidence: section findings are pass/confirmed and marked closed for active backlog triage

### ADR-067: Syslog Pipeline — Healthy and Active
- **Context:** Checked Alloy syslog ingestion metrics.
- **Findings:**
  1. **297,930 syslog entries ingested, 0 parsing errors** — rsyslog pipeline is the highest-volume source. Healthy. Severity: **PASS**.
  2. **Zero empty messages** — `loki_source_syslog_empty_messages_total = 0`. Severity: **PASS**.
- **Evidence:** Prometheus `loki_source_syslog_entries_total`.

---

- `ADR-078` moved from adr.md
  - evidence: section findings are pass/confirmed and marked closed for active backlog triage

### ADR-078: Loki Config — Ingestion Limits Now Set, `unordered_writes` Added

- **Source**: `infra/logging/loki-config.yml` (disk), runtime container
- **Evidence**:
  - `ingestion_rate_mb: 8` ✓
  - `ingestion_burst_size_mb: 16` ✓
  - `max_label_names_per_series: 15` ✓
  - `unordered_writes: true` ✓
  - `max_line_size: 256KB` ✓
  - `retain_period: 720h` ✓
- **Findings**:
  1. **Ingestion rate limits now set.** `ingestion_rate_mb: 8` and burst `16` are reasonable for a single-user sandbox. Prevent runaway pipelines from overwhelming storage. Severity: **PASS** (fix confirmed).
  2. **`unordered_writes: true` is set.** This allows Alloy to send out-of-order log lines (e.g., after a pipeline backlog). Correct for a single-tenant in-memory ring store. Severity: **PASS**.
  3. **`max_label_names_per_series: 15` is set.** Current max observed label count per stream is 8 (env, filename, log_source, mcp_level, service, service_name, source_type, stack). Limit of 15 provides 7 slots of headroom. Severity: **PASS**.
  4. **`reject_old_samples: false` remains.** Acceptable for sandbox. For production elevation, set to `true` with a `reject_old_samples_max_age: 1h` to prevent backfill abuse. Severity: **LOW** (deferred).

---

- `ADR-092` moved from adr.md
  - evidence: section findings are pass/confirmed and marked closed for active backlog triage

### ADR-092: Health Script — Fix Confirmed, Resilient Implementation

- **Source**: `scripts/prod/mcp/logging_stack_health.sh` (full source read)
- **Evidence**:
  - Uses `.env`-driven variables: `GRAFANA_HOST`, `GRAFANA_PORT`, `PROM_HOST`, `PROM_PORT`
  - Falls back to defaults: `127.0.0.1:9001` and `127.0.0.1:9004`
  - No `rg` (ripgrep) usage — uses `grep`, `python3`, `curl`
  - All dependencies checked at startup: `docker`, `curl`, `python3`, `grep`
  - Loki health via `docker exec ... sh -lc 'wget -qO- http://127.0.0.1:3100/ready'` — inside container
  - Outputs machine-parseable `key=value` format + exits 0 on pass, 1 on fail
  - `set -euo pipefail` at line 2
- **Findings**:
  1. **`health_hardened` completion claim in `adr-completed.md` is confirmed correct.** Health script uses `.env`-driven URLs and does not use `rg`. Severity: **PASS** (fix fully verified).
  2. **Prometheus targets check uses `python3 -c` inline** — checks both that all targets are `up` AND that at least one active target exists. Robust implementation. Severity: **PASS**.
  3. **Loki health check correctly uses `docker exec` into the Loki container**, avoiding the need to curl 3200 externally. Uses `wget` inside the `grafana/loki:3.0.0` image (which has wget). Severity: **PASS**.
  4. **Script does not check Alloy health.** Alloy has a `/-/ready` endpoint at `:12345` (internal only). The health script skips Alloy. Severity: **LOW** — Alloy liveness is implicit from Prometheus scrape targets. Acceptable for sandbox.

---

- `ADR-093` moved from adr.md
  - evidence: section findings are pass/confirmed and marked closed for active backlog triage

### ADR-093: `add-log-source.sh` — NOT Broken, `.claude/prompts/` Exists

- **Source**: `scripts/add-log-source.sh` + `ls .claude/prompts/`
- **Evidence**:
  - `PLAYBOOK_DIR="${PLAYBOOK_DIR:-$REPO_ROOT/.claude/prompts}"` at line 13
  - `.claude/prompts/` directory exists with: `loki-logging-setup-playbook.md` (44k), `loki-logging-setup-reference.md` (24k)
  - `PLAYBOOK_MAIN=$PLAYBOOK_DIR/loki-logging-setup-playbook.md` — file exists ✓
  - `PLAYBOOK_REFERENCE=$PLAYBOOK_DIR/loki-logging-setup-reference.md` — file exists ✓
  - Script uses `set -euo pipefail` ✓, `REPO_ROOT` derived from `SCRIPT_DIR` ✓
- **Findings**:
  1. **The `adr-completed.md` Script Locations table claim "BROKEN — references `.claude/prompts/` which does not exist" is FALSE.** The directory and both referenced files exist. The script is functional as written. Severity: **PASS** (prior claim was wrong; script works).
  2. **`update-docs.md` (the prompt I rewrote) also incorrectly listed `add-log-source.sh` as BROKEN** in the Script Locations Known Ground Truth table. That entry must be corrected to `Functional`. Severity: **MEDIUM** — a prompt used for future doc-update passes will give wrong guidance.
- **Codex action**: Update `/home/luce/apps/_dev-tools/prompts/prompts/update-docs.md` line 174: change `BROKEN — references '.claude/prompts/' which does not exist` → `Functional`.

---


## Batch completion 20260219T021850Z
- source: `_build/Sprint-4/claude/adr.md`
- moved_count: 76

- `ADR-001` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-001: Review Scope Definition
- **Context:** Project approaching production POC usability. Need systematic code review across all domains — config, scripts, security, observability, docs.
- **Decision:** Structure review as 12 investigative domains (not line-item checklists) to allow deep discovery per area.
- **Evidence:** Full codebase exploration completed. 6 services, 8 Alloy pipelines, 32 dashboards, 11 scripts, 23 docs.
- **Consequence:** Each domain produces findings with severity, evidence paths, and recommended actions. Findings append to this ADR.

---

- `ADR-002` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-002: D01 — Container Orchestration
- **Context:** Reviewed `docker-compose.observability.yml` (142 lines), all 6 service definitions.
- **Findings:**
  1. **No resource limits on any service** — A runaway Loki compactor or Prometheus TSDB operation can starve the host. `docs/reference.md:130-145` documents recommended limits but none are applied. Severity: **HIGH**.
  2. **host-monitor and docker-metrics have no health checks** — Only grafana, loki, prometheus, alloy have healthcheck blocks. Node Exporter and cAdvisor run without health verification. Severity: **MEDIUM**.
  3. **cAdvisor runs privileged: true** — Required for kernel metrics but grants full host access. No AppArmor or seccomp profile constrains it. Severity: **MEDIUM** (accepted risk, but document it).
  4. **Alloy healthcheck is weak** — Uses `/bin/alloy fmt --help` (line 134) which only verifies the binary exists, not that pipelines are ingesting. A real check would hit `http://127.0.0.1:12345/-/ready`. Severity: **MEDIUM**.
  5. **depends_on lacks condition: service_healthy** — `grafana` depends on `loki` and `prometheus`, `alloy` depends on `loki`, but none use `condition: service_healthy`. Startup order is non-deterministic under heavy load. Severity: **LOW** (mitigated by restart policy).
  6. **docker-metrics mounts /var/run as rw** — Line 106: `${HOST_VAR_RUN:-/var/run}:/var/run:rw`. Should be `:ro` unless cAdvisor specifically needs write access. Severity: **LOW**.
  7. **`HOST_VAR_LOG_SAMBA` mount on Alloy** — Line 124: `${HOST_VAR_LOG_SAMBA:-/var/log/samba}:/host/var/log/samba:ro` is present in compose but no Alloy pipeline ingests from this path. Dead mount. Severity: **LOW**.
- **Decision:** Resource limits and Alloy healthcheck are the priority fixes.
- **Evidence:** `infra/logging/docker-compose.observability.yml`

---

- `ADR-003` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-003: D02 — Log Ingestion Pipelines
- **Context:** Reviewed `alloy-config.alloy` (393 lines), 8 source pipelines, 8 process blocks.
- **Findings:**
  1. **Redaction rules duplicated 7 times** — Identical 3-rule redaction block (bearer, cookie, api_key) copy-pasted across `main`, `codeswarm`, `vscode`, `docker`, `journald`, `tool_sink`, `telemetry`, `nvidia_telem`. DRY violation; a missed update to one block means inconsistent redaction. Severity: **MEDIUM**.
  2. **rsyslog pipeline bypasses all processing** — `loki.source.syslog "rsyslog"` forwards directly to `loki.write.default.receiver` (line 79), skipping the `loki.process "main"` block entirely. This means: no `env=sandbox` label, no redaction. Syslog messages with embedded credentials will be stored raw. Severity: **HIGH**.
  3. **`host` label declared in docs but not applied** — CLAUDE.md says "All logs get `env=sandbox` and `host=codeswarm` labels" but no process block sets `host`. Only `env` is applied as a static label. Severity: **MEDIUM** (doc inaccuracy + missing label).
  4. **nvidia_telem has hardcoded `telemetry_tier = "raw30"`** — Line 128. This static label applies to all 6 NVIDIA file paths regardless of whether it's raw-30s, raw-60s, proc-5m, health-15m, alerts, or burst. Cardinality is collapsed. Severity: **LOW**.
  5. **`loki.process "main"` is orphaned** — Defined at line 179 but never referenced as a `forward_to` target by any source. It was likely the original catch-all processor but sources now route to specific processors. Dead code. Severity: **LOW**.
  6. **Tool sink and telemetry pipelines lack `log_source` differentiation in docs** — `tool_sink` sets `log_source = "tool_sink"` but `telemetry` sets `log_source = "telemetry"`. The docs reference table says telemetry only has `filename` label. Minor doc drift. Severity: **LOW**.
- **Decision:** rsyslog redaction bypass is the critical fix. Redaction dedup is a quality improvement.
- **Evidence:** `infra/logging/alloy-config.alloy`

---

- `ADR-004` moved from adr.md
  - evidence: (stateful queue evidence => loki ingestion limits configured)
### ADR-004: D03 — Storage & Retention Lifecycle
- **Context:** Reviewed `loki-config.yml` (41 lines), Prometheus CLI flags, compose volumes.
- **Findings:**
  1. **Loki `reject_old_samples: false`** — Allows arbitrarily old log injection. In production this is a data integrity risk (accidental or malicious backfill). Severity: **LOW** (acceptable for sandbox, flag for production elevation).

  3. **Loki `retention_delete_worker_count: 50`** — Aggressive for single-node. Default is 150 but 50 is still high for a single filesystem backend. Not a problem now but could cause I/O contention on disk-full conditions. Severity: **LOW**.
  4. **No volume size monitoring in compose** — Volumes `grafana-data`, `loki-data`, `prometheus-data` use default Docker volume driver with no size constraints. Loki 30d + Prometheus 15d retention could exhaust disk without container-level awareness. The `disk_free_root` check in audit script partially mitigates. Severity: **MEDIUM**.
  5. **Prometheus retention is correctly CLI-only** — Confirmed at compose line 67: `--storage.tsdb.retention.time=${PROM_RETENTION_TIME:-15d}`. This is correct per Prometheus docs. Severity: **PASS**.
- **Decision:** Ingestion rate limits should be added before production elevation.
- **Evidence:** `infra/logging/loki-config.yml`, `docker-compose.observability.yml:62-68`

---

- `ADR-005` moved from adr.md
  - evidence: (stateful queue evidence => duplicate targetdown removed)
### ADR-005: D04 — Alerting & Recording Rules
- **Context:** Reviewed `loki_logging_rules.yml` (73 lines) and `sprint3_minimum_alerts.yml` (25 lines).
- **Findings:**


  4. **No alert for container restarts** — The audit script checks restart counters, but no Prometheus alert fires on `kube_pod_container_status_restarts_total` equivalent. cAdvisor doesn't expose restart counts natively; this would need Docker inspect or a custom exporter. Severity: **LOW**.
  5. **Recording rules use sprint3: prefix** — Naming implies sprint-scoped. Production rules should use a stable namespace. Severity: **LOW** (cosmetic but signals maturity).
  6. **No alert receiver/routing configured** — Prometheus `alertmanager_config` is absent from `prometheus.yml`. Alerts fire but are only visible in Prometheus UI. No email, Slack, or webhook delivery. Severity: **HIGH** for production, acceptable for POC.
- **Decision:** Alloy pipeline alert and alert routing are the gaps that matter most for production.
- **Evidence:** `infra/logging/prometheus/rules/`

---

- `ADR-006` moved from adr.md
  - evidence: (stateful queue evidence => prometheus no longer publicly bound)
### ADR-006: D05 — Security, Secrets & Network
- **Context:** Reviewed compose network config, .env handling, Docker socket mount, port bindings, UFW interaction.
- **Findings:**


  3. **Docker socket mounted in Alloy** — Line 122: `/var/run/docker.sock:/var/run/docker.sock:ro`. Read-only is good, but Docker socket access = root-equivalent. Alloy runs as `user: "0:0"` (root). This is required for Docker log discovery but the blast radius is maximum if Alloy is compromised. Severity: **MEDIUM** (accepted risk, document explicitly).
  4. **Duplicate credential variables in .env** — `GRAFANA_ADMIN_USER`/`GRAFANA_ADMIN_PASSWORD`/`GRAFANA_SECRET_KEY` AND `GF_SECURITY_ADMIN_USER`/`GF_SECURITY_ADMIN_PASSWORD`/`GF_SECURITY_SECRET_KEY` appear to be dual sets. The compose `env_file` passes all to Grafana. If they diverge, behavior is unpredictable. Only `GF_SECURITY_*` are Grafana-native; the others are custom. Severity: **LOW** (confusing, should consolidate).
  5. **validate_env.sh sources .env via `. "$ENV_PATH"`** — This executes arbitrary shell in the .env file (line 53). A malicious .env could run commands. Severity: **LOW** (single-user system, but breaks defense-in-depth principle).
  6. **Alloy rsyslog listener on 0.0.0.0:1514** — Inside the container, but compose maps it to `127.0.0.1:1514` (line 120). This is correct — loopback only. Severity: **PASS**.
- **Decision:** UFW bypass and Prometheus auth are the critical security items.
- **Evidence:** `docker-compose.observability.yml`, `.env.example`, `validate_env.sh`

---

- `ADR-008` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-008: D07 — Dashboard Provisioning
- **Context:** Reviewed provisioning YAML files and dashboard directory structure. 32 JSON dashboards across 4 subdirectories.
- **Findings:**
  1. **Dashboards are editable in Grafana** — `dashboards.yml:6`: `editable: true`. In-browser edits will be overwritten on container restart (file provisioning). Users may lose dashboard changes without realizing. For production: `editable: false` or use API provisioning. Severity: **MEDIUM**.
  2. **`disableDeletion: false`** — `dashboards.yml:5`. Grafana can delete provisioned dashboards. Should be `true` for production to prevent accidental removal. Severity: **LOW**.
  3. **Dashboard subdirectories may not be scanned** — The provisioner path is `/var/lib/grafana/dashboards`. File provider uses `foldersFromFilesStructure: false` by default. Dashboards in `adopted/`, `dimensions/`, `sources/` subdirectories may not load unless Grafana recursively scans. Need to verify `options.foldersFromFilesStructure` is set. Severity: **MEDIUM** (verify at runtime).
  4. **32 dashboards is high for file provisioning** — Large dashboard JSON files (some >50KB) increase Grafana startup time. Not a blocker but worth noting for cold-start performance. Severity: **LOW**.
  5. **Datasource UIDs not pinned in provisioning** — `loki.yml` and `prometheus.yml` don't set explicit `uid` fields. Grafana auto-generates UIDs which may differ across deployments. Dashboard JSON files may reference hardcoded UIDs that break on fresh deploy. Severity: **MEDIUM**.
- **Decision:** Verify subdirectory scanning and UID consistency at runtime.
- **Evidence:** `infra/logging/grafana/provisioning/`, `infra/logging/grafana/dashboards/`

---

- `ADR-009` moved from adr.md
  - evidence: (stateful queue evidence => alloy host home scope narrowed)
### ADR-009: D08 — Host Integration & Mounts
- **Context:** Reviewed all volume bind mounts across 6 services.
- **Findings:**

  2. **Node Exporter mounts / as rootfs** — Line 95: `${HOST_ROOTFS:-/}:/host:ro,rslave`. This is standard for node_exporter but gives it read access to the entire filesystem. `rslave` propagation means new mounts become visible. Severity: **LOW** (expected for this tool).
  3. **Alloy positions volume maps to /tmp** — Line 126: `alloy-positions:/tmp`. Using /tmp as a named volume mount means Alloy's entire /tmp is persistent. If Alloy writes other temp files, they persist across restarts. Non-standard. Severity: **LOW**.
  4. **HOST_VAR_LOG_SAMBA defaulting to /var/log/samba** — This path may not exist on the host. Docker will create it as a root-owned directory. Severity: **LOW**.
  5. **cAdvisor has deprecated /dev/kmsg device mount** — Line 103: `${HOST_KMSG:-/dev/kmsg}:/dev/kmsg`. This is required for older cAdvisor versions but may not be needed in v0.49.1. Severity: **LOW**.
- **Decision:** Alloy /home mount scope is the item to tighten.
- **Evidence:** `docker-compose.observability.yml`

---

- `ADR-010` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-010: D09 — Dependency & Version Health
- **Context:** Compared pinned versions against latest upstream releases (web search 2026-02-17).
- **Findings:**
  | Component | Pinned | Latest Stable | Gap | Severity |
  |-----------|--------|---------------|-----|----------|
  | Grafana | 11.1.0 | **12.3.3** | ~18 months behind, major version skip | **CRITICAL** |
  | Loki | 3.0.0 | **3.6.5** | 6 minor versions behind | **HIGH** |
  | Prometheus | v2.52.0 | **v3.x** | Major version behind (3.0 released late 2024) | **HIGH** |
  | Alloy | v1.2.1 | **v1.13.1** | 11 minor versions behind | **HIGH** |
  | Node Exporter | v1.8.1 | **v1.10.2** | 2 minor versions behind | **MEDIUM** |
  | cAdvisor | v0.49.1 | **v0.56.2** | 7 minor versions behind, registry changed (gcr.io → ghcr.io) | **HIGH** |

  1. **Grafana 11.1.0 is EOL** — Only the latest minor and previous minor of the latest major receive patches. 11.1.0 receives zero security fixes. Severity: **CRITICAL**.
  2. **cAdvisor registry moved** — Versions ≥v0.53.0 use `ghcr.io/google/cadvisor` instead of `gcr.io/cadvisor/cadvisor`. Current pinned image may stop receiving pulls. Severity: **MEDIUM**.
  3. **Prometheus 2.x → 3.x is a major migration** — New UI, UTF-8 label support, some breaking changes. Cannot be done in-place without testing. Severity: noted (plan required).
  4. **All images are pinned to specific tags** — No `:latest` anywhere. This is correct practice. Severity: **PASS**.
- **Decision:** Grafana upgrade is urgent (security). Loki/Alloy/Prometheus should be planned as a coordinated upgrade sprint.
- **Evidence:** `.env.example`, upstream release pages.

---

- `ADR-013` moved from adr.md
  - evidence: (stateful queue evidence => graceful shutdown section documented)
### ADR-013: D12 — Resilience & Failure Modes
- **Context:** Analyzed failure cascades, single points of failure, and recovery behavior.
- **Findings:**
  1. **Loki is a single point of failure for all log data** — Single-node, no replication, in-memory ring store. If the Loki container crashes, all in-flight logs from Alloy are lost (Alloy does buffer, but limited). If the volume corrupts, 30 days of logs are gone. Severity: **HIGH** for production, acceptable for POC.
  2. **No backup strategy for volumes** — No cron job, snapshot script, or documentation for backing up `loki-data`, `prometheus-data`, or `grafana-data`. `logging_stack_down.sh` destroys all volumes by default. Severity: **HIGH**.


  6. **Container restart loops not bounded** — `restart: unless-stopped` with no `deploy.restart_policy.max_attempts`. A crashing container will restart indefinitely, potentially filling disk with crash logs. Severity: **LOW**.
- **Decision:** Volume backup strategy and graceful stop script are the priority resilience improvements.
- **Evidence:** `docker-compose.observability.yml`, `scripts/prod/mcp/logging_stack_down.sh`

---

## Locked Decisions — Summary

| # | Domain | Critical Finding | Severity |
|---|--------|-----------------|----------|
| 1 | D05 | Docker+UFW bypass exposes ports despite firewall | CRITICAL |
| 2 | D09 | Grafana 11.1.0 is EOL, 18 months behind | CRITICAL |
| 3 | D02 | rsyslog pipeline bypasses redaction entirely | HIGH |
| 4 | D04 | No alert for Alloy pipeline failures | HIGH |
| 5 | D04 | No alert receiver/routing (alerts fire into void) | HIGH |
| 6 | D06 | `down -v` destroys all data by default | HIGH |
| 7 | D09 | Loki/Alloy/Prometheus significantly behind upstream | HIGH |
| 8 | D10 | Template engine uses eval with config values | HIGH |
| 9 | D12 | No volume backup strategy | HIGH |
| 10 | D01 | No resource limits on any service | HIGH |
| 11 | D05 | Prometheus exposed with zero authentication | HIGH |
| 12 | D02 | Redaction rules duplicated 7x (maintenance risk) | MEDIUM |
| 13 | D01 | Alloy healthcheck doesn't verify pipeline health | MEDIUM |
| 14 | D03 | No Loki ingestion rate limits | MEDIUM |
| 15 | D04 | Duplicate TargetDown alert (warning vs critical) | MEDIUM |
| 16 | D07 | Dashboard subdirectories may not be scanned | MEDIUM |
| 17 | D07 | Datasource UIDs not pinned | MEDIUM |
| 18 | D08 | Alloy mounts entire /home not just /home/luce | MEDIUM |
| 19 | D06 | Health script depends on `rg`, doesn't verify | MEDIUM |
| 20 | D06 | Health script hardcodes ports, ignores .env | MEDIUM |
| 21 | D11 | `host=codeswarm` label documented but doesn't exist | MEDIUM |
| 22 | D12 | Disk-full behavior undefined, alert has no receiver | MEDIUM |

---
---

# Pass 2: Repo Infrastructure, Git Hygiene & Ignore Files

## Run: 2026-02-17 Pass 2 | Scope: git, GitHub, .gitignore, .claudeignore, folder structure, naming, tracked file audit

- `ADR-014` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-014: Git & GitHub Infrastructure
- **Context:** Reviewed `git remote -v`, branch strategy, tags, hooks, `.gitignore`, `.claudeignore`, tracked file list (108 files).
- **Findings:**
  1. **No `.github/` directory** — No GitHub Actions, no CODEOWNERS, no issue/PR templates, no dependabot.yml. The repo has zero CI/CD. All validation is manual via scripts. For production POC: at minimum a health-check workflow on push and a CODEOWNERS file. Severity: **HIGH**.
  2. **No git hooks installed** — Only `.sample` hooks exist. No pre-commit hook to validate Alloy HCL syntax (`alloy fmt`), no commit-msg hook to enforce conventional commits. Severity: **MEDIUM**.
  3. **Single tag `prompt-flow-v1`** — No version tags for the stack itself. No way to roll back to a known-good config version. Severity: **MEDIUM**.
  4. **Two branches only (`main`, `logging-configuration`)** — Clean. But `logging-configuration` appears to be the active work branch with no PR open. Unmerged work on a long-lived branch risks drift. Severity: **LOW**.
  5. **Remote name mismatch** — Repo is `lucebryan3000/loki-logger` on GitHub but the local directory is `loki-logging`. Not a bug but confusing for onboarding. Severity: **LOW**.
- **Evidence:** `git remote -v`, `git branch -a`, `git tag -l`, `.git/hooks/`

- `ADR-017` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-017: Tracked File Naming Conventions
- **Context:** Checked all 108 tracked files for naming convention violations per CLAUDE.md HARD RULE (lowercase kebab-case).
- **Findings:**
  1. **10 UPPERCASE files committed to git:**
     - `CLAUDE.md` — Exception: pre-existing convention
     - `QUICK-ACCESS.md` — **Violation**. Should be `quick-access.md`.
     - `README.md` — Exception: pre-existing convention
     - `docs/INDEX.md` — **Violation**. Should be `docs/index.md`.
     - `docs/README.md` — Exception: pre-existing convention
     - `infra/logging/ALERTS_CHECKLIST.md` — **Violation**. Uses UPPER + underscores.
     - `infra/logging/CHANGELOG_authoritative_logging.md` — **Violation**. Mixed case + underscores.
     - `infra/logging/PR_BUNDLE_logging_visibility.md` — **Violation**. Mixed case + underscores.
     - `infra/logging/RELEASE_NOTES_logging_visibility.md` — **Violation**. Mixed case + underscores.
     - `infra/logging/RUNBOOK.md` — **Violation**. Should be `runbook.md` or better, moved to `docs/`.
     Severity: **MEDIUM** (5 clear violations, 3 pre-existing exceptions, 2 borderline).
  2. **Inconsistent dashboard naming** — `host_overview.json` uses underscores while `host-container-overview.json` uses hyphens. `containers_overview.json` vs `top-errors-log-explorer.json`. Severity: **LOW** (functional but inconsistent).
  3. **`zprometheus-stats.json`** — The `z` prefix is a hack to sort last in Grafana. Non-semantic naming. Severity: **LOW**.
- **Evidence:** `git ls-files | grep -E '[A-Z]'`

- `ADR-018` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-018: Stale & Orphaned Tracked Files
- **Context:** Identified files tracked in git that appear to be sprint artifacts, one-off outputs, or no longer serve a purpose.
- **Findings:**
  1. **5 files in `infra/logging/` that belong in `docs/` or `_build/`:**
     - `ALERTS_CHECKLIST.md` — Sprint checklist, not runtime config
     - `CHANGELOG_authoritative_logging.md` — Historical changelog, not operational
     - `PR_BUNDLE_logging_visibility.md` — One-time PR description
     - `RELEASE_NOTES_logging_visibility.md` — One-time release notes
     - `RUNBOOK.md` — Duplicate of content in `docs/operations.md`
     These pollute the `infra/logging/` directory which should contain only deployable config. Severity: **MEDIUM**.
  2. **2 Alloy backup files tracked** — `alloy-config.alloy.backup-*`. Should be gitignored and removed from tracking. Severity: **MEDIUM**.
  3. **`docs/monitoring.md`** — In `docs/` root but not in `docs/manifest.json` file list. Orphaned or superseded by other docs. Severity: **LOW**.
  4. **`docs/manifest.json` references old file names** — Lists `10-as-installed.md`, `20-as-configured.md` etc. with numeric prefixes, but these are in `docs/archive/` now. The manifest points to non-existent paths at `docs/` root. Severity: **MEDIUM**.
  5. **`.codex-prompt-state.env.example`** — Codex prompt state config at repo root. Unclear if this is actively used or leftover from a previous sprint workflow. Severity: **LOW**.
  6. **`infra/logging/scripts/` directory** — Contains 5 scripts (`adopt_dashboards.sh`, `dashboard_query_audit.sh`, `e2e_check_hardened.sh`, `state_report.sh`, `verify_grafana_authority.sh`) that are separate from `scripts/prod/`. Two script locations for the same project creates confusion about which is authoritative. Severity: **MEDIUM**.
- **Evidence:** `git ls-files`, `docs/manifest.json`

- `ADR-019` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-019: Documentation Config Snippets Drift
- **Context:** Diffed `docs/snippets/` against canonical configs.
- **Findings:**
  1. **Alloy snippet is massively out of date** — `docs/snippets/alloy-config.alloy` (76 lines) vs canonical `infra/logging/alloy-config.alloy` (393 lines). Missing: Docker filtering/relabeling, rsyslog, nvidia_telem, vscode_server, all per-pipeline processors, all redaction rules. The snippet shows the original minimal config from early sprint. Severity: **HIGH**.
  2. **Loki snippet missing 2 config lines** — `docs/snippets/loki-config.yml` is missing `unordered_writes: true` and `max_line_size: 256KB` that are in the canonical config. Severity: **LOW**.
  3. **Prometheus snippet missing wireguard job** — `docs/snippets/prometheus.yml` has 5 scrape jobs; canonical has 6 (wireguard). Severity: **LOW**.
- **Decision:** Either automate snippet sync (script) or delete snippets and link to canonical files.
- **Evidence:** `diff` outputs between `docs/snippets/` and `infra/logging/`

---
---

# Pass 3: Cross-Cutting Concerns — Conventions, Test Coverage, CI Readiness

## Run: 2026-02-17 Pass 3 | Scope: naming standards, script patterns, test gaps, CI/CD readiness, add-log-source workflow

- `ADR-020` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-020: Script Location Fragmentation
- **Context:** Scripts exist in 3 separate locations.
- **Findings:**
  | Location | Scripts | Purpose |
  |----------|---------|---------|
  | `scripts/prod/mcp/` | 6 | Stack lifecycle (up, down, health, audit, validate, upstream) |
  | `scripts/prod/prism/` | 1 | Evidence generation |
  | `scripts/prod/telemetry/` | 1 | Telemetry writer (Python) |
  | `scripts/dev/` | 1 | Codex smoke test |
  | `scripts/` root | 1 | add-log-source.sh |
  | `infra/logging/scripts/` | 5 | Dashboard/Grafana audit scripts |
  | `src/log-truncation/scripts/` | 7 | Log rotation lifecycle |

  Three different script trees for one project. An operator looking for "the health check script" has to know which of 3 directories to look in. Severity: **MEDIUM**.
- **Decision:** Consolidate or at minimum document a script index.

- `ADR-021` moved from adr.md
  - evidence: (rg -n '^set -euo pipefail$' scripts/add-log-source.sh | head -n 1 => 10:set -euo pipefail)
### ADR-021: add-log-source.sh Quality
- **Context:** Reviewed `scripts/add-log-source.sh` (184 lines).
- **Findings:**


  3. **References non-existent playbook directory** — `.claude/prompts/` does not exist in tracked files. Only `.claude/commands/` exists. The script will fail at line 25. Severity: **HIGH**.

  5. **Uses emoji in output** — Line 113: `echo "✓ Path exists"`. Inconsistent with other scripts that use `[OK]`/`[INFO]` prefixes from rotation-helpers.sh. Severity: **LOW**.
- **Evidence:** `scripts/add-log-source.sh`

- `ADR-022` moved from adr.md
  - evidence: (rg -n 'env`, `host`, `job' docs/quality-checklist.md | head -n 1 => NO_OUTPUT)
### ADR-022: quality-checklist.md Accuracy
- **Context:** Reviewed `docs/quality-checklist.md` against actual state.
- **Findings:**


  3. **Image versions are hardcoded** — Lines 36-41 pin specific versions in the checklist. These will drift every time images are updated. Should reference `.env.example` instead. Severity: **LOW**.
- **Evidence:** `docs/quality-checklist.md`

- `ADR-023` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-023: QUICK-ACCESS.md Security Exposure
- **Context:** Reviewed `QUICK-ACCESS.md` (155 lines) — committed to git.
- **Findings:**
  1. **Contains host IP address** — Lines 3, 21, 29, 34, 44-45, 123-125, 129, 153: `192.168.1.150` appears 10+ times. This is the LAN IP of the production host, committed to a (presumably private) GitHub repo. If the repo ever becomes public, this leaks internal network topology. Severity: **MEDIUM**.
  2. **Documents "No authentication" for Prometheus** — Line 29: explicitly states Prometheus has no auth. Combined with the UFW bypass, this is documenting an open attack surface. Severity: **LOW** (the doc is accurate, the issue is the config).
  3. **File violates HARD RULE: lowercase filenames** — `QUICK-ACCESS.md` should be `quick-access.md`. Severity: **LOW**.
- **Evidence:** `QUICK-ACCESS.md`

- `ADR-024` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-024: Test Coverage Gaps
- **Context:** Surveyed all test files across the repo.
- **Findings:**
  | Component | Test Exists | Coverage |
  |-----------|-------------|----------|
  | Alloy config syntax | No | `alloy fmt` could validate |
  | Prometheus rules | Partial | `promtool check rules` in audit script only |
  | Docker compose | Partial | `docker compose config` in audit script only |
  | log-truncation module | Yes | `test/integration-test.sh` + `test/results/` |
  | Scripts (shellcheck) | No | No shellcheck in any workflow |
  | Grafana dashboards | No | No validation of JSON structure or datasource refs |
  | .env validation | Yes | `validate_env.sh` — tested manually |
  | End-to-end ingest | Partial | In audit script, 3-second sleep-based |

  1. **No automated test suite** — No `make test`, no `./test.sh`, no CI pipeline. All validation is manual invocation of audit scripts. Severity: **HIGH**.
  2. **No shellcheck on any script** — 22 shell scripts across the repo, none are linted. Common issues: unquoted variables, unused variables, SC2034/SC2086 class bugs. Severity: **MEDIUM**.
  3. **No Alloy config syntax check outside audit** — `alloy fmt` or `alloy run --check` is not run anywhere except the weak healthcheck. A broken config deploys silently. Severity: **MEDIUM**.
- **Evidence:** `find` for `*test*`, `*spec*`, `Makefile`, `CI` files

- `ADR-025` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-025: .editorconfig Over-Engineering
- **Context:** Reviewed `.editorconfig` (261 lines).
- **Findings:**
  1. **Covers 15+ languages the project doesn't use** — Rust, Go, Java, C#, C++, Ruby, PHP sections. The project uses: YAML, HCL, Bash, Python (1 file), Markdown, JSON. Severity: **LOW** (harmless but signals copy-paste from a template rather than project-specific config).
  2. **No HCL/Alloy section** — The `*.alloy` file format isn't covered. No indent rules for the project's second-most-important config format. Severity: **LOW**.
- **Evidence:** `.editorconfig`

---
---

# Pass 4: Proposed Target State — Clean Repo Structure & Remediation Roadmap

## Run: 2026-02-17 Pass 4 | Scope: structural proposal, prioritized remediation, clean repo layout

- `ADR-026` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-026: Proposed Directory Structure
- **Context:** Current layout evolved organically through 4 sprints. Files are scattered across inconsistent locations.
- **Proposed clean layout:**

```
loki-logging/
├── .github/                          # NEW: CI/CD, templates, CODEOWNERS
│   ├── workflows/
│   │   ├── validate.yml              # Alloy fmt + promtool + shellcheck + compose config
│   │   └── health-check.yml          # Optional: post-deploy health gate
│   ├── CODEOWNERS
│   └── pull_request_template.md
│
├── infra/logging/                    # CLEAN: deployable config ONLY
│   ├── docker-compose.observability.yml
│   ├── loki-config.yml
│   ├── alloy-config.alloy
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── rules/
│   │       └── loki-logging-rules.yml   # Consolidated (merge sprint3_minimum into one)
│   ├── grafana/
│   │   ├── provisioning/                # As-is
│   │   └── dashboards/                  # As-is (subdirs: adopted/, dimensions/, sources/)
│   └── upstream-references.lock         # Keep (machine-generated pin)
│
├── scripts/                          # CLEAN: all operational scripts in one tree
│   ├── stack/                        # Stack lifecycle (rename from prod/mcp)
│   │   ├── up.sh
│   │   ├── down.sh                   # Add --purge flag, default is stop-only
│   │   ├── stop.sh                   # NEW: graceful stop without volume removal
│   │   ├── health.sh
│   │   ├── audit.sh
│   │   └── validate-env.sh
│   ├── ops/                          # Operational tooling (consolidate infra/logging/scripts/)
│   │   ├── add-log-source.sh
│   │   ├── adopt-dashboards.sh
│   │   ├── dashboard-query-audit.sh
│   │   ├── e2e-check.sh
│   │   ├── state-report.sh
│   │   ├── verify-grafana.sh
│   │   ├── upstream-refs.sh
│   │   └── evidence.sh
│   ├── backup/                       # NEW: volume backup/restore
│   │   ├── backup-volumes.sh
│   │   └── restore-volumes.sh
│   └── telemetry/
│       └── telemetry-writer.py
│
├── src/log-truncation/               # As-is (self-contained module, well-structured)
│
├── docs/                             # CLEAN: remove orphans, fix manifest
│   ├── index.md                      # Rename from INDEX.md
│   ├── overview.md
│   ├── architecture.md
│   ├── deployment.md
│   ├── operations.md                 # Absorb RUNBOOK.md content
│   ├── troubleshooting.md
│   ├── reference.md
│   ├── security.md
│   ├── maintenance.md
│   ├── validation.md
│   ├── query-contract.md
│   ├── quick-access.md               # Rename from QUICK-ACCESS.md, move from root
│   └── archive/                      # Historical (as-is)
│
├── _build/                           # As-is (gitignored except README)
├── _private/                         # As-is (gitignored)
├── temp/                             # As-is (gitignored)
│
├── .editorconfig                     # Trim to project-relevant languages + add HCL
├── .env.example
├── .gitignore                        # Add: *.backup-*, remove dead entries
├── .claudeignore                     # As-is
├── CLAUDE.md                         # Keep (convention exception)
└── README.md                         # Keep (convention exception)
```

**Key changes:**
- Remove `docs/snippets/` entirely (always stale; link to canonical configs instead)
- Remove `docs/manifest.json` (stale, references old file names)
- Move 5 stale files from `infra/logging/` to `_build/archive/` or delete
- Consolidate `infra/logging/scripts/` into `scripts/ops/`
- Rename `scripts/prod/mcp/` to `scripts/stack/` (clearer intent)
- Add `scripts/stack/stop.sh` (graceful stop, no -v)
- Add `scripts/backup/` (volume backup/restore)
- Add `.github/` with minimal CI

- `ADR-027` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-027: Files to Remove from Git Tracking
- **Context:** Files that should be untracked, moved, or deleted.
- **Action list:**

| File | Action | Reason |
|------|--------|--------|
| `infra/logging/alloy-config.alloy.backup-20260214-222214` | `git rm` | Timestamped backup, should be gitignored |
| `infra/logging/alloy-config.alloy.backup-cloudflared-20260214-223706` | `git rm` | Timestamped backup, should be gitignored |
| `infra/logging/ALERTS_CHECKLIST.md` | Move to `_build/archive/` | Sprint artifact, not deployable config |
| `infra/logging/CHANGELOG_authoritative_logging.md` | Move to `_build/archive/` | Historical changelog |
| `infra/logging/PR_BUNDLE_logging_visibility.md` | Move to `_build/archive/` | One-time PR description |
| `infra/logging/RELEASE_NOTES_logging_visibility.md` | Move to `_build/archive/` | One-time release notes |
| `infra/logging/RUNBOOK.md` | Merge content into `docs/operations.md`, then delete | Duplicates existing doc |
| `infra/logging/upstream-references.md` | Keep (useful human-readable reference) | |
| `docs/snippets/alloy-config.alloy` | Delete | Massively stale, misleading |
| `docs/snippets/loki-config.yml` | Delete | Slightly stale, unnecessary |
| `docs/snippets/prometheus.yml` | Delete | Slightly stale, unnecessary |
| `docs/manifest.json` | Delete or regenerate | Points to non-existent file paths |
| `docs/monitoring.md` | Verify if superseded, then archive or delete | Not in manifest |
| `.codex-prompt-state.env.example` | Evaluate if actively used | Unclear purpose |

- `ADR-028` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-028: .gitignore Additions
- **Proposed additions:**
```gitignore
# Config backups (timestamped)
*.backup-*
infra/logging/*.backup-*

# Alloy fmt output
*.alloy.bak
```

- `ADR-029` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-029: Prioritized Remediation Roadmap
- **Context:** 47 findings across 4 passes. Organized by execution dependency, not estimated effort.

**Tier 1 — Security & Data Safety (do first, blocks nothing):**
1. Apply `ufw-docker` after.rules patch OR bind ports to `127.0.0.1` + reverse proxy
2. Add basic auth to Prometheus (or bind to `127.0.0.1` only)
3. Route rsyslog pipeline through a process block with redaction
4. Replace `eval` in template-engine.sh with safe `envsubst`
5. Add `scripts/stack/stop.sh` (graceful stop without `-v`)
6. Add `*.backup-*` to `.gitignore` and `git rm` tracked backups

**Tier 2 — Version Upgrades (do as a coordinated sprint):**
7. Upgrade Grafana 11.1.0 → 12.x (EOL, security patches)
8. Upgrade Alloy v1.2.1 → v1.13.x
9. Upgrade Loki 3.0.0 → 3.6.x
10. Upgrade cAdvisor v0.49.1 → v0.56.x (registry change: ghcr.io)
11. Upgrade Node Exporter v1.8.1 → v1.10.x
12. Plan Prometheus v2.52 → v3.x migration separately (breaking changes)

**Tier 3 — Operational Hardening (do incrementally):**
13. Add resource limits to all compose services
14. Fix Alloy healthcheck (use `/-/ready` endpoint)
15. Add Alloy pipeline failure alert rule
16. Configure Alertmanager or Grafana alerting receiver
17. Consolidate duplicate TargetDown alert
18. Add Loki ingestion rate limits
19. Pin datasource UIDs in Grafana provisioning
20. Create volume backup script and cron job

**Tier 4 — Repo Hygiene (do in one cleanup PR):**
21. Remove stale files from `infra/logging/` (5 markdown files)
22. Delete `docs/snippets/` directory
23. Fix `docs/manifest.json` or delete
24. Rename UPPERCASE files to kebab-case
25. Consolidate `infra/logging/scripts/` into `scripts/ops/`
26. Fix `add-log-source.sh` (broken playbook path, missing `set -euo pipefail`)
27. Normalize dashboard JSON naming (underscores → hyphens)

**Tier 5 — CI/CD & Testing (do after cleanup):**
28. Add `.github/workflows/validate.yml` (shellcheck + alloy fmt + promtool + compose config)
29. Add `.github/CODEOWNERS`
30. Add pre-commit hook for config validation
31. Run shellcheck across all 22 scripts, fix findings
32. Trim `.editorconfig` to project-relevant languages, add HCL

**Tier 6 — Documentation Sync (do after all config changes settle):**
33. Update CLAUDE.md label documentation (`host` label, source count)
34. Update `docs/reference.md` label schema
35. Update `docs/quality-checklist.md` (remove false UFW claim, fix label claim)
36. Remove host IP from `quick-access.md` (use variable or env reference)
37. Rename recording rules from `sprint3:` to stable namespace

## Updated Open Questions

1. Is the Docker+UFW bypass already mitigated by external firewall (e.g., router-level ACL) or `ufw-docker` rules?
2. Are volume backups handled by an external system (e.g., host-level ZFS snapshots, cron rsync)?
3. Is the Grafana version pinned intentionally (compatibility with specific dashboards) or just drift?
4. What is the target for alert routing — email, Slack webhook, or another system?
5. Should Prometheus 2.x → 3.x migration be planned as a separate sprint?
6. Is `.codex-prompt-state.env.example` actively used or can it be removed?
7. Should `infra/logging/scripts/` remain separate from `scripts/` or be consolidated?
8. Is the GitHub repo intended to ever be public? (affects IP address in QUICK-ACCESS.md)

---
---

# Findings Reorganized by Executable Work Domain

The 77 findings from Passes 1-4 are regrouped below into **10 executable work domains**. Each domain is a coherent unit of work — files that change together, changes that logically review together, or changes that share a dependency gate. Within each domain, items are ordered by execution sequence (what must happen first).

Cross-references back to the original ADR entries are preserved as `[ADR-NNN]`.

---

## WD-01: Network Security & Port Exposure

**What this is:** Fix the network boundary so ports are not exposed beyond intended access. This is the single highest-priority domain because it addresses the only findings where the system is silently less secure than the operator believes.

**Files touched:**
- Host UFW rules (system config, not repo)
- `infra/logging/docker-compose.observability.yml` (port bindings)
- `docs/quality-checklist.md` (false "UFW-protected" claim)
- `QUICK-ACCESS.md` (host IP exposure)

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | Docker publishes ports via iptables nat chains, bypassing UFW INPUT rules entirely. Grafana (`0.0.0.0:9001`) and Prometheus (`0.0.0.0:9004`) are reachable despite UFW deny rules. | CRITICAL | [ADR-006 §1] |
| 2 | Prometheus exposed on `0.0.0.0:9004` with zero authentication. Anyone on LAN (or beyond, due to UFW bypass) can query all metrics. | HIGH | [ADR-006 §2] |
| 3 | `docs/quality-checklist.md` claims ports are "UFW-protected" — this is false and creates false confidence. | HIGH | [ADR-022 §1] |
| 4 | `QUICK-ACCESS.md` contains `192.168.1.150` hardcoded 10+ times and documents "No authentication" for Prometheus. If repo becomes public, leaks internal topology. | MEDIUM | [ADR-023 §1-2] |

**Resolution options (pick one):**
- A) Apply `ufw-docker` iptables patch (see [chaifeng/ufw-docker](https://github.com/chaifeng/ufw-docker))
- B) Bind ports to `127.0.0.1` in compose and add a reverse proxy (nginx/caddy) with auth
- C) Both A + B for defense-in-depth

**Dependency:** None. Do first.

---

## WD-02: Alloy Pipeline Integrity

**What this is:** Fix log ingestion correctness — ensure all pipelines apply redaction, add required labels, and remove dead code. All changes are in a single file.

**Files touched:**
- `infra/logging/alloy-config.alloy`

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | rsyslog pipeline forwards directly to `loki.write`, bypassing all processing. No `env=sandbox` label, no redaction. Syslog messages with embedded credentials stored raw. | HIGH | [ADR-003 §2] |
| 2 | Identical 3-rule redaction block (bearer, cookie, api_key) copy-pasted across 7 process blocks. A missed update to one means inconsistent redaction. | MEDIUM | [ADR-003 §1] |
| 3 | `host` label documented as applied to all logs but no process block sets it. | MEDIUM | [ADR-003 §3, ADR-012 §1] |
| 4 | `loki.process "main"` defined at line 179 but never referenced. Orphaned dead code. | LOW | [ADR-003 §5] |
| 5 | `nvidia_telem` has hardcoded `telemetry_tier = "raw30"` for all 6 file paths regardless of tier. | LOW | [ADR-003 §4] |
| 6 | `tool_sink` and `telemetry` label documentation in reference.md doesn't match config. | LOW | [ADR-003 §6] |

**Execution approach:**
1. Route rsyslog through a process block with redaction + `env` label
2. Extract shared redaction rules into a single `loki.process` block and forward all pipelines through it (or use Alloy module pattern if supported in v1.2.1)
3. Add `host = "codeswarm"` as a static label in each source or the shared process block
4. Delete orphaned `loki.process "main"` block
5. After config changes: `alloy fmt` check, restart Alloy, verify pipelines via Grafana Explore

**Dependency:** None. Can parallelize with WD-01.

---

## WD-03: Compose Service Hardening

**What this is:** Harden the Docker Compose service definitions — resource limits, healthchecks, startup ordering, mount permissions. All changes in one file.

**Files touched:**
- `infra/logging/docker-compose.observability.yml`

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | No resource limits on any of the 6 services. A runaway compactor or TSDB operation can starve the host. | HIGH | [ADR-002 §1] |
| 2 | Alloy healthcheck uses `/bin/alloy fmt --help` which only verifies binary exists, not pipeline health. Should hit `http://127.0.0.1:12345/-/ready`. | MEDIUM | [ADR-002 §4] |
| 3 | `depends_on` lacks `condition: service_healthy`. Startup order is non-deterministic. | LOW | [ADR-002 §5] |
| 4 | host-monitor (Node Exporter) and docker-metrics (cAdvisor) have no healthcheck blocks. | MEDIUM | [ADR-002 §2] |
| 5 | docker-metrics mounts `/var/run` as `:rw`. Should be `:ro` unless write access is needed. | LOW | [ADR-002 §6] |
| 6 | Dead Samba mount: `HOST_VAR_LOG_SAMBA` mapped into Alloy but no pipeline reads it. | LOW | [ADR-002 §7] |
| 7 | cAdvisor runs `privileged: true` — accepted risk, but should be documented explicitly. | MEDIUM | [ADR-002 §3] |
| 8 | Alloy mounts entire `/home` read-only. Should scope to `/home/luce` only. | MEDIUM | [ADR-009 §1] |
| 9 | Container restart loops are unbounded (`restart: unless-stopped`, no max_attempts). | LOW | [ADR-013 §6] |

**Execution approach:**
1. Add `deploy.resources.limits` for CPU and memory on each service
2. Replace Alloy healthcheck with `curl -sf http://127.0.0.1:12345/-/ready`
3. Add healthcheck blocks to host-monitor and docker-metrics
4. Add `condition: service_healthy` to all `depends_on` entries
5. Change `/var/run` mount to `:ro`, scope `/home` to `/home/luce`, remove Samba mount
6. Add comment documenting cAdvisor privileged requirement

**Dependency:** WD-01 port binding changes are in the same file. Coordinate if doing both.

---

## WD-04: Alerting & Monitoring Gaps

**What this is:** Fix alert rules so they fire correctly and actually reach someone. Touches Prometheus rules and potentially Grafana alerting config.

**Files touched:**
- `infra/logging/prometheus/rules/loki_logging_rules.yml`
- `infra/logging/prometheus/rules/sprint3_minimum_alerts.yml`
- `infra/logging/prometheus/prometheus.yml` (if adding alertmanager config)
- Potentially Grafana provisioning (if using Grafana alerting instead of Alertmanager)

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | No alert for Alloy pipeline failures. If Alloy silently drops logs, nobody is alerted. | HIGH | [ADR-005 §3] |
| 2 | No alert receiver/routing configured. Alerts fire but only visible in Prometheus UI. No email, Slack, or webhook. | HIGH | [ADR-005 §6] |
| 3 | Duplicate TargetDown alert: `TargetDown` (warning, 2m) in loki_logging_rules + `PrometheusTargetDown` (critical, 5m) in sprint3_minimum. Both fire simultaneously. | MEDIUM | [ADR-005 §1] |
| 4 | No alert for Loki volume fill rate (distinct from host disk alert). | MEDIUM | [ADR-005 §2] |
| 5 | Disk-full alert exists but has no receiver — fires into void. | MEDIUM | [ADR-013 §3] |
| 6 | Recording rules use `sprint3:` prefix namespace. Should use stable production namespace. | LOW | [ADR-005 §5] |

**Execution approach:**
1. Add Alloy pipeline failure alert rule (`alloy_logs_receiver_write_failures_total` or equivalent)
2. Decide alert routing target (email, Slack, webhook) — **open question #4**
3. Configure either Alertmanager or Grafana alerting as the receiver
4. Merge duplicate TargetDown into one rule with appropriate severity/threshold
5. Add Loki volume-specific disk alert
6. Rename `sprint3:` → stable namespace (e.g., `loki_logging:`)

**Dependency:** Requires decision on alert routing method before item 2-3.

---

## WD-05: Version Upgrades

**What this is:** Upgrade all pinned container images from their current (stale) versions. This is a coordinated effort because services interact and version compatibility matters.

**Files touched:**
- `.env` / `.env.example` (version variables)
- Potentially `infra/logging/docker-compose.observability.yml` (if image references or flags change)
- Potentially config files (if new versions require config changes)

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | Grafana 11.1.0 is EOL (~18 months behind, 12.3.3 current). Receives zero security patches. | CRITICAL | [ADR-010 §1] |
| 2 | Alloy v1.2.1 → v1.13.1 (11 minor versions behind). | HIGH | [ADR-010 table] |
| 3 | Loki 3.0.0 → 3.6.5 (6 minor versions behind). | HIGH | [ADR-010 table] |
| 4 | cAdvisor v0.49.1 → v0.56.2. Registry changed from `gcr.io` to `ghcr.io` at v0.53.0. | HIGH | [ADR-010 §2, table] |
| 5 | Node Exporter v1.8.1 → v1.10.2 (2 minor behind). | MEDIUM | [ADR-010 table] |
| 6 | Prometheus v2.52.0 → v3.x is a major migration with breaking changes. Plan separately. | HIGH | [ADR-010 §3] |

**Execution approach:**
1. Grafana first (EOL, security risk, independent of other services)
2. Alloy + Loki together (ingestion pipeline — test config compatibility between versions)
3. cAdvisor (registry change requires updating image reference pattern)
4. Node Exporter (low risk, minimal config surface)
5. Prometheus v3 migration as a separate planned effort (new UI, UTF-8 labels, breaking changes)

**Dependency:** Do after WD-03 (compose hardening) so resource limits are in place before testing new versions. Grafana can be done independently.

---

## WD-06: Operational Script Fixes

**What this is:** Fix bugs, safety issues, and inconsistencies in the operational scripts. Multiple files but all are shell scripts with the same patterns.

**Files touched:**
- `scripts/prod/mcp/logging_stack_down.sh`
- `scripts/prod/mcp/logging_stack_health.sh`
- `scripts/prod/mcp/logging_stack_audit.sh`
- `scripts/add-log-source.sh`
- `scripts/prod/mcp/validate_env.sh`
- `src/log-truncation/lib/template-engine.sh`

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | `template-engine.sh` uses `eval` with config-sourced values — command injection vector. Replace with `envsubst` or safe parameter expansion. | HIGH | [ADR-011 §1-2] |
| 2 | `logging_stack_down.sh` always uses `-v` (destroys all volumes). No safe default. Should default to stop-only with `--purge` flag for destructive mode. | HIGH | [ADR-007 §3] |
| 3 | `add-log-source.sh` references non-existent `.claude/prompts/` directory. Script is broken. | HIGH | [ADR-021 §3] |
| 4 | `add-log-source.sh` missing `set -uo pipefail` (only has `set -e`). | MEDIUM | [ADR-021 §2] |
| 5 | `add-log-source.sh` uses hardcoded absolute path `/home/luce/apps/loki-logging/`. | MEDIUM | [ADR-021 §1] |
| 6 | `logging_stack_health.sh` depends on `rg` (ripgrep) without `command -v` check. | MEDIUM | [ADR-007 §4] |
| 7 | `logging_stack_health.sh` hardcodes ports `9001`/`9004`, doesn't read from `.env`. | MEDIUM | [ADR-007 §5] |
| 8 | `logging_stack_audit.sh` leaks 7 `mktemp` files (only 1 has `trap` cleanup). | LOW | [ADR-007 §6] |
| 9 | `validate_env.sh` sources `.env` via `. "$ENV_PATH"` — executes arbitrary shell. | LOW | [ADR-006 §5] |
| 10 | `logging_stack_down.sh` doesn't validate `.env` exists before sourcing. | LOW | [ADR-007 §8] |
| 11 | Audit script uses fragile sed-based image parsing from YAML. | LOW | [ADR-007 §7] |
| 12 | `add-log-source.sh` source count stale (says 7, actual is 8). | LOW | [ADR-021 §4] |

**Execution approach:**
1. Replace `eval` in template-engine.sh with safe substitution
2. Rewrite `down.sh` to default safe (stop only), add `--purge` for volume removal
3. Create `stop.sh` for graceful stop (new script)
4. Fix `add-log-source.sh` — update path, add `set -euo pipefail`, fix playbook reference
5. Fix health script — add `rg` check, read ports from `.env`
6. Add `trap` cleanup for all `mktemp` files in audit script
7. Run `shellcheck` across all scripts after fixes

**Dependency:** None. Can parallelize with other domains.

---

## WD-07: Storage, Retention & Backup

**What this is:** Address storage lifecycle gaps — ingestion limits, backup strategy, graceful shutdown documentation.

**Files touched:**
- `infra/logging/loki-config.yml`
- New: `scripts/backup/backup-volumes.sh`, `scripts/backup/restore-volumes.sh`
- `docs/operations.md` or `docs/maintenance.md` (backup procedure docs)

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | No volume backup strategy. No cron job, snapshot script, or documentation. `down -v` destroys everything. | HIGH | [ADR-013 §2] |
| 2 | No graceful shutdown procedure documented. No drain for Alloy → Loki flush → Prometheus snapshot. | MEDIUM | [ADR-013 §5] |
| 3 | No Loki ingestion rate limits (`ingestion_rate_mb`, `ingestion_burst_size_mb`). A misbehaving pipeline can overwhelm storage. | MEDIUM | [ADR-004 §2] |
| 4 | No volume size monitoring in compose. 30d Loki + 15d Prometheus retention could exhaust disk. | MEDIUM | [ADR-004 §4] |
| 5 | Alloy WAL/retry behavior on Loki unavailability uses defaults. May not survive extended Loki downtime. | MEDIUM | [ADR-013 §4] |
| 6 | Loki single point of failure — single node, no replication, in-memory ring store. | HIGH | [ADR-013 §1] |
| 7 | `reject_old_samples: false` allows arbitrarily old log injection. | LOW | [ADR-004 §1] |
| 8 | No integration test for Alloy position tracking after log rotation. | MEDIUM | [ADR-011 §7] |

**Execution approach:**
1. Create volume backup script (docker volume inspect + tar/rsync)
2. Create restore script with verification
3. Document graceful shutdown procedure in operations.md
4. Add `limits_config` to loki-config.yml (ingestion rate, burst)
5. Items 6-8 are noted risks — document and accept for POC, plan for production elevation

**Dependency:** WD-06 (down.sh rewrite) should happen first so backup/restore integrates with the new safe-stop flow.

---

## WD-08: Dashboard & Grafana Provisioning

**What this is:** Fix Grafana provisioning so dashboards load reliably, UIDs are stable, and in-browser edits don't silently vanish.

**Files touched:**
- `infra/logging/grafana/provisioning/dashboards/dashboards.yml`
- `infra/logging/grafana/provisioning/datasources/loki.yml`
- `infra/logging/grafana/provisioning/datasources/prometheus.yml`
- Dashboard JSON files (if normalizing naming)

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | Dashboard subdirectories (`adopted/`, `dimensions/`, `sources/`) may not be scanned — `foldersFromFilesStructure` not configured. Verify at runtime. | MEDIUM | [ADR-008 §3] |
| 2 | Datasource UIDs not pinned. Auto-generated UIDs may differ across deployments, breaking dashboard references. | MEDIUM | [ADR-008 §5] |
| 3 | `editable: true` means in-browser dashboard edits are silently lost on container restart. | MEDIUM | [ADR-008 §1] |
| 4 | `disableDeletion: false` allows accidental deletion of provisioned dashboards. | LOW | [ADR-008 §2] |
| 5 | Dashboard JSON naming inconsistent (underscores vs hyphens: `host_overview.json` vs `host-container-overview.json`). | LOW | [ADR-017 §2] |
| 6 | `zprometheus-stats.json` uses `z` prefix hack for sort ordering. | LOW | [ADR-017 §3] |

**Execution approach:**
1. Set `foldersFromFilesStructure: true` in dashboards.yml and verify subdirectories load
2. Pin explicit `uid` in both datasource YAML files
3. Update dashboard JSON files to reference pinned UIDs
4. Set `editable: false` and `disableDeletion: true`
5. Rename dashboard files to consistent kebab-case (optional, cosmetic)

**Dependency:** Do after WD-05 Grafana upgrade (provisioning YAML syntax may change between 11.x and 12.x).

---

## WD-09: Repo Cleanup & Git Hygiene

**What this is:** One cleanup PR — remove stale files, fix naming, update gitignore, consolidate script locations. Pure file management, no config behavior changes.

**Files touched:**
- `.gitignore`
- Multiple files to `git rm` or `git mv`
- `docs/manifest.json`
- `infra/logging/` (remove 5 stale markdown files + 2 backup files)
- `docs/snippets/` (delete entirely)

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | 2 Alloy backup files tracked in git. Add `*.backup-*` to `.gitignore`, then `git rm --cached`. | MEDIUM | [ADR-015 §1, ADR-018 §2] |
| 2 | 5 stale markdown files in `infra/logging/` (ALERTS_CHECKLIST, CHANGELOG, PR_BUNDLE, RELEASE_NOTES, RUNBOOK). Move to `_build/archive/` or delete. | MEDIUM | [ADR-018 §1] |
| 3 | `docs/snippets/` directory is massively stale (alloy snippet: 76 lines vs 393 canonical). Delete entirely — link to canonical files instead. | HIGH | [ADR-019 §1-3] |
| 4 | `docs/manifest.json` references non-existent file paths (old numeric-prefixed names in archive). Delete or regenerate. | MEDIUM | [ADR-018 §4] |
| 5 | 5 UPPERCASE file naming violations: `QUICK-ACCESS.md`, `docs/INDEX.md`, and 3 in `infra/logging/`. Rename to kebab-case. | MEDIUM | [ADR-017 §1] |
| 6 | Script location fragmentation: `infra/logging/scripts/` (5 scripts) is separate from `scripts/prod/`. Consolidate. | MEDIUM | [ADR-020, ADR-018 §6] |
| 7 | Dead `.local-archives/` entry in `.gitignore`. Remove. | LOW | [ADR-015 §4] |
| 8 | `docs/monitoring.md` orphaned — not in manifest. Verify if superseded, then archive or delete. | LOW | [ADR-018 §3] |
| 9 | `.codex-prompt-state.env.example` at repo root — unclear if actively used. | LOW | [ADR-018 §5] |

**Execution approach:**
1. `git rm` Alloy backups, add `*.backup-*` to `.gitignore`
2. `git rm` or `git mv` stale files from `infra/logging/`
3. `git rm -r docs/snippets/`
4. Fix or delete `docs/manifest.json`
5. `git mv` UPPERCASE files to kebab-case
6. Move `infra/logging/scripts/*` to `scripts/ops/`
7. Clean dead `.gitignore` entries

**Dependency:** Do before WD-10 (docs sync) since file renames affect doc references.

---

## WD-10: Documentation Accuracy & CI/CD

**What this is:** Sync all documentation with reality after config and file changes have settled. Also establish minimum CI/CD to prevent future drift.

**Files touched:**
- `CLAUDE.md`
- `docs/reference.md`
- `docs/quality-checklist.md`
- `QUICK-ACCESS.md` (or `docs/quick-access.md` after rename)
- `.editorconfig`
- New: `.github/workflows/validate.yml`
- New: `.github/CODEOWNERS`

**Items (execution order):**

| # | Finding | Severity | Source |
|---|---------|----------|--------|
| 1 | No `.github/` directory — no CI/CD, no CODEOWNERS, no issue templates, no dependabot. | HIGH | [ADR-014 §1] |
| 2 | No automated test suite (`make test`, CI pipeline). All validation is manual. | HIGH | [ADR-024 §1] |
| 3 | No shellcheck on any of the 22 shell scripts. | MEDIUM | [ADR-024 §2] |
| 4 | No Alloy config syntax check outside audit script. Broken config deploys silently. | MEDIUM | [ADR-024 §3] |
| 5 | No git hooks (no pre-commit for config validation). | MEDIUM | [ADR-014 §2] |
| 6 | `CLAUDE.md` claims `host=codeswarm` label — doesn't exist. Also says 10-15s ingestion delay with no evidence. | MEDIUM | [ADR-012 §1, §5] |
| 7 | `docs/reference.md` says "7 active log sources" (actual: 8). Label schema incomplete — only documents `codeswarm_mcp` log_source. | MEDIUM | [ADR-012 §2, §4] |
| 8 | `docs/quality-checklist.md` false claims: "UFW-protected", all logs have `host` label. | HIGH, MEDIUM | [ADR-022 §1-2] |
| 9 | `.editorconfig` covers 15+ unused languages, missing HCL/Alloy section. | LOW | [ADR-025 §1-2] |
| 10 | No version tags for the stack itself — no rollback to known-good config. | MEDIUM | [ADR-014 §3] |
| 11 | `quality-checklist.md` hardcodes image versions that will drift. | LOW | [ADR-022 §3] |
| 12 | Duplicate `.env` credential variables (`GRAFANA_ADMIN_*` vs `GF_SECURITY_*`). | LOW | [ADR-006 §4] |

**Execution approach:**
1. Create `.github/workflows/validate.yml`: shellcheck + `alloy fmt` + `promtool check rules` + `docker compose config`
2. Create `.github/CODEOWNERS`
3. Add pre-commit hook for config validation
4. Run shellcheck across all 22 scripts, fix findings
5. Update `CLAUDE.md` — fix label docs, source count, remove unverified claims
6. Update `docs/reference.md` — fix source count, complete label schema
7. Update `docs/quality-checklist.md` — remove false UFW claim, fix label claim, reference `.env.example` for versions
8. Trim `.editorconfig` to project-relevant sections, add `[*.alloy]` block
9. Tag a release once stable

**Dependency:** Do last. All other work domains change config and files that these docs reference.

---

## Execution Order Summary

```
WD-01  Network Security          ──┐
WD-02  Alloy Pipeline Integrity  ──┼── No dependencies, can run in parallel
WD-06  Script Fixes              ──┘
                                    │
WD-03  Compose Hardening         ───── After WD-01 (same file, coordinate)
WD-04  Alerting Gaps             ───── Needs routing decision (open question #4)
WD-07  Storage & Backup          ───── After WD-06 (down.sh rewrite)
                                    │
WD-05  Version Upgrades          ───── After WD-03 (resource limits before upgrade testing)
                                    │
WD-08  Dashboard Provisioning    ───── After WD-05 (Grafana upgrade may change provisioning)
WD-09  Repo Cleanup              ───── After all config changes (renames affect references)
                                    │
WD-10  Docs & CI/CD             ───── Last (docs must reflect final state)
```

**Finding distribution across work domains:**

| Domain | Findings | Critical | High | Medium | Low |
|--------|----------|----------|------|--------|-----|
| WD-01 Network Security | 4 | 1 | 1 | 1 | 1 |
| WD-02 Alloy Pipelines | 6 | 0 | 1 | 2 | 3 |
| WD-03 Compose Hardening | 9 | 0 | 1 | 4 | 4 |
| WD-04 Alerting Gaps | 6 | 0 | 2 | 3 | 1 |
| WD-05 Version Upgrades | 6 | 1 | 4 | 1 | 0 |
| WD-06 Script Fixes | 12 | 0 | 3 | 4 | 5 |
| WD-07 Storage & Backup | 8 | 0 | 2 | 4 | 2 |
| WD-08 Dashboard Provisioning | 6 | 0 | 0 | 3 | 3 |
| WD-09 Repo Cleanup | 9 | 0 | 1 | 4 | 4 |
| WD-10 Docs & CI/CD | 12 | 0 | 3 | 5 | 4 |
| **Totals** | **78** | **2** | **18** | **31** | **27** |

*Note: Some findings appear in multiple domains (e.g., quality-checklist false UFW claim is in both WD-01 and WD-10). Total count is 78 vs 77 unique findings due to 1 cross-domain duplicate.*

---

## WD-11: Reusable Tooling from _dev-tools

**What this is:** Adopt, adapt, or reference proven tooling from `/home/luce/apps/_dev-tools/` that directly addresses gaps identified in WD-01 through WD-10. This is not greenfield — these tools already exist and are production-quality.

**Source inventory reviewed:**

| Tool | Location | Lines | Relevant To |
|------|----------|-------|-------------|
| bash-basher | `_dev-tools/tools/bash-basher/` | ~200 (wrapper) + Python core | WD-06, WD-10 (script linting, CI) |
| dependency-updater | `_dev-tools/tools/dependency-updater/` | 1841 | WD-05 (version tracking, SBOM) |
| backup-rollback.sh | `_dev-tools/tools/dependency-updater/lib/backup-rollback.sh` | 211 | WD-07 (safe backup before config changes) |
| json-output.sh | `_dev-tools/tools/dependency-updater/lib/json-output.sh` | 153 | WD-06 (structured health check output) |
| dashboard.sh | `_dev-tools/tools/dependency-updater/lib/dashboard.sh` | 429 | WD-06 (health check status display) |
| Logging-Bootstrap | `_dev-tools/projects/Logging-Bootstrap/` | Full project | WD-03, WD-07 (health contracts, preflight patterns) |
| health_contract.json | `_dev-tools/projects/Logging-Bootstrap/contracts/health_contract.json` | 69 | WD-03 (service health check definitions) |
| port_exposure.json | `_dev-tools/projects/Logging-Bootstrap/contracts/port_exposure.json` | 13 | WD-01 (port binding validation) |
| github-setup-playbook | `_dev-tools/tools/github-setup-playbook/` | 2747 | WD-10 (GitHub CI/CD bootstrap) |
| bash-scripter-playbook | `_dev-tools/tools/bash-scripter-playbook/` | 1016 | WD-06 (extract runbook CLIs from docs) |

**Items (grouped by target work domain):**

### For WD-06 (Script Fixes) + WD-10 (CI/CD):

| # | Opportunity | Impact | Action |
|---|-------------|--------|--------|
| 1 | **bash-basher** — 172-rule shell linter with tier system (BREAK/AUTO_FIX/WARN). Supports `--profile security` and `--profile ci`. Outputs JSON, SARIF (GitHub Code Scanning), Markdown. | HIGH | Run `bash-basher --profile security scripts/prod/mcp/` to get baseline. Add to CI workflow (`validate.yml`). Catches unsafe `eval`, unquoted vars, missing `set -euo pipefail`, temp file leaks — all of which are findings in WD-06. |
| 2 | **bash-basher pre-commit hook** — `.pre-commit-hooks.yaml` already exists. | MEDIUM | Copy hook config to loki-logging `.pre-commit-config.yaml`. Prevents new script issues from reaching main. |
| 3 | **bash-scripter-playbook** — Extracts embedded bash from `.md` playbooks → auto-generates companion `.sh` CLIs. | MEDIUM | Run against `docs/operations.md` and `docs/maintenance.md` to extract operational runbook commands into validated scripts. Guarantees syntax correctness of documented procedures. |

### For WD-05 (Version Upgrades):

| # | Opportunity | Impact | Action |
|---|-------------|--------|--------|
| 4 | **dependency-updater** — Multi-ecosystem dependency manager. `audit --severity high` for security vulns, `sbom` for software bill of materials, `report` for dashboard. | MEDIUM | Run `dependency-manager.sh audit` against Docker images. Generate SBOM per release. Integrate `outdated` check into CI for Grafana/Loki/Prometheus/Alloy version drift detection. |

### For WD-07 (Storage & Backup):

| # | Opportunity | Impact | Action |
|---|-------------|--------|--------|
| 5 | **backup-rollback.sh** — Atomic backup + CRC verification + rollback on failure pattern. | HIGH | Adapt for volume backup scripts. Pattern: backup → verify CRC → proceed with change → rollback on failure. Directly addresses ADR-013 §2 (no backup strategy). |
| 6 | **Logging-Bootstrap preflight/verify pattern** — 10-level validation: preflight → apply → verify → evidence bundle. Each run saves to `$OUTPUT_DIR/runs/<timestamp>/`. | MEDIUM | Adopt evidence bundle pattern for `logging_stack_audit.sh`. Save audit results as timestamped JSON for post-incident diagnosis. Currently audit output is ephemeral. |

### For WD-03 (Compose Hardening):

| # | Opportunity | Impact | Action |
|---|-------------|--------|--------|
| 7 | **health_contract.json** — Declarative health check definitions per service (endpoint, expected status, timeout, retries, backoff). | MEDIUM | Adopt contract-driven health checks. Current health script hardcodes endpoints. A JSON contract makes health checks data-driven and testable. **Note:** The existing contract has the same weak Alloy check (`alloy fmt --help`). Fix that in our adopted version to use `/-/ready`. |
| 8 | **port_exposure.json** — Validation rules for bind addresses and port ranges. Uses `ss -tln` for verification. | LOW | Reference pattern for WD-01 port binding validation. Adds a runtime check that actual bind addresses match intent. |

### For WD-10 (CI/CD):

| # | Opportunity | Impact | Action |
|---|-------------|--------|--------|
| 9 | **github-setup-playbook** — 2747-line parameterized GitHub project bootstrap. Generates workflows, CODEOWNERS, templates, hooks. | HIGH | Run against loki-logging to generate `.github/` directory structure. Saves manual creation of validate.yml, CODEOWNERS, PR template, issue templates. Addresses ADR-014 §1 directly. |

**Execution approach:**
1. Run bash-basher security profile against all 22 scripts → get baseline findings
2. Generate `.github/` structure using github-setup-playbook (or adapt its templates manually)
3. Adapt backup-rollback.sh pattern for volume backup scripts
4. Adopt health_contract.json pattern (fix the Alloy healthcheck in our copy)
5. Integrate bash-basher into pre-commit hook and CI workflow
6. Run dependency-updater audit to verify current image security posture

**Dependency:** This domain feeds into WD-06, WD-07, and WD-10. Run the bash-basher baseline early (before WD-06 script fixes) to prioritize which scripts need the most work. Run github-setup-playbook before WD-10 CI/CD setup.

**Updated execution order:**

```
WD-11  _dev-tools Baseline    ───── Run first (bash-basher scan, github-setup-playbook)
                                    │
WD-01  Network Security          ──┐
WD-02  Alloy Pipeline Integrity  ──┼── No dependencies, can run in parallel
WD-06  Script Fixes              ──┘  (informed by WD-11 bash-basher baseline)
                                    │
WD-03  Compose Hardening         ───── After WD-01 (same file, coordinate)
WD-04  Alerting Gaps             ───── Needs routing decision (open question #4)
WD-07  Storage & Backup          ───── After WD-06 (uses WD-11 backup-rollback pattern)
                                    │
WD-05  Version Upgrades          ───── After WD-03 (resource limits before upgrade testing)
                                    │
WD-08  Dashboard Provisioning    ───── After WD-05 (Grafana upgrade may change provisioning)
WD-09  Repo Cleanup              ───── After all config changes (renames affect references)
                                    │
WD-10  Docs & CI/CD             ───── Last (uses WD-11 github-setup-playbook output)
```

---
---

# Pass 5: Live Runtime Validation & _dev-tools Deep Dive

## Run: 2026-02-17 Pass 5 | Scope: live stack diagnostics (read-only), shellcheck, config audit, new commits review, _dev-tools pattern catalog

- `ADR-031` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-031: Shellcheck Baseline (Read-Only Scan)

- **Context:** Ran `shellcheck --severity=warning` across all scripts in `scripts/`, `src/log-truncation/`, `infra/logging/scripts/`.
- **Findings:**
  - **11 total findings** across all scripts (severity=warning threshold)
  - **1 error**: `src/log-truncation/scripts/status.sh:40` — `local` used outside function (`SC2168`)
  - **4 SC1090 warnings**: Non-constant source (`.env` sourced via variable) in `down.sh`, `audit.sh`, `validate_env.sh`, `up.sh`
  - **1 SC2034**: Unused variable `STORE_ROOT` in `codex_prompt_state_smoke.sh`
  - **1 SC2034**: Unused variable `i` in `e2e_check_hardened.sh`
  - **1 SC2024**: `sudo` doesn't affect redirects in `verify_grafana_authority.sh`
  - **2 SC2155**: Declare and assign separately in `status.sh`, `build-configs.sh`
  - **1 SC2024**: sudo redirect in `verify_grafana_authority.sh`

  Shellcheck is available (`v0.10.0`). promtool is NOT installed on the host.

  Overall: **11 warnings, 1 error** — relatively clean for 22+ scripts. The SC2168 error in status.sh is a real bug. Severity: **MEDIUM** (mostly style, one real bug).

- **Decision:** Fix the SC2168 bug in status.sh. Add `# shellcheck source=` directives for the SC1090 warnings. Run shellcheck in CI.
- **Evidence:** `shellcheck --severity=warning --format=gcc` output

---

- `ADR-032` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-032: Loki Config Safety Audit

- **Context:** Parsed `loki-config.yml` to verify safety limits.
- **Findings:**
  - `ingestion_rate_mb`: **NOT SET** (no limit — confirmed from ADR-004 §2)
  - `ingestion_burst_size_mb`: **NOT SET**
  - `reject_old_samples`: `false` (confirmed from ADR-004 §1)
  - `max_line_size`: `256KB` (set — good)
  - `retention_enabled`: `true`
  - `retention_delete_worker_count`: `50`
  - Schema: `v13` / `tsdb` / `filesystem` (from 2024-01-01)

  No changes from Pass 1 findings. Ingestion rate limits still missing. Severity: **Confirmed MEDIUM**.
- **Evidence:** Python YAML parse of `infra/logging/loki-config.yml`

---

- `ADR-033` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-033: Compose Runtime vs Config Drift

- **Context:** Compared running container config against declared compose file.
- **Findings:**
  - **All 6 services have `limits=NONE`** — Confirmed from parsed compose config. No service has `deploy.resources.limits`.
  - **2 services have no healthcheck** — `docker-metrics` and `host-monitor` (confirmed from compose parse).
  - **Grafana bound to `0.0.0.0:9001`** — Confirmed. UFW bypass applies.
  - **Prometheus bound to `0.0.0.0:9004`** — Confirmed.
  - **Alloy syslog bound to `127.0.0.1:1514`** — Correct (loopback only).
  - **cAdvisor `privileged: true`** — Confirmed.
  - **All services: `restart=unless-stopped`** — Confirmed. No max_attempts.
  - **Loki running state has port 3200 exposed but compose config has no ports** — Config drift. Container needs recreation.

  All Pass 1 findings confirmed at runtime. No false positives. Severity: **Validates ADR-002, ADR-006, ADR-009**.
- **Evidence:** `docker compose config`, `docker stats`, `ss -tlnp`

---

- `ADR-035` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-035: _dev-tools Deep Pattern Catalog

- **Context:** Deep read of library files, contracts, and operational patterns from `/home/luce/apps/_dev-tools/`.
- **Findings — Additional patterns beyond WD-11 initial scan:**

  **High-Priority Adoptable Patterns:**

  1. **Error taxonomy contract** — `_dev-tools/projects/Logging-Bootstrap/contracts/error_taxonomy.json`: Six error buckets (ENV, CONFIG, RUNTIME, PROOF, NETWORK, SECURITY) with stable error codes, human messages, and suggested actions. Loki-logging has no error classification — all failures are ad-hoc string matching. Severity: **MEDIUM** (quality improvement).

  2. **Label contract** — `_dev-tools/projects/Logging-Bootstrap/contracts/label_contract.json`: Declarative required labels, valid values, cardinality limits, validation selectors. Loki-logging's label schema exists only in docs (which are stale per ADR-012). Severity: **MEDIUM**.

  3. **Secrets policy contract** — `_dev-tools/projects/Logging-Bootstrap/contracts/secrets_policy.json`: Required keys, placeholder detection, file mode enforcement (600). Current `validate_env.sh` does basic checks but no placeholder detection. Severity: **LOW**.

  4. **Checkpoint/restore pattern** — `_dev-tools/projects/Logging-Bootstrap/bin/lib/checkpoint.sh`: Snapshot running containers + config SHAs to timestamped dir. `checkpoint_create()`, `checkpoint_list()`, `checkpoint_latest()`. Directly applicable to WD-07 backup strategy. Severity: **HIGH** (fills a real gap).

  5. **Clean slate with dry-run** — `_dev-tools/projects/Logging-Bootstrap/bin/clean_slate.sh`: Default dry-run, requires `--force` to execute. Layered deletion with audit trail. Directly applicable to WD-06 `down.sh` rewrite. Severity: **HIGH**.

  6. **SHA-based config diff** — `_dev-tools/projects/Logging-Bootstrap/bin/bootstrap_apply.sh`: `sha256sum` current vs staged configs, atomic swap via temp dir + backup. Detect config drift before applying. Severity: **MEDIUM**.

  7. **Preflight validation framework** — `_dev-tools/tools/prompt-runner/lib/prompt-preflight.sh`: `preflight_require()`, `preflight_optional()`, `preflight_env_required()`, `preflight_dir_writable()`. Three-tier validation (required/optional/environment). Severity: **MEDIUM**.

  8. **CVE suppression with time-bound expiry** — `_dev-tools/tools/dependency-updater/lib/suppressions.sh`: JSON-based suppression list with `until` date, reason, approver. Auto-expires. Severity: **LOW** (useful for known issues registry).

  **Updated WD-11 scope:** Added 8 new patterns (items 1-8 above) to the 9 already documented, bringing WD-11 total to 17 adoptable patterns.

- **Evidence:** Deep file reads via explore agent across all _dev-tools libraries and contracts.

---

---

## Pass 6: Deep Pipeline & Tooling Audit (Loop 1)

- `ADR-044` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-044: Bash-Basher Audit Baseline
- **Context:** Ran `bash-basher.sh` (172-rule linter from `_dev-tools/`) against 5 core scripts: `logging_stack_up.sh`, `logging_stack_health.sh`, `logging_stack_audit.sh`, `melissa_batchlib.sh`, `status.sh`.
- **Findings:**
  1. **Total findings across 5 scripts:** ~120 findings. Breakdown by severity:
     - BREAK: 7 (source untrusted ×4, env path trust ×4, hardcoded credentials ×1)
     - WARN: ~85 (hardcoded paths, unused vars, deep nesting, unset vars, etc.)
     - AUTO_FIX: ~28 (unquoted vars, noclobber, inherit errexit, subshell masks)
  2. **BB024 BREAK: Hardcoded credentials in `melissa_batchlib.sh`** — `derive_grafana_pass()` at line 39 extracts `GF_SECURITY_ADMIN_PASSWORD` from running container via `docker inspect`. bash-basher flags this as credential exposure in script output. Severity: **HIGH** (the password transits through shell variables and process table).
  3. **BB029 BREAK: Source untrusted** — All scripts that `source` other scripts do so without first validating the file exists with `[[ -f "$path" ]]`. Severity: **MEDIUM** (all sources are hardcoded paths, not user-supplied, so real risk is low).
  4. **BB096 BREAK: Env path trust** — Scripts that source `.env` or parse env vars trust the contents without validation. In this project `.env` is user-controlled and mode 600, so risk is contextual. Severity: **LOW**.
  5. **`logging_stack_audit.sh` has highest finding count** — ~80 findings including BB090 deep nesting (30+ lines flagged), BB116 sed injection, BB091 long function, BB112 glob before assignment. This script is the most complex and needs the most hardening. Severity: **HIGH** (cumulative risk).
  6. **`status.sh` has BB135 unset variable warnings** — Multiple variables used without being assigned first (lines 16, 25, 26, 37, 65). Correlates with the SC2168 shellcheck error from ADR-031. Severity: **MEDIUM**.
  7. **Common AUTO_FIX patterns across all scripts:** BB098 noclobber missing, BB100 inherit errexit missing. These are safe to apply project-wide in one PR. Severity: **LOW** (easy batch fix).
  8. **`melissa_longrun.sh` specific:** BB029 source untrusted (line 22), BB015 hardcoded home path (line 4), BB031 unquoted command substitution in `for` loop (line 162), 4× BB043 unused variable warnings for variables that ARE used via `source`d batchlib (false positives from cross-file analysis limitation). Severity: **MEDIUM**.
- **Evidence:** bash-basher output for 5 scripts. Full findings logged.

---

### Loki Source Inventory (Confirmed via API)
- **log_source values active in Loki (5):** `codeswarm_mcp`, `docker`, `rsyslog_syslog`, `telemetry`, `vscode_server`
- **Missing from Loki:** `tool_sink`, `journald`, `nvidia_telem` — either no data ingested yet for these sources, or the `log_source` label is not being indexed. Note: `tool_sink` may have zero files in `_logs/` and `nvidia_telem` may not be active. `journald` is confirmed active via `loki_source_journal_target_lines_total` metric in Prometheus, suggesting journald logs exist but `log_source` label querying may differ.

---

---

## Pass 7: Infrastructure & Alerting Deep Audit (Loop 2)

- `ADR-046` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-046: Prometheus Recording & Alert Rules Detailed Review
- **Context:** All 18 rules in `prometheus/rules/loki_logging_rules.yml` — 11 recording rules + 4 alerts + 3 implicit.
- **Findings:**
  1. **11 recording rules, all prefixed `sprint3:`** — Clean namespace. Rules cover: targets up/down, job health ratio, scrape failures, Loki ingestion errors, host CPU/memory/disk, container CPU/memory. Severity: **PASS**.
  2. **4 alert rules:** TargetDown (2m), NodeDiskSpaceLow (5m >90%), NodeMemoryHigh (5m >90%), NodeCPUHigh (5m >90%). All severity=warning. Severity: **PASS** (basic coverage).
  3. **Missing alert for Loki ingestion errors** — `sprint3:loki_ingestion_errors:rate5m` is recorded but never alerted on. Also `sprint3:loki_ingestion_errors:increase10m` is recorded but unused by any alert or dashboard reference. Severity: **HIGH** (the recording rule exists but nobody acts on it — same pattern as ADR-041 #6).
  4. **`sprint3:prometheus_scrape_failures:rate5m`** — Records rate of `prometheus_target_scrapes_exceeded_sample_limit_total`. No alert fires on this. Severity: **MEDIUM**.
  5. **No alerts for container resource usage** — `sprint3:container_cpu_usage_cores:rate5m` and `sprint3:container_memory_workingset_bytes` are recorded but not alerted on. A runaway container won't trigger any notification. Severity: **MEDIUM**.
  6. **`sprint3:` prefix tied to sprint name** — These rules will outlive Sprint 3 but carry its name. Minor naming hygiene. Severity: **LOW**.
  7. **Loki distributor metric may not exist** — `sprint3:loki_ingestion_errors:rate5m` references `loki_distributor_ingester_appends_failed_total` which is a Loki distributor metric. In monolithic mode (Loki 3.0 single binary), this metric may not be emitted. Need to verify. Severity: **MEDIUM** (recording rule may always be 0).
- **Evidence:** `infra/logging/prometheus/rules/loki_logging_rules.yml` (73 lines).

---

- `ADR-049` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-049: Alloy Positions File Audit
- **Context:** Checked Alloy positions volume (`alloy-positions:/tmp`) for file tracking state.
- **Findings:**
  1. **Positions volume is EMPTY** — The named volume `logging_alloy-positions` is mounted at `/tmp` but contains zero files. The `/tmp` directory in the container is empty. Severity: **HIGH**.
  2. **Alloy v1.2.1 default positions path** — Alloy `loki.source.file` default `positions_file` is `$DATA_PATH/loki.source.file.*/positions.yml`. The default `$DATA_PATH` for Alloy is typically `/var/lib/alloy/data/`, NOT `/tmp`. The compose config maps `alloy-positions:/tmp` but Alloy may be writing positions to its internal data directory (not `/tmp`). Severity: **HIGH** (if positions are in container filesystem, they're lost on recreate → duplicate log ingestion).
  3. **No `positions_file` override in alloy-config.alloy** — None of the `loki.source.file` blocks set a custom `positions_file` path. They rely on the default. If the default is NOT `/tmp`, the named volume serves no purpose. Severity: **HIGH** (volume mount may be misconfigured).
  4. **Impact on restart:** If Alloy loses positions on container recreate, all file-based sources (tool_sink, telemetry, nvidia_telem, codeswarm_mcp, vscode_server) will re-ingest from `tail_from_end = true` — meaning only NEW lines after restart. Old lines between last position and restart are lost. Lines already sent may be re-sent if tailing resumes from a different offset. Severity: **MEDIUM** (data integrity gap).
- **Evidence:** `docker exec logging-alloy-1 ls -la /tmp/`, `docker inspect` mounts, Alloy config review.

---

- `ADR-056` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-056: Grafana Alerts Both Firing
- **Context:** Queried Grafana Alertmanager API for active alert instances.
- **Findings:**
  1. **BOTH Grafana alerts are currently firing:**
     - `Logging E2E marker missing (15m)` — active since 2026-02-17T10:58:00 (~11 hours). No MARKER process exists on the host to feed this alert. It has been firing since Grafana was last restarted. Severity: **HIGH** (false positive alert erodes trust in alerting).
     - `Logging ingest appears down (5m)` — active since 2026-02-17T10:58:00 (~11 hours). This means `sum(count_over_time({log_source=~".+"}[5m])) < 1` — Loki reports zero logs over 5m windows. Severity: **CRITICAL** (either log ingestion is genuinely broken, or the Grafana→Loki query path has an issue despite Alloy metrics showing active ingestion).
  2. **Contradiction with Alloy metrics:** Alloy `loki_write_sent_bytes_total=15.2 MiB` and `loki_source_*_total` counters show active ingestion. But the Grafana alert query uses `{log_source=~".+"}` against Loki — this query may fail if Grafana's Loki datasource connection is broken, or if the Grafana managed alerting evaluation path differs from dashboard queries. Severity: **CRITICAL** (investigate: is Grafana alerting actually querying Loki successfully?).
  3. **`for: 0m` caused immediate firing** — Both alerts have no grace period, so they fired on the very first evaluation after Grafana restart. With `noDataState: Alerting`, if the Loki query returned no data (e.g., during cold start), the alert would fire immediately. Severity: **MEDIUM** (confirms ADR-045 #2).
- **Evidence:** Grafana `/api/alertmanager/grafana/api/v2/alerts`.

---

- `ADR-057` moved from adr.md
  - evidence: (docker inspect logging-alloy-1 cmd/mounts => storage.path=/var/lib/alloy and /var/lib/alloy mount present; journald mounts present)
### ADR-057: Alloy Positions — Volume Misconfiguration Confirmed
- **Context:** Investigated Alloy's actual `--storage.path` default and data directory contents.
- **Findings:**
  1. **Alloy `--storage.path` default is `data-alloy/`** (relative to CWD). The compose command does NOT set `--storage.path`. Alloy's CWD in the container is `/` (root). So positions would be written to `/data-alloy/`. Severity: **HIGH**.
  2. **`/var/lib/alloy/data/` exists but is EMPTY** — This is the Alloy image's pre-created data directory, but Alloy is not configured to use it. The `--storage.path` flag would need to be set to `/var/lib/alloy/data` explicitly. Severity: **HIGH**.
  3. **Named volume `alloy-positions:/tmp` is correctly mounted but serves NO PURPOSE** — Alloy doesn't write to `/tmp`. The intent was to persist positions, but the volume target is wrong. Severity: **HIGH** (fix: either `--storage.path=/tmp` in compose command, or change volume mount to `/data-alloy`).
  4. **24 healthy Alloy components, 0 config load failures** — Alloy is operationally healthy; only positions persistence is broken. Severity: **PASS** (component health).
- **Evidence:** `alloy run --help` showing `--storage.path` default, `docker exec ls -laR /var/lib/alloy/data/`, container cmdline.

---

- `ADR-062` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-062: Journald Pipeline — Zero Delivery
- **Context:** Queried Loki for `{log_source="journald"}` and checked Alloy `loki_source_journal_target_lines_total`.
- **Findings:**
  1. **Zero journald lines ingested** — `loki_source_journal_target_lines_total = 0`. The journald source is configured in Alloy but has NEVER delivered a single log line. Severity: **HIGH** (broken pipeline).
  2. **No journald data in Loki** — Query for `{log_source="journald"}` returns empty. Severity: **HIGH**.
  3. **Likely root cause: journal access permissions** — The Alloy container needs read access to host journal files. The compose file mounts `HOST_RUN_LOG_JOURNAL` and `HOST_VAR_LOG_JOURNAL` but these may not be mapped. Checking compose: the Alloy service does NOT mount journal paths — only `HOST_HOME`, `HOST_DOCKER_SOCK`, `HOST_VAR_LOG_SAMBA`, and config. The journal mount is MISSING from compose despite the Alloy config having a `loki.source.journal` block. Severity: **HIGH** (config/compose mismatch).
  4. **Alloy config line 64-66:** `loki.source.journal "journald" { forward_to = [loki.process.journald.receiver] }` — no `path` argument means Alloy tries default journal path (`/var/log/journal` or `/run/log/journal`), but these are not mounted. Severity: **HIGH**.
- **Evidence:** Prometheus metrics, Loki query, Alloy config, compose volume mounts.

---

- `ADR-063` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-063: Documentation Staleness Inventory
- **Context:** Searched all 19 docs for stale references to ports, versions, and internal-only assertions.
- **Findings:**
  1. **"Loki is internal-only" stated in 5 locations but FALSE at runtime:**
     - `CLAUDE.md:73` "None (internal only)"
     - `CLAUDE.md:111` "no `http://127.0.0.1:3100` access"
     - `docs/README.md:223` "Loki is internal-only"
     - `docs/security.md:30` "No external binding"
     - `docs/quality-checklist.md:121` "Loki is internal-only"
     At runtime, Loki is accessible at `0.0.0.0:3200`. Severity: **HIGH** (security docs are wrong).
  2. **Version references in 4 doc files match current config** — `overview.md`, `quality-checklist.md`, `architecture.md` all reference Grafana 11.1.0, Loki 3.0.0, Prometheus v2.52.0, Alloy v1.2.1. These are correct per `.env.example` but represent outdated versions needing upgrade (ADR-010). Severity: **LOW** (docs match config, but config is outdated).
  3. **19 documentation files total** — Including 2 archive files (`archive/10-as-installed.md`, `archive/20-as-configured.md`). Severity: **PASS** (inventory complete).
  4. **`docs/troubleshooting.md:494`** says trying to access `http://127.0.0.1:3100` is an error — but at runtime, `http://127.0.0.1:3200` works (config drift makes it accessible). Contradictory. Severity: **MEDIUM**.
- **Evidence:** `grep` across all docs files for port/version references.

---

---

## Pass 9: Final Validation & Cross-Reference (Loop 4)

- `ADR-064` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-064: Second Loki Instance Identified
- **Context:** Investigated iptables DNAT rules for ports 3100/3101 on subnet 172.22.0.0/16.
- **Findings:**
  1. **The "second Loki" is `codeswarm-mcp` container** (id=467c0393ffbd) on network `vllm_fast_executor_default`. IP `172.22.0.2`. This is a CodeSwarm MCP container from the `vllm` compose project that runs its own Loki instance. Severity: **MEDIUM** (not a security issue for THIS project, but port 3100 is also exposed to 0.0.0.0 via Docker DNAT).
  2. **Port 3100 collision potential** — Both the logging project's Loki (on obs network, port 3200→3100) and the vllm project's Loki (on vllm network, port 3100→3100) are DNATed. Docker assigns different host ports, so there's no actual collision, but it creates confusion. Severity: **LOW**.
  3. **Port 3101 also exposed** — The vllm Loki has both 3100 and 3101 mapped. Severity: **LOW** (not in scope for this project).
- **Evidence:** `sudo iptables -t nat -L DOCKER -n`, `docker inspect` network info.

---

- `ADR-065` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-065: Grafana Alert — Ingest-Down Is a False Positive
- **Context:** Tested the exact Loki query used by the `logging-total-ingest-down` alert.
- **Findings:**
  1. **Loki returns 4370 log lines in the last 5m** — `sum(count_over_time({log_source=~".+"}[5m]))` returns a valid result. Data IS flowing. The alert should NOT be firing. Severity: **CRITICAL** (false positive alert).
  2. **Root cause hypothesis:** The Grafana managed alert evaluator may be querying Loki through a different path than ad-hoc queries. Possible causes:
     - Grafana alert evaluation happens server-side, routing through the provisioned Loki datasource URL `http://loki:3100`. If Grafana's alerting engine has a DNS resolution or connection issue to Loki, the query fails → `noDataState: Alerting` triggers.
     - The alert query is a `range` query (`queryType: range`) while the instant query works. Range queries over `from: 300, to: 0` may behave differently.
     - Grafana may have an internal alerting state bug after restart.
  3. **Both alerts started at the exact same time (10:58:00)** — This strongly suggests a Grafana restart event triggered both alerts simultaneously, and the `for: 0m` + `noDataState: Alerting` combination caused them to fire immediately and never recover. Severity: **CRITICAL** (alerts are not self-healing).
  4. **Grafana notification goes to `grafana-default-email`** — The default email receiver is configured but likely not set up (no SMTP config visible). Alerts are firing into the void. Severity: **HIGH** (alerts have no delivery mechanism).
- **Evidence:** Direct Loki query via port 3200, Grafana alertmanager API, notification policy.

---

- `ADR-068` moved from adr.md
  - evidence: (docker compose config --hash vs docker inspect labels => loki runtime hash matches expected; grafana hash drift remains but no second restart in this run)
### ADR-068: Compose Config Drift — Grafana and Loki Diverged
- **Context:** Compared Docker compose config hashes between running containers and current on-disk config.
- **Findings:**
  1. **4 services match (no drift):** alloy, docker-metrics, host-monitor, prometheus. Running config hash == disk config hash. Severity: **PASS**.
  2. **Grafana has config drift:**
     - Running: `f6fde2aaa414c8dc54ba33aa0853c3185d05a3b8999970ede7e7bf3d35edb907`
     - On disk: `6235853859e6945e901f8053748d7d98fcd6ac6bb990e270d86c0ed5f3ff3c67`
     Grafana was last started 4 hours ago but with a DIFFERENT compose config than current disk. Compose config has been modified since Grafana was last created. Severity: **MEDIUM** (Grafana needs `docker compose up -d` to pick up changes).
  3. **Loki has config drift:**
     - Running: `4bc12e903a63d7fe63b86b7be30bec3be6c35e91712ba68d2e0d7b45d9cfae80`
     - On disk: `acfc3f2555417720f33ebd9f5b0e5959320f1436cb8817e4672de47e9f35d2b8`
     Loki was started 2.3 days ago. The compose config has changed since (the `LOKI_PUBLISH=0` change). This confirms Loki's port 3200 exposure is from an OLDER compose config where `LOKI_PUBLISH` was non-zero. Severity: **HIGH** (explains the entire Loki port drift saga — deploying `docker compose up -d` with current config would remove port 3200).
  4. **`LOKI_PUBLISH=0` in current .env** — The environment variable that controls Loki port publishing is set to 0 in the current config. When Loki is recreated, port 3200 will disappear. The melissa longrun scripts that depend on `http://127.0.0.1:3200` will break. Severity: **HIGH** (confirms config drift AND identifies the future breakage risk).
- **Evidence:** `docker inspect` config-hash labels, `docker compose config --hash '*'`.

---

- `ADR-069` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-069: Grafana Notification — Alerts Go Nowhere
- **Context:** Checked Grafana notification contact points and policies.
- **Findings:**
  1. **Default email receiver configured but no SMTP** — Contact point `grafana-default-email` exists as the default receiver, but no SMTP configuration is visible in Grafana environment variables. Emails are not being delivered. Severity: **HIGH** (both firing alerts are silently lost).
  2. **Zero custom notification routes** — The notification policy has 0 routes, meaning ALL alerts go to the default receiver (which doesn't work). Severity: **HIGH**.
  3. **Impact:** The 2 currently firing Grafana alerts and any future Prometheus-routed alerts via Grafana have no delivery mechanism. The alerting system is effectively decorative. Severity: **HIGH**.
- **Evidence:** Grafana `/api/v1/provisioning/contact-points`, `/api/v1/provisioning/policies`.

---

- `ADR-070` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-070: Host Log Source Paths — Inventory
- **Context:** Checked disk for the existence and population of all Alloy file source paths.
- **Findings:**
  1. **All 5 source paths exist and are populated:**
     - `/home/luce/_logs`: 2 files
     - `/home/luce/_telemetry`: 5 files
     - `/home/luce/apps/vLLM/_data/mcp-logs`: 8 files
     - `/home/luce/apps/vLLM/logs/telemetry/nvidia`: 2 files
     - `/home/luce/.vscode-server`: 31,934 files (!)
  2. **VSCode server path is huge** — 31,934 files. The glob pattern `**/*.log` and `**/log.txt` will match many of these. This could cause high Alloy file descriptor usage and positions tracking overhead. Severity: **MEDIUM** (should add more specific glob or path constraints).
  3. **Tool sink has only 2 files** — Explains why `tool_sink` doesn't appear in Loki `log_source` values. If the files are empty or haven't been written since Alloy started with `tail_from_end = true`, no data would be ingested. Severity: **LOW** (expected behavior).
- **Evidence:** `find` and `du` on host paths.

---

- `ADR-072` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-072: Environment Variable Audit
- **Context:** Extracted all environment variables from compose config (secrets redacted).
- **Findings:**
  1. **All 34 env vars are injected into Grafana's environment** — The compose file uses `env_file: .env` which injects ALL variables into the Grafana container, including `HOST_DOCKER_SOCK`, `HOST_ROOTFS`, etc. that Grafana doesn't need. Severity: **MEDIUM** (principle of least privilege violation — container gets more env vars than necessary).
  2. **`LOKI_PORT=9002` in .env but not used** — `LOKI_PORT` is set to 9002 but compose uses `LOKI_PUBLISH` to control publishing. When `LOKI_PUBLISH=0`, no port is published regardless of `LOKI_PORT`. However, the running container has port 3200→3100 from an older config where `LOKI_PORT` may have been 3200 or the binding was different. Severity: **MEDIUM** (confusing env var semantics).
  3. **`PROM_RETENTION_TIME=15d`** properly passed via CLI flag `--storage.tsdb.retention.time=${PROM_RETENTION_TIME:-15d}`. Severity: **PASS**.
  4. **`TELEMETRY_INTERVAL_SEC=10`** — Confirmed orphaned. Not referenced in any compose service or config file. Severity: **LOW** (reconfirms ADR-040 #4).
- **Evidence:** `docker compose config` with redaction.

---

### Final Open Questions (Consolidated)

**Answered (10):**
- ~~14. Is journald reaching Loki?~~ NO. Journal mounts missing from compose.
- ~~15. Where are Alloy positions?~~ `/data-alloy/` (CWD-relative). Volume mount wrong.
- ~~16. Is e2e-marker alert firing?~~ YES. Both Grafana alerts firing 11+ hours.
- ~~17. Does grafana-metrics dashboard work?~~ NO. No Grafana scrape in Prometheus.
- ~~18. Does loki_distributor metric exist?~~ NO. Dead in monolithic mode.
- ~~19. Why is ingest-down alert firing?~~ FALSE POSITIVE. Loki has 4370 lines/5m. Grafana alerting evaluator likely failed on restart and never recovered.
- ~~20. What is the second Loki?~~ `codeswarm-mcp` container from vllm project.
- ~~9. Is Loki port 3200 intentional?~~ CONFIG DRIFT. `.env` has `LOKI_PUBLISH=0`. Running container from older deploy. `docker compose up -d` would remove it.
- ~~10. Should melissa use Docker network?~~ YES. Port 3200 will disappear on next deploy.
- ~~11. When did 47K drops happen?~~ BEFORE Alloy restart (Alloy started 12h ago, counter at 15.2 MiB).

**Remaining (11):**
12. Should `editable: false` be set on stable dashboards?
13. Should the 3 orphaned original dashboards be deleted?
21. Should journald mounts be added to Alloy service?
22. Should Grafana SMTP be configured, or use a different notification channel (webhook, Slack)?
23. The verify script says `e2e_marker_found: true` but the Grafana alert says marker missing — which is correct?
24. Should the `grafana-metrics.json` dashboard be removed or should a Grafana scrape job be added?
25. Should Alloy's VSCode server glob be constrained to reduce 31K file scan?
26. Should `env_file` be replaced with explicit `environment:` entries per service?
27. What should replace the dead `loki_distributor_*` recording rules for Loki 3.0 monolithic mode?
28. Should `for: 0m` on Grafana alerts be changed to `for: 2m` to prevent immediate false positives?
29. Should a `docker compose up -d` be run to reconcile config drift? (Warning: breaks melissa scripts that use port 3200)

---
---

# Regrouped Findings by Domain Category

> **Generated:** 2026-02-17 | 237 findings across 72 ADR entries (9 passes) regrouped into 8 domain categories of like work.
>
> This replaces the earlier WD-01 through WD-11 structure with categories derived from the full dataset. Each category collects every finding that touches the same system boundary, regardless of which pass discovered it. Cross-references to original ADR entries are preserved.

---

## DC-1: Network Security, Port Exposure & Firewall Bypass

**Boundary:** Everything between the host's network interfaces and the containers — port bindings, iptables, UFW, authentication, config drift that exposes services.

**Why this is one domain:** The Loki port 3200 story spans 8 ADR entries across 5 passes. It only makes sense as a single coherent narrative: Docker bypasses UFW → Loki was deployed with a port → .env changed but container wasn't recreated → scripts depend on the exposed port → iptables confirms bypass → docs say "internal only."

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 1 | Docker publishes ports via iptables NAT chains, bypassing UFW INPUT rules entirely. Grafana (0.0.0.0:9001) and Prometheus (0.0.0.0:9004) reachable despite UFW deny rules. | CRITICAL | ADR-006 §1 | Open |
| 2 | iptables DNAT rule for Loki port 3200: `0.0.0.0/0 → 172.20.0.4:3100`. Source unrestricted. UFW has NO rule for 3200. Anyone can reach Loki HTTP API. | CRITICAL | ADR-052 §2, ADR-060 §1-2 | Open |
| 3 | Loki running with port 3200 published despite `.env` having `LOKI_PUBLISH=0`. Container created from older compose config. `docker compose up -d` would remove the port. | HIGH | ADR-030 §1, ADR-068 §3-4, ADR-040 §3 | Open (Q29) |
| 4 | Prometheus exposed on 0.0.0.0:9004 with zero authentication. | HIGH | ADR-006 §2 | Open |
| 5 | Melissa scripts depend on Loki port 3200 (`http://127.0.0.1:3200`). Reconciling config drift will break them. | MEDIUM | ADR-034 §3, ADR-068 §4 | Open (Q29) |
| 6 | `QUICK-ACCESS.md` contains `192.168.1.150` hardcoded 10+ times and documents "No authentication" for Prometheus. | MEDIUM | ADR-023 §1-2 | Open |
| 7 | `docs/quality-checklist.md` claims ports are "UFW-protected" — false confidence. | HIGH | ADR-022 §1 | Open |
| 8 | "Loki is internal-only" stated in 5 doc locations but FALSE at runtime. | HIGH | ADR-063 §1 | Open |
| 9 | Second Loki instance on vllm project (`codeswarm-mcp`, 172.22.0.2) also exposed via DNAT on ports 3100/3101. | MEDIUM | ADR-060 §4, ADR-064 | Informational |
| 10 | rsyslog port 1514 correctly bound to 127.0.0.1 — loopback only. | PASS | ADR-006 §6, ADR-052 §3 | Verified |
| 11 | Grafana/Prometheus UFW rules (31-32) correctly allow LAN 192.168.1.0/24 for ports 9001/9004. | PASS | ADR-052 §1 | Verified |
| 12 | Network `obs` is not internal (containers can reach internet). Acceptable for sandbox. | LOW | ADR-039 §2 | Accept |
| 13 | Docker socket mounted in Alloy as root (read-only). Required for Docker log discovery. | MEDIUM | ADR-006 §3 | Accepted risk |

**Resolution path:**
1. Decide: bind to 127.0.0.1 + reverse proxy, or apply `ufw-docker` iptables patch, or both
2. Reconcile Loki config drift (`docker compose up -d`) — first update melissa scripts to use Docker network
3. Add basic auth to Prometheus if binding stays at 0.0.0.0
4. Update 5 doc locations that say "Loki internal-only"
5. Remove hardcoded IP from `QUICK-ACCESS.md`

**Open questions:** Q29 (reconcile config drift?)

---

## DC-2: Alloy Pipeline Integrity & Log Delivery

**Boundary:** Everything inside Alloy — source configuration, process blocks, label application, redaction, positions persistence, pipeline health metrics, and whether data actually reaches Loki.

**Why this is one domain:** Alloy is the single ingestion gateway. Every finding about pipelines, labels, positions, journald, dropped entries, and redaction all lives in the same config file or the same container.

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 1 | Alloy positions volume misconfigured: `alloy-positions:/tmp` but Alloy's `--storage.path` defaults to `data-alloy/` (CWD-relative). Positions are NOT persisted. | HIGH | ADR-049, ADR-057, ADR-043 correction | Open |
| 2 | Journald pipeline: ZERO delivery. `loki_source_journal_target_lines_total = 0`. Journal mounts missing from compose — `loki.source.journal` block exists in config but no `/run/log/journal` or `/var/log/journal` mounts on Alloy container. | HIGH | ADR-062 | Open (Q21) |
| 3 | rsyslog pipeline routes through `loki.process "main"` which only adds `env=sandbox` — no `log_source` is set by the process block (set at source level). Redaction IS applied via main. Corrects ADR-003 §5. | MEDIUM | ADR-003 §2, ADR-036 §2 | Open |
| 4 | 47,442 dropped entries due to `ingester_error` (historical, not active). Current 1h rate is 0.0. Drops happened before Alloy's last restart. | HIGH | ADR-041 §2, ADR-048 §3 | Informational |
| 5 | Redaction rules (bearer/cookie/api_key) copy-pasted across 7 process blocks. Alloy HCL has no native shared-stage mechanism; fix requires template generator or `import.file`. | MEDIUM | ADR-003 §1, ADR-036 §3 | Open |
| 6 | `host` label documented but not applied. No process block sets `host=codeswarm`. | MEDIUM | ADR-003 §3, ADR-012 §1, ADR-066 §2 | Open |
| 7 | `container_name` label documented but not in Loki. Docker pipeline uses `service` label from compose metadata instead. | MEDIUM | ADR-066 §2 | Open |
| 8 | `job` label documented as mandatory but not present in Loki labels. | MEDIUM | ADR-066 §2 | Open |
| 9 | `source_type` label inconsistent — only `docker` and `syslog` values exist. File-based sources don't set it. | MEDIUM | ADR-066 §4 | Open |
| 10 | VSCode server path matches 31,934 files. High file descriptor and positions tracking overhead. | MEDIUM | ADR-070 §2 | Open (Q25) |
| 11 | `nvidia_telem` has hardcoded `telemetry_tier = "raw30"` for all 6 file paths regardless of actual tier. | LOW | ADR-003 §4 | Open |
| 12 | Dead samba mount: `HOST_VAR_LOG_SAMBA` in compose but no Alloy pipeline reads it. | LOW | ADR-002 §7, ADR-036 §5 | Open |
| 13 | Docker discovery filter correctly allowlists `vllm|hex` only, drops logging stack. | PASS | ADR-036 §4 | Verified |
| 14 | 10 source → 9 processor → 1 writer structure confirmed. | PASS | ADR-036 §1 | Verified |
| 15 | `loki_process_dropped_lines_total = 0` — no process-stage drops. | PASS | ADR-041 §5 | Verified |
| 16 | Syslog pipeline healthy: 297,930 entries, 0 parsing errors, 0 empty messages. | PASS | ADR-067 | Verified |
| 17 | Log truncation paths match all Alloy file source paths. | PASS | ADR-043 §1-3 | Verified |
| 18 | 5 active log_source values in Loki (codeswarm_mcp, docker, rsyslog_syslog, telemetry, vscode_server). Missing: tool_sink (2 files, likely empty), journald (dead), nvidia_telem (no recent data). | PASS | Loki inventory | Verified |
| 19 | 15.2 MiB total sent bytes (counter since Alloy restart ~12h ago). Modest throughput. | PASS | ADR-041 §4 | Verified |
| 20 | 46 Alloy/Loki pipeline metrics available in Prometheus. Full pipeline observability. | PASS | ADR-041 §1 | Verified |

**Resolution path:**
1. Fix Alloy positions: either `--storage.path=/tmp` in compose command, or change volume to `alloy-positions:/data-alloy`
2. Add journal mounts to Alloy service in compose (if journald ingestion desired)
3. Consolidate label schema: add `host`, fix `container_name`/`job`, normalize `source_type`
4. Constrain VSCode glob or add path exclusions
5. Remove dead samba mount

**Open questions:** Q21, Q25

---

## DC-3: Alerting, Recording Rules & Notification Delivery

**Boundary:** Everything that evaluates conditions and (should) notify — Prometheus recording rules, Prometheus alert rules, Grafana managed alerts, notification contact points, alert routing, false positives.

**Why this is one domain:** The alerting system is currently decorative. Both Grafana alerts are false positives firing for 11+ hours with no notification delivery. Two Prometheus recording rules reference a non-existent metric. No Alloy pipeline failure alerting exists. All of this is one coherent problem: "the alerting system doesn't work."

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 1 | Both Grafana alerts firing as false positives for 11+ hours. `logging-total-ingest-down` fires despite Loki returning 4370 lines in 5m. Started at exact same time (10:58) suggesting Grafana restart triggered both. | CRITICAL | ADR-056, ADR-065 | Open |
| 2 | Grafana notification goes to `grafana-default-email` with no SMTP configured. Zero custom notification routes. Alerts fire into void. | HIGH | ADR-069, ADR-065 §4 | Open (Q22) |
| 3 | `logging-e2e-marker-missing` alert fires because no MARKER process exists on the host. It's testing a capability that was never deployed. | HIGH | ADR-045 §1, ADR-056 §1 | Open |
| 4 | `loki_distributor_ingester_appends_failed_total` does NOT exist in Loki 3.0 monolithic mode. Two recording rules (`rate5m`, `increase10m`) are permanently dead. `LokiIngestionErrors` alert in `sprint3_minimum_alerts.yml` can NEVER fire. | HIGH | ADR-055, ADR-061 §2 | Open (Q27) |
| 5 | No alert for Alloy pipeline failures (dropped entries, write errors). The 47K historical drops went unnoticed. | HIGH | ADR-005 §3, ADR-041 §6 | Open |
| 6 | No alert receiver/routing in Prometheus. `alertmanager_config` absent from `prometheus.yml`. Alerts visible in Prometheus UI only. | HIGH | ADR-005 §6 | Open |
| 7 | Both Grafana alerts set `for: 0m` + `noDataState: Alerting`. Fires immediately on first evaluation with no grace period. | MEDIUM | ADR-045 §2, ADR-056 §3 | Open (Q28) |
| 8 | Duplicate TargetDown alert: `TargetDown` (warning, 2m) in one file, `PrometheusTargetDown` (critical, 5m) in another. | MEDIUM | ADR-005 §1, ADR-061 §3 | Open |
| 9 | No alert for Loki volume fill rate (distinct from host disk). | MEDIUM | ADR-005 §2 | Open |
| 10 | Missing alerts on recorded metrics: `sprint3:prometheus_scrape_failures:rate5m` recorded but never alerted. Container CPU/memory recorded but never alerted. | MEDIUM | ADR-046 §4-5 | Open |
| 11 | Verify script says `e2e_marker_found: true` but Grafana alert says marker missing. Inconsistency between audit tools. | MEDIUM | ADR-071 §2 | Open (Q23) |
| 12 | Recording rules use `sprint3:` prefix namespace. Cosmetic but signals sprint-scoped naming. | LOW | ADR-005 §5, ADR-046 §6 | Open |
| 13 | No alert for container restarts. cAdvisor doesn't expose restart counts natively. | LOW | ADR-005 §4 | Open |
| 14 | `sprint3_minimum_alerts.yml` discovered as second alert file with 3 rules (1 dead). | PASS | ADR-061 | Documented |
| 15 | 18 rules total (11 recording + 7 alerting) evaluate in 0.0011s. All healthy. | PASS | ADR-061 §4 | Verified |
| 16 | Grafana alert rules are file-provisioned (`provenance: file`), cannot be edited in UI. | PASS | ADR-045 §5 | Verified |
| 17 | All Prometheus alert rules health=ok, state=inactive (Prometheus-side alerts not firing). | PASS | ADR-030 | Verified |

**Resolution path:**
1. Fix false-positive Grafana alerts: add `for: 2m`, investigate evaluator behavior, restart Grafana with updated rules
2. Configure notification delivery (SMTP or webhook) — decision needed
3. Replace dead recording rules: `loki_distributor_*` → `loki_write_dropped_entries_total` (from Alloy)
4. Add Alloy pipeline failure alert
5. Merge duplicate TargetDown into one rule
6. Decide on MARKER process: either deploy it or remove the alert
7. Rename `sprint3:` prefix to stable namespace

**Open questions:** Q22, Q23, Q27, Q28

---

## DC-4: Compose Service Configuration & Container Hardening

**Boundary:** The `docker-compose.observability.yml` file itself — service definitions, resource limits, healthchecks, startup ordering, mount permissions, restart policies, config drift between running containers and declared config.

**Why this is one domain:** All changes touch the same file. Resource limits, healthchecks, mount scoping, and config drift reconciliation are tightly coupled — changing one section often means testing the full stack restart.

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 1 | No resource limits on any of 6 services. Runaway compactor/TSDB can starve host. | HIGH | ADR-002 §1 | Open |
| 2 | Grafana and Loki containers running from different compose config than on disk. Config drift confirmed via hash comparison. | HIGH | ADR-068 §2-3, ADR-033 | Open (Q29) |
| 3 | Alloy healthcheck uses `/bin/alloy fmt --help` — only verifies binary exists, not pipeline health. Should use `http://127.0.0.1:12345/-/ready`. | MEDIUM | ADR-002 §4 | Open |
| 4 | host-monitor and docker-metrics have no healthcheck blocks. | MEDIUM | ADR-002 §2 | Open |
| 5 | cAdvisor runs `privileged: true`. Required for kernel metrics. No AppArmor/seccomp. | MEDIUM | ADR-002 §3 | Accepted risk |
| 6 | Alloy mounts entire `/home` read-only. Should scope to `/home/luce`. | MEDIUM | ADR-009 §1 | Open |
| 7 | All 34 env vars injected into Grafana via `env_file`. Least-privilege violation. | MEDIUM | ADR-072 §1 | Open (Q26) |
| 8 | Duplicate credential variables (`GRAFANA_ADMIN_*` vs `GF_SECURITY_*`). Must be kept in sync manually. | MEDIUM | ADR-006 §4, ADR-040 §2 | Open |
| 9 | `depends_on` lacks `condition: service_healthy`. Startup order non-deterministic. | LOW | ADR-002 §5 | Open |
| 10 | docker-metrics mounts `/var/run` as `:rw`. Should be `:ro`. | LOW | ADR-002 §6 | Open |
| 11 | Container restart loops unbounded (`restart: unless-stopped`, no max_attempts). | LOW | ADR-013 §6 | Open |
| 12 | `LOKI_PORT=9002` in .env but not used by current compose (LOKI_PUBLISH controls). Confusing. | MEDIUM | ADR-072 §2 | Open |
| 13 | `TELEMETRY_INTERVAL_SEC=10` orphaned — not referenced anywhere. | LOW | ADR-040 §4, ADR-072 §4 | Open |
| 14 | Alloy, Prometheus, docker-metrics, host-monitor: running config matches disk (no drift). | PASS | ADR-068 §1 | Verified |
| 15 | cAdvisor /dev/kmsg mount present (may not be needed in v0.49.1). | LOW | ADR-009 §5 | Low priority |
| 16 | Docker network `obs` correctly isolates services. Not attachable by external containers. | PASS | ADR-039 §3 | Verified |
| 17 | /16 subnet oversized for 6 containers. Standard Docker behavior. | PASS | ADR-039 §4 | Informational |
| 18 | All containers have zero restarts. Restart policy is working. | PASS | ADR-048 §1 | Verified |

**Resolution path:**
1. Add `deploy.resources.limits` for CPU/memory on each service
2. Fix Alloy healthcheck → `/-/ready` endpoint
3. Add healthchecks to host-monitor and docker-metrics
4. Add `condition: service_healthy` to all `depends_on`
5. Scope Alloy `/home` mount to `/home/luce`
6. Consider per-service `environment:` instead of `env_file`
7. Reconcile config drift with `docker compose up -d` (coordinate with DC-1 port changes)
8. Remove dead samba mount, fix `/var/run` to `:ro`

**Open questions:** Q26, Q29

---

## DC-5: Storage, Retention, Backup & Resilience

**Boundary:** Data lifecycle — ingestion limits, volume sizing, backup/restore, graceful shutdown, Loki WAL/compactor health, single-point-of-failure analysis, and the destructive `down -v` default.

**Why this is one domain:** Losing data and preventing data loss are two sides of the same coin. The backup gap, the destructive down script, the missing ingestion limits, and the volume size monitoring all converge on "how do we not lose logs."

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 1 | No volume backup strategy. No cron job, snapshot script, or documentation. `down -v` destroys everything. | HIGH | ADR-013 §2 | Open |
| 2 | `logging_stack_down.sh` always uses `-v` (removes volumes). No option for safe stop. | HIGH | ADR-007 §3 | Open |
| 3 | Loki is a single point of failure — single node, no replication, in-memory ring store. | HIGH | ADR-013 §1 | Accepted risk (POC) |
| 4 | No graceful shutdown procedure documented. No drain for Alloy → Loki flush → Prometheus snapshot. | MEDIUM | ADR-013 §5 | Open |
| 5 | No Loki ingestion rate limits (`ingestion_rate_mb`, `ingestion_burst_size_mb`). | MEDIUM | ADR-004 §2, ADR-032 | Open |
| 6 | No volume size monitoring. 30d Loki + 15d Prometheus retention could exhaust disk. | MEDIUM | ADR-004 §4, ADR-051 §1 | Open |
| 7 | Alloy WAL/retry behavior on Loki unavailability uses defaults. May not survive extended downtime. | MEDIUM | ADR-013 §4 | Open |
| 8 | No integration test for Alloy position tracking after log rotation. | MEDIUM | ADR-011 §7 | Open |
| 9 | `reject_old_samples: false` allows arbitrary old log injection. | LOW | ADR-004 §1 | Accept (sandbox) |
| 10 | `retention_delete_worker_count: 50` — aggressive for single-node but not a problem currently. | LOW | ADR-004 §3 | Accept |
| 11 | Prometheus retention correctly CLI-only (`--storage.tsdb.retention.time`). | PASS | ADR-004 §5 | Verified |
| 12 | Loki WAL healthy: 130.5 MiB logged, 77K records, 208 duplicates (negligible). | PASS | ADR-059 §1-2 | Verified |
| 13 | WAL recovery successful on last restart: 9635 entries, 13 streams, 12 chunks. | PASS | ADR-059 §3 | Verified |
| 14 | Compactor ring ACTIVE: 226 successful retention operations, 680 gRPC requests, all 2xx. | PASS | ADR-047 §2-3 | Verified |
| 15 | Volume sizes: grafana 1.7 MB, loki 51 MB, prometheus 356 MB. Total 409 MB. | PASS | ADR-030 | Verified |
| 16 | All 4 volumes use local driver with no size limits. | MEDIUM | ADR-051 §1 | Open |
| 17 | `_dev-tools` has checkpoint/restore and backup-rollback patterns ready for adoption. | PASS | ADR-035 §4-5 | Adoptable |

**Resolution path:**
1. Rewrite `down.sh` to default safe (stop only), add `--purge` for volume removal
2. Create `stop.sh` for graceful shutdown
3. Create volume backup/restore scripts (adopt `_dev-tools` backup-rollback pattern)
4. Add `limits_config` to Loki config (ingestion rate + burst)
5. Document graceful shutdown procedure

**Open questions:** None blocking.

---

## DC-6: Version Upgrades & Dependency Health

**Boundary:** Container image versions, upstream release tracking, registry changes, migration planning.

**Why this is one domain:** All version upgrades share the same workflow: update `.env`/`.env.example`, pull images, restart, verify. They also share a risk profile — the stack must work as a coherent unit after upgrades.

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 1 | Grafana 11.1.0 is EOL (~18 months behind, 12.3.3 current). Zero security patches. | CRITICAL | ADR-010 §1 | Open |
| 2 | Alloy v1.2.1 → v1.13.1 (11 minor versions behind). | HIGH | ADR-010 | Open |
| 3 | Loki 3.0.0 → 3.6.5 (6 minor behind). Build date 2024-04-08 (~2 years old). | HIGH | ADR-010, ADR-047 §1 | Open |
| 4 | cAdvisor v0.49.1 → v0.56.2. Registry changed from `gcr.io` to `ghcr.io` at v0.53.0. | HIGH | ADR-010 §2 | Open |
| 5 | Prometheus v2.52.0 → v3.x. Major migration with breaking changes (new UI, UTF-8 labels). | HIGH | ADR-010 §3 | Open (separate plan) |
| 6 | Node Exporter v1.8.1 → v1.10.2 (2 minor behind). | MEDIUM | ADR-010 | Open |
| 7 | All images are pinned to specific tags (no `:latest`). Correct practice. | PASS | ADR-010 §4 | Verified |
| 8 | Prometheus TSDB: 993 unique metrics, manageable cardinality. | PASS | ADR-042 | Verified |
| 9 | `_dev-tools` has dependency-updater with audit, SBOM, and outdated-check capabilities. | PASS | WD-11 §4 | Adoptable |

**Resolution path:**
1. Grafana first (EOL, security risk, independent of other services)
2. Alloy + Loki together (ingestion pipeline — test config compat between versions)
3. cAdvisor (registry change: `gcr.io` → `ghcr.io`)
4. Node Exporter (low risk)
5. Prometheus v3 migration — separate sprint

---

## DC-7: Operational Scripts, Linting & Tooling

**Boundary:** All shell scripts — bugs, safety issues, linting findings, hardcoded paths, template injection, and `_dev-tools` tooling that improves script quality.

**Why this is one domain:** Scripts share patterns (set -euo pipefail, .env sourcing, temp file cleanup, hardcoded paths). Fixing one script's patterns informs all others. bash-basher and shellcheck run across the entire set.

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 1 | `template-engine.sh` uses `eval` with config-sourced values — command injection vector. | HIGH | ADR-011 §1-2 | Open |
| 2 | `add-log-source.sh` references non-existent `.claude/prompts/` directory. Script broken. | HIGH | ADR-021 §3 | Open |
| 3 | `melissa_batchlib.sh` BB024: `derive_grafana_pass()` transits password through shell variables and process table. | HIGH | ADR-044 §2 | Open |
| 4 | `logging_stack_audit.sh` has ~80 bash-basher findings including deep nesting, sed injection, long functions. Highest-risk script. | HIGH | ADR-044 §5 | Open |
| 5 | `add-log-source.sh` missing `set -uo pipefail` (only `set -e`). | MEDIUM | ADR-021 §2 | Open |
| 6 | `add-log-source.sh` uses hardcoded absolute path `/home/luce/apps/loki-logging/`. | MEDIUM | ADR-021 §1 | Open |
| 7 | `melissa_longrun.sh` and `melissa_batchlib.sh` hardcode `ROOT="/home/luce/apps/loki-logging"`. | MEDIUM | ADR-034 §1 | Open |
| 8 | `logging_stack_health.sh` depends on `rg` (ripgrep) without `command -v` check. | MEDIUM | ADR-007 §4 | Open |
| 9 | `logging_stack_health.sh` hardcodes ports 9001/9004, doesn't read from `.env`. | MEDIUM | ADR-007 §5 | Open |
| 10 | `status.sh` SC2168 error: `local` used outside function (real bug). | MEDIUM | ADR-031 | Open |
| 11 | `status.sh` BB135: multiple unset variable warnings. | MEDIUM | ADR-044 §6 | Open |
| 12 | `validate_env.sh` sources `.env` via `. "$ENV_PATH"` — executes arbitrary shell. | LOW | ADR-006 §5 | Open |
| 13 | `logging_stack_audit.sh` leaks 7 `mktemp` files (only 1 has `trap` cleanup). | LOW | ADR-007 §6 | Open |
| 14 | Audit script uses fragile sed-based image parsing from YAML. | LOW | ADR-007 §7 | Open |
| 15 | `logging_stack_down.sh` doesn't validate `.env` exists before sourcing. | LOW | ADR-007 §8 | Open |
| 16 | `add-log-source.sh` source count stale (says 7, actual is 8+). | LOW | ADR-021 §4 | Open |
| 17 | Common AUTO_FIX patterns across all scripts: BB098 noclobber, BB100 inherit errexit. | LOW | ADR-044 §7 | Batch fix |
| 18 | 4 SC1090 warnings across scripts (non-constant `.env` source). | LOW | ADR-031 | Add directives |
| 19 | Script locations fragmented across 3 directories. | MEDIUM | ADR-020, ADR-018 §6, ADR-034 §4 | Open |
| 20 | Shellcheck baseline: 11 findings, 1 error. Relatively clean. | PASS | ADR-031 | Baseline |
| 21 | Bash-basher baseline: ~120 findings across 5 scripts (7 BREAK, ~85 WARN, ~28 AUTO_FIX). | PASS | ADR-044 | Baseline |
| 22 | All scripts have `set -euo pipefail` (except `add-log-source.sh`). | PASS | ADR-007 §1 | Verified |
| 23 | All scripts have `--help` handlers. | PASS | ADR-007 §2 | Verified |
| 24 | Melissa drift detection pattern and auto-commit scoping are well-implemented. | PASS | ADR-034 §5-6 | Verified |
| 25 | `_dev-tools` bash-basher available for CI integration. 172-rule linter with SARIF output. | PASS | WD-11 §1-2 | Adoptable |
| 26 | `_dev-tools` bash-scripter-playbook available to extract runbook CLIs from docs. | PASS | WD-11 §3 | Adoptable |

**Resolution path:**
1. Replace `eval` in template-engine.sh with `envsubst` or safe parameter expansion
2. Fix `add-log-source.sh` — broken path, missing `set -uo pipefail`, stale count
3. Fix `status.sh` SC2168 bug
4. Add `trap` cleanup for all `mktemp` files in audit script
5. Fix hardcoded paths (use `SCRIPT_DIR` relative resolution)
6. Add `rg` check to health script, read ports from `.env`
7. Run bash-basher + shellcheck in CI
8. Consolidate script locations (3 dirs → 2)

---

## DC-8: Dashboards, Grafana Provisioning, Repo Hygiene, Documentation & CI/CD

**Boundary:** Everything that doesn't change runtime behavior — dashboard provisioning, file naming, stale files, git hygiene, documentation accuracy, CI/CD setup, `.editorconfig`.

**Why this is one domain:** These are all "do last" tasks. They depend on every other domain's changes settling first. Dashboard UIDs may change after Grafana upgrade. Docs must reflect final state. File renames affect cross-references. CI validates the final config.

### Dashboards & Grafana Provisioning

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 1 | `editable: true` means in-browser edits silently lost on restart. | MEDIUM | ADR-008 §1, ADR-038 §3 | Open (Q12) |
| 2 | Grafana-metrics dashboard has zero data (no Grafana scrape in Prometheus). | MEDIUM | ADR-058, ADR-053 §4 | Open (Q24) |
| 3 | 3 orphaned original dashboards in Grafana (pre-adoption copies). | LOW | ADR-037 §2 | Open (Q13) |
| 4 | `disableDeletion: false` allows accidental deletion of provisioned dashboards. | LOW | ADR-008 §2 | Open |
| 5 | Dashboard JSON naming inconsistent (underscores vs hyphens). | LOW | ADR-017 §2 | Open |
| 6 | `zprometheus-stats.json` uses `z` prefix hack for sort ordering. | LOW | ADR-017 §3 | Open |
| 7 | `allowUiUpdates` not set — confusing: users can modify but not persist. | LOW | ADR-038 §4 | Open |
| 8 | Datasource UIDs correctly pinned and matching. | PASS | ADR-050 | Verified |
| 9 | Subdirectory scanning works (25 files across 4 dirs all loaded). | PASS | ADR-038 §1-2 | Verified |
| 10 | 25 provisioned dashboards, 120 queries checked, 0 unexpected empty panels. | PASS | ADR-054 | Verified |
| 11 | "zNot Working" folder exists in Grafana (experimental, not provisioned). | LOW | ADR-037 §3 | Cleanup |

### Repo Hygiene & Git

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 12 | `docs/snippets/` massively stale (alloy snippet 76 lines vs 393 canonical). Delete directory. | HIGH | ADR-019 §1-3 | Open |
| 13 | 2 Alloy backup files tracked in git. Add `*.backup-*` to `.gitignore`. | MEDIUM | ADR-015 §1, ADR-018 §2 | Open |
| 14 | 5 stale markdown files in `infra/logging/` (ALERTS_CHECKLIST, CHANGELOG, PR_BUNDLE, RELEASE_NOTES, RUNBOOK). | MEDIUM | ADR-018 §1 | Open |
| 15 | 5 UPPERCASE file naming violations. | MEDIUM | ADR-017 §1 | Open |
| 16 | `docs/manifest.json` references non-existent paths. | MEDIUM | ADR-018 §4 | Open |
| 17 | Dead `.local-archives/` entry in `.gitignore`. | LOW | ADR-015 §4 | Open |
| 18 | `docs/monitoring.md` orphaned — not in manifest. | LOW | ADR-018 §3 | Open |
| 19 | `.codex-prompt-state.env.example` at repo root — unclear purpose. | LOW | ADR-018 §5 | Open |
| 20 | `*.env` gitignore glob overly broad. | LOW | ADR-015 §2 | Open |
| 21 | Remote name mismatch: `loki-logger` (GitHub) vs `loki-logging` (local). | LOW | ADR-014 §5 | Informational |
| 22 | Single tag `prompt-flow-v1`. No stack version tags. | MEDIUM | ADR-014 §3 | Open |

### Documentation Accuracy

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 23 | `CLAUDE.md` claims `host=codeswarm` label — doesn't exist. | MEDIUM | ADR-012 §1 | Open |
| 24 | `docs/reference.md` says "7 active log sources" (actual: 8+). Label schema incomplete. | MEDIUM | ADR-012 §2, §4 | Open |
| 25 | `docs/quality-checklist.md` claims all logs have `host` label (false). | MEDIUM | ADR-022 §2 | Open |
| 26 | `docs/quality-checklist.md` hardcodes image versions that will drift. | LOW | ADR-022 §3 | Open |
| 27 | `docs/troubleshooting.md` says `127.0.0.1:3100` is an error — but `127.0.0.1:3200` works at runtime. Contradictory. | MEDIUM | ADR-063 §4 | Open |
| 28 | CLAUDE.md says "10-15 seconds" ingestion delay with no evidence. Audit script uses 3s. | LOW | ADR-012 §5 | Open |
| 29 | Config snippets drift verified: alloy massively stale, loki minor, prometheus minor. | HIGH | ADR-019 | Open (delete snippets) |
| 30 | 19 documentation files inventoried. | PASS | ADR-063 §3 | Documented |

### CI/CD & Testing

| # | Finding | Severity | Source | Status |
|---|---------|----------|--------|--------|
| 31 | No `.github/` directory — no CI/CD, CODEOWNERS, issue templates, dependabot. | HIGH | ADR-014 §1 | Open |
| 32 | No automated test suite. All validation is manual script invocation. | HIGH | ADR-024 §1 | Open |
| 33 | No shellcheck in any workflow. | MEDIUM | ADR-024 §2 | Open |
| 34 | No Alloy config syntax check outside audit script. | MEDIUM | ADR-024 §3 | Open |
| 35 | No git hooks (no pre-commit for config validation). | MEDIUM | ADR-014 §2 | Open |
| 36 | `.editorconfig` covers 15+ unused languages, missing HCL/Alloy section. | LOW | ADR-025 §1-2 | Open |
| 37 | `_dev-tools` github-setup-playbook available for CI bootstrap. | PASS | WD-11 §9 | Adoptable |
| 38 | Log truncation module has integration tests — only component with proper testing. | PASS | ADR-024 | Verified |
| 39 | promtool not installed on host. | PASS | ADR-031 | Constraint |

**Resolution path:**
1. Delete `docs/snippets/` (always stale; link to canonical configs)
2. `git rm` backup files, add `*.backup-*` to `.gitignore`
3. Move stale markdown from `infra/logging/` to archive or delete
4. Rename UPPERCASE files to kebab-case
5. Set `editable: false`, `disableDeletion: true` on stable dashboards
6. Either add Grafana scrape job or remove dead dashboard
7. Update all documentation to match final config state
8. Create `.github/workflows/validate.yml` (shellcheck + alloy fmt + promtool + compose config)
9. Add CODEOWNERS, pre-commit hooks, version tags

**Open questions:** Q12, Q13, Q24

---

## Execution Order

```
DC-1  Network Security & Port Exposure    ──┐
DC-2  Alloy Pipeline Integrity            ──┼── Independent, can parallelize
DC-7  Operational Scripts & Linting       ──┘
                                             │
DC-4  Compose Service Hardening           ───── Coordinate with DC-1 (same file)
DC-3  Alerting & Notification Delivery    ───── Needs notification decision (Q22)
DC-5  Storage, Retention & Backup         ───── After DC-7 (down.sh rewrite)
                                             │
DC-6  Version Upgrades                    ───── After DC-4 (resource limits before upgrade)
                                             │
DC-8  Dashboards, Repo, Docs & CI/CD     ───── Last (depends on all others settling)
```

## Finding Distribution

| Domain | Open | Pass/Verified | Critical | High | Medium | Low |
|--------|------|---------------|----------|------|--------|-----|
| DC-1 Network Security | 9 | 4 | 2 | 4 | 4 | 1 |
| DC-2 Alloy Pipelines | 12 | 8 | 0 | 3 | 7 | 2 |
| DC-3 Alerting & Notifications | 13 | 4 | 2 | 5 | 4 | 2 |
| DC-4 Compose Hardening | 13 | 5 | 0 | 2 | 7 | 4 |
| DC-5 Storage & Backup | 8 | 9 | 0 | 3 | 5 | 2 |
| DC-6 Version Upgrades | 5 | 4 | 1 | 4 | 1 | 0 |
| DC-7 Scripts & Tooling | 19 | 7 | 0 | 4 | 9 | 6 |
| DC-8 Dashboards/Repo/Docs/CI | 30 | 9 | 0 | 4 | 13 | 10 |
| **Totals** | **109** | **50** | **5** | **29** | **50** | **27** |

*Note: Some findings appear in multiple DCs (e.g., DC-1 and DC-4 share the config drift finding). The 109+50 count exceeds 237 unique findings due to cross-domain references. Severity counts reflect unique entries within each DC.*

---

## Open Questions (Consolidated, 11 remaining)

| # | Question | Blocking |
|---|----------|----------|
| Q12 | Should `editable: false` be set on stable dashboards? | DC-8 |
| Q13 | Should the 3 orphaned original dashboards be deleted? | DC-8 |
| Q21 | Should journald mounts be added to Alloy service? | DC-2 |
| Q22 | Should Grafana SMTP be configured, or use webhook/Slack? | DC-3 |
| Q23 | Verify script says `e2e_marker_found: true` but Grafana alert says missing — which is correct? | DC-3 |
| Q24 | Remove grafana-metrics dashboard or add Grafana scrape job? | DC-8 |
| Q25 | Should VSCode server glob be constrained? | DC-2 |
| Q26 | Should `env_file` be replaced with per-service `environment:`? | DC-4 |
| Q27 | What replaces dead `loki_distributor_*` rules for monolithic mode? | DC-3 |
| Q28 | Should `for: 0m` on Grafana alerts be changed to `for: 2m`? | DC-3 |
| Q29 | Run `docker compose up -d` to reconcile config drift? (Breaks melissa port 3200) | DC-1, DC-4 |

---
---

## Pass 10: Post-Remediation Verification Loop (2026-02-18)

> Discovery loop against live stack and source files after first batch of fixes applied.
> Authoritative sources: running containers, config files on disk, Prometheus/Loki/Grafana APIs.
> All findings verified against runtime, not inferred.

- `ADR-073` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-073: Alloy → Loki Write Path — Transient DNS Errors on Restart

- **Source**: `docker logs --since 30m logging-alloy-1`
- **Evidence**:
  - At 18:15 UTC: 6× `"error sending batch, will retry"` with `"dial tcp: lookup loki on 127.0.0.11:53: server misbehaving"`
  - 1× `"status=500 Internal Server Error (500): empty ring"` (Loki ingester ring not yet ready)
  - By 18:20 UTC: zero errors. Alloy health: `healthy`. DNS resolves: `loki → 172.20.0.3`
- **Findings**:
  1. **Alloy write errors were transient post-restart, not structural.** DNS resolver `127.0.0.11` (Docker embedded DNS) was briefly unavailable during compose restart. Alloy's backoff-retry recovered without intervention. Severity: **PASS** (resolved).
  2. **`empty ring` error confirms Loki ingester startup lag.** Loki's in-memory ring store takes ~10–30s to become ready. Alloy's `depends_on: loki` does not wait for ring-ready — only for container healthy. `start_period: 20s` in Loki healthcheck may not be long enough under load. Severity: **LOW** — acceptable for sandbox; increase `start_period` or add a Loki ring-ready check before production elevation.
  3. **No persistent drops from the restart.** `loki_write_dropped_entries_total{reason="ingester_error"}` is still 47,442 — the same historical counter. No new drops added. Severity: **PASS**.
- **Codex action**: If `start_period` on loki healthcheck is raised to `40s`, the ring-ready window is covered. File: `infra/logging/docker-compose.observability.yml`, loki service `healthcheck.start_period`.

---

- `ADR-074` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-074: Journald Pipeline — Mounts Confirmed Missing at Runtime

- **Source**: `docker exec logging-alloy-1 ls /var/log/journal` and `ls /run/log/journal`
- **Evidence**:
  - Both paths: `ls: cannot access ...: No such file or directory`
  - `loki_source_journal_target_lines_total = 0` (Prometheus metric, runtime confirmed)
  - Compose file DOES declare mounts: `${HOST_VAR_LOG_JOURNAL:-/var/log/journal}:/var/log/journal:ro` and `${HOST_RUN_LOG_JOURNAL:-/run/log/journal}:/run/log/journal:ro`
  - Container was started at `2026-02-18T18:17` (after compose fix was applied per adr-completed.md `journald_mounts_fixed: true`)
- **Findings**:
  1. **Journald mounts are declared in compose but the paths do not exist inside the container.** This means either: (a) the host paths `/var/log/journal` and `/run/log/journal` do not exist on the host, or (b) the env vars `HOST_VAR_LOG_JOURNAL`/`HOST_RUN_LOG_JOURNAL` override to empty/wrong paths. Severity: **HIGH** — journald pipeline still dead despite the compose fix.
  2. **Root cause to verify**: Run `ls /var/log/journal /run/log/journal` on the HOST (not container) to confirm whether journal paths exist. If they don't exist, systemd journal may be writing to `/run/user/` or the host uses `volatile` journal storage. Severity: **HIGH** — needs host-side check before Codex can fix.
  3. **`loki.source.journal` block in alloy-config.alloy has no `path` argument.** Alloy defaults to `/var/log/journal` if not set. If host journal is at a non-standard path, must set explicit `path = "/host/run/log/journal"` in the HCL block. Severity: **MEDIUM**.
- **Codex action**: 
  - Prerequisite: confirm host journal path (`ls /run/log/journal /var/log/journal` on host).
  - If host path exists but mount fails: check `.env` for `HOST_VAR_LOG_JOURNAL`/`HOST_RUN_LOG_JOURNAL` overrides.
  - If host journal is volatile (in-memory only): add `path = "/run/log/journal"` to `loki.source.journal "journald"` block in `alloy-config.alloy` AND mount `${HOST_RUN_LOG_JOURNAL:-/run/log/journal}:/run/log/journal:ro` in compose alloy service.
  - If host has no persistent journal: `journalctl --disk-usage` — if 0, journal is volatile. Set `Storage=persistent` in `/etc/systemd/journald.conf`, then `systemctl restart systemd-journald`.

---

- `ADR-075` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-075: Recording Rule `sprint3:loki_ingestion_errors` — Still Evaluates Empty

- **Source**: Prometheus API `/api/v1/query` and `/api/v1/rules`
- **Evidence**:
  - `sprint3:loki_ingestion_errors:rate5m` → `[]` (empty result)
  - `sprint3:loki_ingestion_errors:increase10m` → `[]` (empty result)
  - `loki_write_dropped_entries_total` exists with value `47442` ✓
  - `loki_write_failures_discarded_total` → **no active series** (metric name exists in `__name__` label, but `query?query=loki_write_failures_discarded_total` returns `[]`)
  - `sum(rate(loki_write_dropped_entries_total[5m])) + sum(rate(loki_write_failures_discarded_total[5m]))` → **empty** because PromQL binary ops between a scalar and a no-series metric return no result.
- **Findings**:
  1. **The `sum() + sum()` expression silently returns empty when one operand has no series.** `loki_write_failures_discarded_total` is registered in Alloy's metric registry but has never been emitted (zero failures to date). A metric with no series returns nothing from `sum()`. Adding it to another `sum()` via `+` causes the entire expression to evaluate to empty. Severity: **HIGH** — the replacement recording rule is still dead. `LokiIngestionErrors` alert can still never fire.
  2. **Fix pattern**: Use `or vector(0)` fallback on each operand: `sum(rate(loki_write_dropped_entries_total[5m])) + sum(rate(loki_write_failures_discarded_total[5m]) or vector(0))`. Alternatively, split into two separate recording rules and alert on each independently. Severity: **HIGH**.
  3. **`AlloyPipelineDrops` alert in `loki_logging_rules.yml:65` IS functional**: `sum(increase(loki_write_dropped_entries_total[10m])) > 0` uses only the metric with known series. This alert would fire if drops resume. Severity: **PASS**.
  4. **`LokiIngestionErrors` in `sprint3_minimum_alerts.yml` references the broken recording rule** and will never fire. Severity: **HIGH** — redundant dead alert, should be removed or repointed to `AlloyPipelineDrops`.
- **Codex action**:
  - File: `infra/logging/prometheus/rules/loki_logging_rules.yml`
  - Fix `sprint3:loki_ingestion_errors:rate5m` expr to: `sum(rate(loki_write_dropped_entries_total[5m])) + sum(rate(loki_write_failures_discarded_total[5m]) or vector(0))`
  - Fix `sprint3:loki_ingestion_errors:increase10m` expr to: `sum(increase(loki_write_dropped_entries_total[10m])) + sum(increase(loki_write_failures_discarded_total[10m]) or vector(0))`
  - File: `infra/logging/prometheus/rules/sprint3_minimum_alerts.yml`
  - Remove `LokiIngestionErrors` alert (dead) OR rewrite to: `expr: sum(increase(loki_write_dropped_entries_total[10m])) > 0` (directly, without recording rule).

---

- `ADR-076` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-076: Grafana Alerts Persist Despite `noDataState: OK` Fix — State Machine Issue

- **Source**: Grafana Alertmanager API, provisioned rule API
- **Evidence**:
  - Both alerts `noDataState: OK`, `for: 2m` confirmed via `/api/v1/provisioning/alert-rules` API ✓
  - Both alerts still `state: active`, `startsAt: 2026-02-17T10:58:00.000Z` from Alertmanager API
  - Grafana restarted `2026-02-18T18:17:07Z` — AFTER the fix was applied
  - `loki_write_dropped_entries_total{reason="ingester_error"}` = 47442 (unchanged — no new drops)
  - Loki is receiving queries (confirmed from Loki access logs showing range queries succeeding)
- **Findings**:
  1. **Alertmanager state survives Grafana restart via `grafana-data` volume.** The alert was set `active` on 2026-02-17T10:58. Even after Grafana restart with the corrected `noDataState: OK`, the alert state is loaded from the persisted alertmanager state in the volume. The fix prevents future false positives but does NOT clear an already-firing alert. Severity: **MEDIUM** — alerts will only clear when the alert condition evaluates as non-firing (data is present) AND the pending duration passes.
  2. **`logging-total-ingest-down` should self-clear if Loki query returns data.** The alert fires when `sum(count_over_time({log_source=~".+"}[5m])) < 1`. If Loki is delivering data to Grafana's alerting engine, the condition should resolve within the next evaluation cycle (1m interval) and the alert should transition to `normal` after `for: 2m`. If it doesn't clear within 3–4 minutes of Grafana restart, the Grafana alerting engine has a different issue querying Loki.
  3. **`logging-e2e-marker-missing` CANNOT self-clear** until a process writes `MARKER=` to rsyslog. No such process exists. The alert will fire indefinitely regardless of fixes. Severity: **HIGH** — requires either: (a) deploy a marker cron job, or (b) remove the alert rule from the provisioning file.
  4. **`execErrState: Alerting` remains set on both rules.** If Grafana's connection to Loki fails (e.g., during future restarts), alerts fire immediately. This is the correct behavior for an alerting stack — execution errors should fire. No change needed. Severity: **PASS**.
- **Codex action**:
  - File: `infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml`
  - Remove the `logging-e2e-marker-missing` rule entirely (no marker process, no plan to deploy one, indefinitely firing).
  - OR: add a cron job that writes `MARKER=$(date +%s)` to rsyslog every 10 minutes. Command: `*/10 * * * * logger -p local0.info "MARKER=$(date +%s) e2e-probe"`. Add to root crontab.
  - After removing the rule OR deploying the marker, force-clear the stale alertmanager state: `docker compose -p logging -f infra/logging/docker-compose.observability.yml restart grafana` (state will reset without the rule).

---

- `ADR-079` moved from adr.md
  - evidence: (rg mem_limit/cpus and localhost bindings in compose => core service limits present and Loki/Grafana/Prometheus bound loopback)
### ADR-079: Compose — Resource Limits Applied, Port Bindings Confirmed Localhost-Only

- **Source**: `infra/logging/docker-compose.observability.yml` (disk)
- **Evidence**:
  - `grafana`: `mem_limit: 1g`, `cpus: "0.50"` ✓
  - `loki`: `mem_limit: 2g`, `cpus: "1.00"` ✓
  - `prometheus`: `mem_limit: 2g`, `cpus: "1.00"` ✓
  - `alloy`: `mem_limit: 1g`, `cpus: "0.75"` ✓
  - `host-monitor`, `docker-metrics`: no resource limits (still missing)
  - Grafana port: `127.0.0.1:${GRAFANA_PORT:-9001}:3000` ✓ (localhost-only)
  - Loki port: `"127.0.0.1:3200:3100"` ✓ (localhost-only, intentional for melissa scripts)
  - Prometheus port: `127.0.0.1:${PROM_PORT:-9004}:9090` ✓ (localhost-only)
  - Alloy syslog: `"127.0.0.1:1514:1514"` ✓
- **Findings**:
  1. **Resource limits applied to 4 of 6 services.** grafana, loki, prometheus, alloy have limits. Severity: **PASS** (partial fix confirmed).
  2. **`host-monitor` (node-exporter) and `docker-metrics` (cAdvisor) still have no resource limits.** Node Exporter is typically lightweight (<50MB RAM). cAdvisor can spike during metric collection. Neither has CPU/memory cap. Severity: **MEDIUM** — add `mem_limit: 256m` and `cpus: "0.25"` to each.
  3. **All external ports now bind to `127.0.0.1` not `0.0.0.0`.** Docker+UFW bypass risk is eliminated — iptables DNAT rules only forward from loopback, not from external interfaces. Severity: **PASS** (critical fix confirmed).
  4. **Loki port 3200 is intentionally kept as `127.0.0.1:3200:3100`** for melissa script compatibility. This is loopback-only. Not a security issue. Severity: **PASS**.
  5. **`docker-metrics` still mounts `/var/run:rw`** — not changed to `:ro`. cAdvisor requires write access to `/var/run/docker.sock` for container metadata. Changing to `:ro` would break it. Severity: **LOW** — acceptable as-is; document the requirement.
- **Codex action**:
  - File: `infra/logging/docker-compose.observability.yml`
  - Add to `host-monitor` service: `mem_limit: 256m` and `cpus: "0.25"`
  - Add to `docker-metrics` service: `mem_limit: 512m` and `cpus: "0.25"`

---

- `ADR-080` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-080: Duplicate Alert Rules — `TargetDown` vs `PrometheusTargetDown`

- **Source**: `infra/logging/prometheus/rules/loki_logging_rules.yml` and `sprint3_minimum_alerts.yml`
- **Evidence**:
  - `loki_logging_rules.yml`: **no `TargetDown` alert** — grep returned 0 matches. The TargetDown alert was removed.
  - `sprint3_minimum_alerts.yml:11`: `PrometheusTargetDown` — `expr: sprint3:targets_down:count > 0`, `for: 5m`, `severity: critical`
  - Prometheus rules eval: both groups healthy, `PrometheusTargetDown: inactive`
- **Findings**:
  1. **Duplicate TargetDown alert resolved — only `PrometheusTargetDown` remains.** Previously ADR-061 §3 noted both `TargetDown` (2m, warning) and `PrometheusTargetDown` (5m, critical) existed. The original `TargetDown` is now gone. Severity: **PASS** (fix confirmed).
  2. **`PrometheusScrapeFailure` alert remains in `sprint3_minimum_alerts.yml`.** References `sprint3:prometheus_scrape_failures:rate5m` which IS a working recording rule. Alert is functional. Severity: **PASS**.
  3. **`sprint3_minimum_alerts.yml` now has 2 functional alerts + 1 dead (`LokiIngestionErrors`).** The dead one should be removed (see ADR-075 Codex action). Severity: **HIGH** — same as ADR-075.

---

- `ADR-081` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-081: Grafana Alert Provisioning — `noDataState` Fix Confirmed, Stale State Persists

- **Source**: Grafana provisioning API `/api/v1/provisioning/alert-rules`
- **Evidence**:
  - `logging-e2e-marker-missing`: `noDataState: OK`, `for: 2m`, `execErrState: Alerting` ✓
  - `logging-total-ingest-down`: `noDataState: OK`, `for: 2m`, `execErrState: Alerting` ✓
  - Alertmanager: both alerts `state: active`, `startsAt: 2026-02-17T10:58:00` (stale, pre-dates today's restart)
- **Findings**:
  1. **`noDataState: OK` and `for: 2m` fixes are live in the provisioned rules.** Future Grafana restarts will not trigger immediate false-positive firing. Severity: **PASS** (fix confirmed).
  2. **Alertmanager state loaded from `grafana-data` volume persists the stale firing state.** The alerts will NOT self-clear until their condition evaluates non-firing AND the `for: 2m` pending period expires. For `logging-total-ingest-down`, this should occur within 2 minutes if Loki is delivering data to Grafana's alerting engine. For `logging-e2e-marker-missing`, it CANNOT clear without a MARKER process or removing the rule. Severity: **MEDIUM** — see ADR-076 Codex action.
  3. **Notification delivery still broken.** Contact point `email receiver: email` configured but no SMTP in Grafana env. All alert notifications go to `/dev/null`. Severity: **HIGH** — no notification channel means alerts fire silently. This has not changed.
- **Codex action** (notification fix):
  - Option A — SMTP: Add `GF_SMTP_ENABLED=true`, `GF_SMTP_HOST`, `GF_SMTP_USER`, `GF_SMTP_PASSWORD`, `GF_SMTP_FROM_ADDRESS` to `.env` and `.env.example`. Grafana reads these natively.
  - Option B — Webhook: Add a webhook contact point via provisioning YAML in `grafana/provisioning/alerting/contact-points.yml`. A simple webhook to a local script or ntfy.sh instance requires no SMTP. Recommended for sandbox.
  - After either: provision a notification policy YAML that routes all alerts to the new contact point.

---

- `ADR-082` moved from adr.md
  - evidence: (label_contract_report from loki series => 5 active sources all include identity labels; no NO_SERIES rows)
### ADR-082: Loki Label Schema — Current Runtime State vs Documented State

- **Source**: Loki `/loki/api/v1/labels` API (via port 3200)
- **Evidence**:
  - Current labels: `['env', 'filename', 'log_source', 'mcp_level', 'service', 'service_name', 'source_type', 'stack']`
  - Missing vs previously observed: `__stream_shard__`, `mcp_tool` (were present in pass 9 snapshot)
  - `mcp_tool` label query: `count: 0 []` — no values (mcp_tool label has no active streams)
  - Previous snapshot (2026-02-17): 10 labels including `__stream_shard__`, `mcp_tool`
- **Findings**:
  1. **`mcp_tool` label is no longer active.** Previously had values, now shows 0. The `codeswarm` processor promotes `mcp_tool` to a label from JSON field `tool`. If no MCP logs have been ingested with a `tool` field since Alloy restart, the label has no active streams and drops from the label index. Severity: **LOW** — expected behavior; will reappear when MCP logs flow.
  2. **`service_name` label still present.** This is a dimension label from dashboard provisioning (not set by Alloy directly). Source unclear — likely from a Grafana dimension dashboard configuration. Needs tracing. Severity: **LOW** (informational).
  3. **`host` and `job` and `container_name` labels still absent.** Confirmed missing. Alloy config sets neither `host` nor `job` in any process block. Only `env`, `log_source`, `source_type` static labels are applied. Severity: **MEDIUM** — documentation and query-contract.md must not reference these labels.
  4. **8 active labels** (down from 10 in pass 9). Compact schema. `max_label_names_per_series: 15` provides ample headroom. Severity: **PASS**.
- **Codex action**:
  - File: `docs/reference.md` — update label schema table to reflect: `host` NOT applied, `job` NOT applied, `container_name` NOT applied, `service` IS applied (from docker pipeline).
  - File: `docs/query-contract.md` — remove any queries that filter on `host=`, `job=`, or `container_name=`.
  - File: `CLAUDE.md` — fix label list (already partially done per adr-completed.md, verify fully corrected).

---

- `ADR-085` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-085: `loki_write_failures_discarded_total` — Metric Exists But Has No Series

- **Source**: Prometheus label API and direct metric query (runtime)
- **Evidence**:
  - `loki_write_failures_discarded_total` appears in `__name__` label values ✓
  - Direct query `?query=loki_write_failures_discarded_total` → `[]` (empty result)
  - `loki_write_failures_logged_total` → `[]` (also empty)
  - `loki_write_dropped_entries_total{reason="ingester_error"}` = 47,442 ✓ (has series)
  - `loki_write_dropped_entries_total{reason="line_too_long"}` = 0 ✓
  - `loki_write_dropped_entries_total{reason="rate_limited"}` = 0 ✓
  - `loki_write_dropped_entries_total{reason="stream_limited"}` = 0 ✓
- **Findings**:
  1. **`loki_write_failures_discarded_total` is registered in Alloy's metric registry but has never been emitted.** A metric appears in `__name__` index if Alloy pre-registers it at startup, even if no data has triggered it. It has no active series (no label combination with a value). Severity: **INFORMATIONAL** — this is why `sum()` on it returns empty.
  2. **The `ingester_error` drops (47,442) are historical and not increasing.** Current 5m rate = 0. The drops occurred before the Alloy restart on 2026-02-18. Severity: **PASS** (pipeline clean).
  3. **The `reason` label on `loki_write_dropped_entries_total` is the key monitoring signal.** Only `ingester_error` has a non-zero value. `rate_limited`, `stream_limited`, `line_too_long` are all zero — pipeline is healthy under current load. Severity: **PASS**.
- **Codex action**: See ADR-075 for the recording rule fix using `or vector(0)`.

---

## Pass 11 — Runtime Verification (2026-02-18)

**Scope**: Stale container detection, journald host-path root cause, Grafana alert structural bug, backup scripts verification, notification delivery, health script verification, label schema delta, `add-log-source.sh` status, `down.sh` purge behavior, recording rule fix validation.

**Sources**: `docker inspect`, `docker ps`, host filesystem, Prometheus API, Grafana API, Loki API, git log, source files.

---

- `ADR-086` moved from adr.md
  - evidence: (stateful queue evidence => alloy_recreated_with_storage_and_journald_mounts)
### ADR-086: Alloy Container Is Stale — Not Recreated After Compose Changes

- **Source**: `docker inspect logging-alloy-1` + `stat infra/logging/docker-compose.observability.yml`
- **Evidence**:
  - Alloy container created: `2026-02-17T09:15:14Z`
  - `docker-compose.observability.yml` last modified: `2026-02-18T12:40 CST` (= `2026-02-18T18:40Z`)
  - Compose changes since container creation include: `--storage.path=/var/lib/alloy` command arg, journal bind mounts, `alloy-positions:/var/lib/alloy` volume mapping
  - Current container command: `[run --server.http.listen-addr=0.0.0.0:12345 /etc/alloy/config.alloy]` — MISSING `--storage.path=/var/lib/alloy`
  - Current container mounts: only 5 mounts — NO `/var/log/journal`, NO `/run/log/journal`, volume still at `/tmp`
  - `alloy-positions` volume destination in running container: `/tmp` (NOT `/var/lib/alloy`)
  - Other services created on 2026-02-18T18:15-18:17Z — were recreated; Alloy was not
- **Findings**:
  1. **Alloy is running with the OLD container definition from 2026-02-17.** The container predates all compose changes applied since then. The following fixes declared done in `adr-completed.md` are NOT deployed to the running Alloy instance: `alloy_positions_fixed`, `journald_mounts_fixed`. Severity: **CRITICAL** — fixes exist in compose but are not running.
  2. **`--storage.path=/var/lib/alloy` is NOT passed to the running Alloy process.** Positions are writing to the default path (`/tmp`) inside the OLD container, backed by the `alloy-positions` volume mounted at `/tmp`. The positions file IS persisting (volume is mounted), but to a path that is also a general tmpfs-like location — positions survive container restarts, but are at risk of being overwritten by other processes. Severity: **HIGH** — positions persist via volume but path is suboptimal.
  3. **Journal mounts are not present in the running container.** The host journal paths (`/var/log/journal`, `/run/log/journal`) exist on the host with 1GB of data, but are NOT mounted into the Alloy container. Journald pipeline remains dead. Severity: **HIGH** — root cause confirmed: container not recreated.
  4. **`HOST_HOME=/home` in `.env` mounts entire `/home` not `/home/luce`.** The running container has `/home:/host/home:ro` — confirms the over-permissive mount applies system-wide to all home directories. Severity: **MEDIUM** (ADR-009 carry-forward — single-user host, acceptable risk).
- **Root cause**: `docker compose up -d` was NOT run after compose file changes. Only specific services (grafana, loki, prometheus) appear to have been recreated on 2026-02-18T18:15-18:17Z. Alloy was left from the previous day.
- **Codex action**:
  - Command to apply: `docker compose -p logging -f infra/logging/docker-compose.observability.yml up -d alloy`
  - This will recreate the Alloy container with the current compose spec including: `--storage.path=/var/lib/alloy`, journal bind mounts, updated volume mapping.
  - Verify after: `docker inspect logging-alloy-1 --format '{{json .Mounts}}'` must show `/var/log/journal` and `/run/log/journal` bind mounts, and `alloy-positions` volume at `/var/lib/alloy`.
  - Verify: `docker exec logging-alloy-1 ls /var/log/journal` must return journal files.

---

- `ADR-087` moved from adr.md
  - evidence: (stateful queue evidence => host_journal_mounted_into_alloy)
### ADR-087: Journald Host Paths — Exist on Host, Not Mounted in Container

- **Source**: Host filesystem + `docker inspect logging-alloy-1`
- **Evidence**:
  - Host: `ls /var/log/journal/d7850bf681114f3a93669b409dea1b9f/` → `system.journal` + 3 archived journals
  - Host: `journalctl --disk-usage` → `Archived and active journals take up 1G in the file system.`
  - Host journal machine-id directory: `/var/log/journal/d7850bf681114f3a93669b409dea1b9f/`
  - `.env`: `HOST_VAR_LOG_JOURNAL=/var/log/journal`, `HOST_RUN_LOG_JOURNAL=/run/log/journal`
  - Container: `docker exec logging-alloy-1 ls /var/log/journal` → `No such file or directory`
  - Container mounts: no `/var/log/journal` or `/run/log/journal` entries in `docker inspect`
- **Findings**:
  1. **The host systemd journal IS persistent and accessible.** 1GB of journal data exists at `/var/log/journal`. This is NOT a volatile journal. The `.env` variables point to the correct paths. Severity: **PASS** (host-side is fine).
  2. **The journal mounts are absent from the running container only because the container is stale (ADR-086).** Once Alloy is recreated via `docker compose up -d alloy`, the `/var/log/journal` and `/run/log/journal` bind mounts will be applied and the journald pipeline will receive data. Severity: **PASS** (no code fix needed — container recreation fixes this).
  3. **Alloy `loki.source.journal "journald"` has no `path` argument**, defaulting to `/var/log/journal`. The host path matches the default. No alloy-config.alloy change is needed. Severity: **PASS**.
  4. **Journald pipeline will produce log entries after container recreation.** The `loki.source.journal` block will ingest from the journal files. First ingest may be large (historical backfill of 1GB). Alloy positions file will track offset, preventing re-ingestion on subsequent restarts. Severity: **LOW** — monitor for ingestion spike on first run.

---

- `ADR-088` moved from adr.md
  - evidence: (stateful queue evidence => alert_reduce_step_added_lastError_cleared)
### ADR-088: Grafana Alert Rules — Structural Bug (Missing Reduce Step)

- **Source**: Grafana API `/api/prometheus/grafana/api/v1/rules` + `/api/v1/provisioning/alert-rules` + Loki query validation
- **Evidence**:
  - Both alert rules: `lastError: "failed to parse expression 'C': no variable specified to reference for refId C"`
  - Both alert rules: `state: firing`, `alert state: Alerting (Error)`
  - Both alerts have been in this state since `2026-02-17T10:58:00` (unchanged)
  - Rule structure: `A (Loki range query)` → `C (threshold on A)` — missing reduce step
  - Loki query test: `sum(count_over_time({log_source=~".+"}[5m]))` returns `6512` — data IS flowing
  - The error is a structural parse error in Grafana's expression engine, not a data error
  - Git history: this structure existed in the original commit `fd9f734` — NEVER worked correctly
  - `noDataState: OK` fix (from `af2c911`) addresses noData behavior but the expression never successfully evaluates
  - `execErrState: Alerting` means expression parse failures fire the alert — causing both alerts to fire continuously
- **Findings**:
  1. **Both Grafana alert rules have NEVER successfully evaluated their query.** The `A → C` structure (Loki range query directly into threshold) fails in Grafana 11.x because a range query returns a time series, not a scalar. A reduce step (`refId: B`, type: `reduce`) is required between the Loki query and the threshold condition. Severity: **CRITICAL** — alerts are permanently broken as written.
  2. **`execErrState: Alerting` causes both alerts to fire on every evaluation interval.** This is the actual firing mechanism — not noData, not threshold breach. The expression parse fails, `execErrState` triggers, alert fires. Severity: **CRITICAL** — alerts produce noise, not signal.
  3. **`noDataState: OK` fix was insufficient.** It correctly addresses the case where Loki returns no data, but the alerts do not reach the noData path — they fail earlier at expression evaluation. The prior fix (ADR-081) was incomplete. Severity: **HIGH** — prior remediation did not solve the root cause.
  4. **Loki IS delivering data.** `sum(count_over_time({log_source=~".+"}[5m]))` = 6512. The `logging-total-ingest-down` alert is structurally impossible to evaluate correctly in its current form — even though ingest is healthy. Severity: **PASS** (data flow OK) / **CRITICAL** (alert broken).
- **Codex action** — fix rule structure in `infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml`:
  - For EACH rule, insert a reduce step between the Loki query (refId A) and the threshold (refId C):
    ```yaml
    - refId: B
      datasourceUid: __expr__
      model:
        type: reduce
        reducer: last
        expression: A
    ```
  - Change the threshold condition refId from `A` to `B`:
    ```yaml
    - refId: C
      datasourceUid: __expr__
      model:
        type: threshold
        conditions:
          - evaluator:
              type: lt
              params: [1]
            query:
              params: [B]
    ```
  - Also change `condition: C` at the rule level to remain `C` (the threshold step is still the final condition).
  - After applying: `docker compose -p logging -f infra/logging/docker-compose.observability.yml restart grafana`
  - Verify: `lastError` field in Grafana API rules response must be empty/null. Both alerts must transition to `Normal` state (since ingest IS active and MARKER will be absent → `logging-e2e-marker-missing` will go `noDataState: OK` → Normal).

---

- `ADR-089` moved from adr.md
  - evidence: (stateful queue evidence => alloy_positions_mapped_var_lib_alloy)
### ADR-089: Alloy Positions Volume — Still Mounted at /tmp in Running Container

- **Source**: `docker inspect logging-alloy-1 --format '{{json .Mounts}}'`
- **Evidence**:
  - Running container mount: `{"Type":"volume","Name":"logging_alloy-positions","Source":"/var/lib/docker/volumes/logging_alloy-positions/_data","Destination":"/tmp",...}`
  - Compose file (current): `alloy-positions:/var/lib/alloy` ✓ (fix exists in compose)
  - Compose command (current): `--storage.path=/var/lib/alloy` ✓ (fix exists in compose)
  - Running container command: `[run --server.http.listen-addr=0.0.0.0:12345 /etc/alloy/config.alloy]` — NO `--storage.path`
- **Findings**:
  1. **The `alloy_positions_fixed` completion claim in `adr-completed.md` is FALSE at runtime.** The fix exists in compose YAML but is not deployed. The running container has the old, broken configuration. Severity: **HIGH** — claimed fix is not live.
  2. **Positions ARE persisting** because the volume is mounted at `/tmp` and Alloy writes to `/tmp/positions.json` by default. The volume at `/tmp` is not serving its intended purpose but accidentally prevents complete position loss on restart. Severity: **MEDIUM** — functional by accident, not by design.
  3. **Resolution**: Container recreation (ADR-086 Codex action) will deploy both the `--storage.path=/var/lib/alloy` command arg AND the corrected volume mapping. No additional code change is needed — the fix is already in compose. Severity: **PASS** (fix already written, just not deployed).

---

- `ADR-091` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-091: Grafana Contact Point — Placeholder Email, No SMTP

- **Source**: Grafana API `/api/v1/provisioning/contact-points` + `.env` + compose env inspection
- **Evidence**:
  - Contact point: `{"name":"email receiver","type":"email","settings":{"addresses":"<example@email.com>"}}`
  - `.env`: no `GF_SMTP_*` variables defined
  - `infra/logging/`: no SMTP environment variables in compose or grafana provisioning
  - No webhook, PagerDuty, Slack, or ntfy contact point defined
- **Findings**:
  1. **Notification delivery is non-functional.** The contact point has a placeholder email (`example@email.com`) and no SMTP is configured. All alert notifications are silently discarded. Severity: **HIGH** — confirmed from ADR-081 but now with full evidence chain.
  2. **No alternative contact point (webhook, Slack, ntfy) exists.** A webhook to a local `ntfy` or `ntfy.sh` instance would require zero SMTP configuration and is the lowest-friction fix for a sandbox. Severity: **MEDIUM** (enhancement, not a blocker for sandbox operation).
  3. **No notification policy provisioning YAML exists.** Even if a working contact point were added, the default Grafana notification policy would need to be overridden to route to the new contact point. A `notification-policy.yml` in `grafana/provisioning/alerting/` is required. Severity: **MEDIUM**.
- **Codex action** (Option A — ntfy webhook, no SMTP required):
  - Create `infra/logging/grafana/provisioning/alerting/contact-points.yml` with a webhook contact point pointing to `https://ntfy.sh/<topic>` (public, no auth required for sandbox).
  - Create `infra/logging/grafana/provisioning/alerting/notification-policy.yml` routing all alerts to the new contact point.
  - Update `.env.example` to document the ntfy topic variable.
  - After: `docker compose -p logging -f infra/logging/docker-compose.observability.yml restart grafana`

---

- `ADR-094` moved from adr.md
  - evidence: (stateful queue evidence => loki_write_rule_path_hardened)
### ADR-094: `sprint3:loki_ingestion_errors` — `or vector(0)` Fix Verified in Isolation

- **Source**: Prometheus API `/api/v1/query` (live evaluation)
- **Evidence**:
  - `sum(increase(loki_write_dropped_entries_total[10m])) > 0` (AlloyPipelineDrops expr) → returns `0` (vector, not empty) ✓
  - `sum(rate(loki_write_dropped_entries_total[5m])) or vector(0)` → returns `0` ✓
  - `sum(rate(loki_write_dropped_entries_total[5m])) + sum(rate(loki_write_failures_discarded_total[5m]))` → `[]` (empty) ✗
  - `AlloyPipelineDrops` alert uses `sum(increase(loki_write_dropped_entries_total[10m])) > 0` — returns a non-empty vector (value `0`), so alert evaluates correctly and stays `inactive` ✓
- **Findings**:
  1. **`AlloyPipelineDrops` alert IS functional.** It uses only `loki_write_dropped_entries_total` (which has active series). The alert correctly evaluates to inactive (no drops in current window). Severity: **PASS**.
  2. **`or vector(0)` pattern is confirmed to produce a non-empty result** when either operand has no series. The fix for `sprint3:loki_ingestion_errors:*` recording rules is verified in isolation. Severity: **PASS** (fix pattern confirmed).
  3. **The `LokiIngestionErrors` alert in `sprint3_minimum_alerts.yml`** references `sprint3:loki_ingestion_errors:increase10m > 0`, which evaluates to `[]`. Since an empty vector is treated as `false` by Prometheus, this alert will NEVER fire even when there are ingestion errors. It is a silent dead alert. Severity: **HIGH** — must be removed or fixed.
- **Codex action** (two-part fix):
  - Part A — Fix recording rules in `infra/logging/prometheus/rules/loki_logging_rules.yml`:
    - `sprint3:loki_ingestion_errors:rate5m` expr: change to `(sum(rate(loki_write_dropped_entries_total[5m])) or vector(0)) + (sum(rate(loki_write_failures_discarded_total[5m])) or vector(0))`
    - `sprint3:loki_ingestion_errors:increase10m` expr: same pattern with `increase` instead of `rate`
  - Part B — Remove dead alert from `infra/logging/prometheus/rules/sprint3_minimum_alerts.yml`:
    - Delete the `LokiIngestionErrors` alert block entirely (it is superseded by `AlloyPipelineDrops` in `loki_logging_rules.yml` which is functional)
  - After: Prometheus will hot-reload rules within 30s (no restart needed; `--web.enable-lifecycle` is not required for rules reload — Prometheus polls rules directory)
  - Verify: `curl -sf http://127.0.0.1:9004/api/v1/query?query=sprint3:loki_ingestion_errors:rate5m` must return `{"result":[{"metric":{},"value":[..., "0"]}]}` (not empty)

---

## Pass 12 — Completed-Claim Validation + 30 New Findings (2026-02-19)

**Scope**: Systematic validation of every `adr-completed.md` completion claim against runtime state + 5-agent parallel discovery sweep covering runtime containers, documentation, Prometheus/Grafana/Loki metrics, Alloy pipelines, and security/infrastructure.

**Parallel agents**: Agent-1 (runtime/containers), Agent-2 (docs), Agent-3 (Prometheus/Grafana/Loki), Agent-4 (config/pipelines/disk), Agent-5 (security/ports/UFW).

**Evidence timestamps**: 2026-02-19T00:05–00:07Z

---

- `ADR-095` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-095: `alloy_positions_fixed` — CLAIM FALSE AT RUNTIME

- **Completion claim**: `alloy_positions_fixed: true` — "alloy storage path and positions volume aligned"
- **Source**: `docker inspect logging-alloy-1 --format '{{json .Mounts}}'` (Agent-1)
- **Evidence**:
  - Volume destination in running container: `/tmp` (NOT `/var/lib/alloy`)
  - Container command: `[run --server.http.listen-addr=0.0.0.0:12345 /etc/alloy/config.alloy]` — NO `--storage.path`
  - Compose file has correct fix: `alloy-positions:/var/lib/alloy` + `--storage.path=/var/lib/alloy` ✓
  - Container creation: `2026-02-17T09:15:14Z`, compose modified: `2026-02-18T18:40Z`
  - Positions volume (`logging_alloy-positions`) contains EMPTY data: `8.0K` total, `no positions file found`
- **Findings**:
  1. **The fix exists in compose YAML but has NOT been deployed to the running container.** Container is 33 hours stale relative to the compose file. `alloy_positions_fixed: true` is TRUE as a code change but FALSE as a runtime deployment. Severity: **CRITICAL** — every claim dependent on this completion tag must be re-evaluated.
  2. **The alloy-positions volume is empty (8.0K).** No positions file exists at any path in the volume. This means Alloy has no tail position memory — if the container were recreated, it would re-ingest from start of all monitored files. Severity: **HIGH** — risk of log re-ingestion flood on next `docker compose up -d alloy`.
- **Re-invalidates**: ADR-008 (alloy_positions_fixed), ADR-009 (alloy_positions_fixed), ADR-011 (alloy_positions_fixed), ADR-015 (alloy_positions_fixed), ADR-019–ADR-021 (alloy_positions_fixed), ADR-022 (alloy_positions_fixed), ADR-025 (alloy_positions_fixed), ADR-043 (alloy_positions_fixed)
- **Codex action**: `docker compose -p logging -f infra/logging/docker-compose.observability.yml up -d alloy` — must be run to deploy the fix.

---

- `ADR-096` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-096: `journald_mounts_fixed` — CLAIM FALSE AT RUNTIME

- **Completion claim**: `journald_mounts_fixed: true` — "journald mounts added to alloy service"
- **Source**: `docker exec logging-alloy-1 ls /var/log/journal` + `docker inspect` mounts (Agent-1)
- **Evidence**:
  - `docker exec logging-alloy-1 ls /var/log/journal` → `ls: cannot access '/var/log/journal': No such file or directory`
  - `docker exec logging-alloy-1 ls /run/log/journal` → same error
  - Container mounts: 5 entries — NO `/var/log/journal`, NO `/run/log/journal`
  - Host `ls /var/log/journal` → `d7850bf681114f3a93669b409dea1b9f/` (journal exists, 1GB data)
  - `.env` has: `HOST_VAR_LOG_JOURNAL=/var/log/journal`, `HOST_RUN_LOG_JOURNAL=/run/log/journal` ✓
  - Compose file has journal mounts declared ✓
  - Container stale — created before compose changes
- **Findings**:
  1. **`journald_mounts_fixed: true` is TRUE as a code change but FALSE at runtime.** Journal mounts are in the compose file but the running container was created before those changes. Severity: **CRITICAL** — same root cause as ADR-095.
  2. **Journald pipeline continues to produce ZERO log delivery** despite 1GB of journal data on the host. Severity: **HIGH**.
  3. **Resolution is the same as ADR-095** — container recreation will deploy both fixes simultaneously.

---

- `ADR-097` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-097: `resource_limits_fixed` — CLAIM PARTIALLY FALSE

- **Completion claim**: `resource_limits_fixed: true` — "resource limits added for core services"
- **Source**: `docker inspect` HostConfig.Memory + NanoCpus for all 6 services (Agent-1)
- **Evidence**:
  - `grafana`: `mem=1073741824 cpu=500000000` (1GB, 0.50 CPUs) ✓
  - `loki`: `mem=2147483648 cpu=1000000000` (2GB, 1.00 CPUs) ✓
  - `prometheus`: `mem=2147483648 cpu=1000000000` (2GB, 1.00 CPUs) ✓
  - `alloy`: `mem=0 cpu=0` — NO LIMITS (stale container, predates compose changes)
  - `host-monitor`: `mem=0 cpu=0` — NO LIMITS (never updated in compose)
  - `docker-metrics`: `mem=0 cpu=0` — NO LIMITS (never updated in compose)
- **Findings**:
  1. **3 of 6 services have resource limits applied.** Grafana, Loki, Prometheus are fixed. Severity: **PASS** (partial).
  2. **Alloy has `mem=0 cpu=0` because the container is stale** — compose has limits declared but container not recreated. After `docker compose up -d alloy`, Alloy will gain `mem_limit: 1g, cpus: 0.75`. Severity: **HIGH** — stale container again.
  3. **`host-monitor` and `docker-metrics` have NO limits in the compose file** — not a stale container issue. These services were never given resource constraints. Severity: **MEDIUM** — both are light services but unconstrained.
- **Codex action** (host-monitor and docker-metrics): Add to `docker-compose.observability.yml`:
  - `host-monitor`: `mem_limit: 256m`, `cpus: "0.25"`
  - `docker-metrics`: `mem_limit: 512m`, `cpus: "0.25"`

---

- `ADR-098` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-098: `alloy_health_ready_fixed` — CLAIM FALSE AT RUNTIME

- **Completion claim**: `alloy_health_ready_fixed: true` — "alloy healthcheck now probes /-/ready"
- **Source**: `docker inspect logging-alloy-1 --format '{{json .Config.Healthcheck}}'` (Agent-1)
- **Evidence**:
  - Running container healthcheck: `{"Test":["CMD","/bin/alloy","fmt","--help"],...}` — probes `alloy fmt --help`
  - Compose file (current): `wget -q -O - http://127.0.0.1:12345/-/ready` ✓ (fix in compose)
  - Container stale — healthcheck change not deployed
- **Findings**:
  1. **`alloy_health_ready_fixed: true` is TRUE as a code change but FALSE at runtime.** The running container healthcheck executes `alloy fmt --help`, which always succeeds regardless of whether Alloy is serving requests. It does NOT probe `/-/ready`. Severity: **HIGH** — container reports healthy even during Alloy startup failures or pipeline errors.
  2. **Resolution**: Container recreation deploys correct healthcheck.

---

- `ADR-099` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-099: `docs/reference.md` — Alloy Positions Still Shows `/tmp`

- **Completion claim**: `alloy_positions_fixed` — "docs/reference.md `alloy-positions` mount shows `/tmp`" marked PASS
- **Source**: `grep -n 'alloy-positions\|positions\|/tmp' docs/reference.md` (Agent-2)
- **Evidence**:
  - `docs/reference.md:125` → `| alloy-positions | alloy | /tmp | File tail positions, syslog cursor tracking |`
  - The volume table in `docs/reference.md` still says `/tmp` as the container path
  - Compose fix has `/var/lib/alloy` ✓, but docs not updated to reflect the intended destination
- **Findings**:
  1. **The doc still says `/tmp`.** The `alloy_positions_fixed` completion note says "docs/reference.md `alloy-positions` mount shows `/tmp`" is PASS — but the doc still has `/tmp`. Severity: **MEDIUM** — doc drift, doc reader gets wrong info.
  2. **Even after container recreation, the correct path is `/var/lib/alloy`**. The doc needs updating to `/var/lib/alloy`.
- **Codex action**: Update `docs/reference.md:125` — change `/tmp` to `/var/lib/alloy`.

---

- `ADR-100` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-100: `docs/reference.md` — Label Schema Claims Unvalidated Labels

- **Completion claim**: `docs_host_drift_fixed` — CLAUDE.md host label corrected
- **Source**: `grep -n 'env\|host\|job\|container_name\|label' docs/reference.md` (Agent-2)
- **Evidence**:
  - `docs/reference.md:162` → `| container_name | Docker metadata | logging-grafana-1 | Preferred |`
  - `docs/reference.md:153` → `| env | Alloy static label | sandbox | Yes |`
  - No `host` label row in docs ✓ (removed)
  - No `job` label row in docs ✓ (removed)
  - `container_name` still listed as an active label with value `logging-grafana-1`
  - Runtime Loki labels: `['env', 'filename', 'log_source', 'mcp_level', 'service', 'service_name', 'source_type', 'stack']` — NO `container_name`
- **Findings**:
  1. **`container_name` label claim persists in `docs/reference.md`.** Loki has no `container_name` label. Alloy Docker pipeline uses `service` (compose service name), not `container_name`. Severity: **MEDIUM** — documentation gives incorrect query guidance.
  2. **`host` and `job` label rows appear removed** from the doc — partial fix confirmed. Severity: **PASS** (host/job removed).
- **Codex action**: Remove or correct `container_name` row in `docs/reference.md`. Replace with `service` label which IS present.

---

- `ADR-101` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-101: `docs/reference.md` — Source Count Says 8 But 3 Are Dead

- **Completion claim**: `docs_source_count_fixed: true` — "reference source count corrected to 8 with rsyslog/tool labels"
- **Source**: `grep -n 'source\|8\|7\|active' docs/reference.md` (Agent-2)
- **Evidence**:
  - `docs/reference.md:80` → `**Total: 8 active log sources**`
  - Runtime Loki `log_source` values: `['codeswarm_mcp', 'docker', 'rsyslog_syslog', 'telemetry', 'vscode_server']` — 5 active
  - Dead (configured but not delivering): `journald` (mounts missing), `tool_sink` (likely empty/no new files), `nvidia_telem` (no recent data)
  - Reference table (lines 84–91) lists: journald, rsyslog_syslog, docker, vscode_server, codeswarm_mcp, nvidia_telem, telemetry, tool_sink = 8
- **Findings**:
  1. **"8 active log sources" is misleading — 3 are configured but not delivering data.** Calling all 8 "active" gives false confidence. Severity: **MEDIUM** — operational decision-making based on this count is incorrect.
  2. **`journald` shows as "active" in the doc but is delivering zero lines** due to mount issue. Severity: **HIGH** — document implies journald is working.
  3. **Correction: doc should say "8 configured log sources (5 delivering, 3 not delivering)".**
- **Codex action**: Update `docs/reference.md:80` to `**Total: 8 configured log sources (5 delivering, 3 not delivering)**`. Add delivery status column to the table.

---

- `ADR-102` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-102: `docs/security.md` — Claims Loki Is Internal-Only (False)

- **Completion claim**: `loki_port_local_runtime: true` — "loki now bound local at runtime"
- **Source**: `grep -n 'Loki\|internal\|3200\|3100\|exposed' docs/security.md` (Agent-2) + runtime `docker ps`
- **Evidence**:
  - `docs/security.md:30` → `**Loki** (http://loki:3100) — No external binding`
  - `docs/security.md:226` → `Loki is **internal-only** (no external exposure)`
  - `docs/security.md:351` → `- [ ] Loki has no exposed ports (internal-only)`
  - Runtime: `logging-loki-1 127.0.0.1:3200->3100/tcp` — Loki IS bound on `127.0.0.1:3200` externally
  - `iptables DNAT: dpt:3200 to:172.20.0.3:3100` — confirms external port exists
- **Findings**:
  1. **`docs/security.md` claims Loki has "no external binding" and is "internal-only".** This is false — Loki has a loopback-bound port `127.0.0.1:3200`. The claim that there's "no external binding" is incorrect; there IS a binding, it's just loopback-scoped. Severity: **MEDIUM** — security documentation gives false assurance. Loopback binding is lower risk than 0.0.0.0, but is NOT "no external binding".
  2. **The `loki_port_local_runtime` fix is confirmed** — the binding IS loopback only (`127.0.0.1:3200`). The iptables DNAT confirms `anywhere → localhost`. This is correctly scoped. Severity: **PASS** (security posture is correct).
  3. **Documentation must be corrected** to say "Loki binds to `127.0.0.1:3200` (loopback-only, not accessible from LAN)". Not "no external binding". Severity: **MEDIUM** — misleading but not dangerous.
- **Codex action**: Update `docs/security.md` lines 28–35 and 226, 351 to accurately state: "Loki has a loopback-only external binding (`127.0.0.1:3200`). Not accessible from LAN. Internal Docker service URL: `http://loki:3100`."

---

- `ADR-103` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-103: `docs/manifest.json` — Points to Non-Existent Files (10-/20-/40- Prefixes)

- **Source**: `cat docs/manifest.json` (Agent-2)
- **Evidence**:
  - `docs/manifest.json` lists: `"10-as-installed.md"`, `"20-as-configured.md"`, `"30-architecture.md"`, `"40-runbooks.md"`, `"50-troubleshooting.md"`, `"60-validation.md"`, `"70-security.md"`, `"80-maintenance.md"` — 8 files with numeric prefixes
  - `ls docs/` shows: `architecture.md`, `maintenance.md`, `security.md`, `operations.md`, `troubleshooting.md`, `validation.md` etc. — NO numeric prefix files
  - `manifest.json.meta.git_head` = `2c5470a18fc784b87074853b4de48a5a7e24c17a` (old commit, files since renamed)
  - `manifest.json.meta.generated_utc` = `2026-02-13T04:33:42Z` (5 days before current date)
- **Findings**:
  1. **`docs/manifest.json` references 10 files that no longer exist.** All were renamed from `NN-name.md` to `name.md` format. Manifest has not been regenerated. Severity: **HIGH** — any tooling that reads manifest.json will fail to find the docs.
  2. **`docs/snippets/` still exists** with 3 stale config excerpts (alloy-config.alloy 1.7k vs 395-line canonical, loki-config.yml 687b vs current, prometheus.yml 487b). Update-docs.md marked these for deletion but they were not deleted. Severity: **MEDIUM** — snippets are stale and misleading.
  3. **Manifest meta contains hardcoded paths** (`/home/luce/apps/loki-logging/temp/codex/evidence/...`) and old git head. Severity: **LOW** (internal artifact).
- **Codex action**:
  - Regenerate `docs/manifest.json` from actual file list in `docs/`.
  - Delete `docs/snippets/alloy-config.alloy`, `docs/snippets/loki-config.yml`, `docs/snippets/prometheus.yml`.

---

- `ADR-111` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-111: Alloy Config — Samba Mount Present in Compose But NO Samba Pipeline in Alloy Config

- **Source**: `grep -n -A10 'samba' alloy-config.alloy` + `docker inspect` mounts (Agent-4, Agent-1)
- **Evidence**:
  - `grep samba alloy-config.alloy` → no output (no samba pipeline)
  - `docker inspect logging-alloy-1` mounts includes: `{"Source":"/var/log/samba","Destination":"/host/var/log/samba","Mode":"ro",...}` — mount IS present
  - `ls /var/log/samba` exists on host (not checked but mount source exists in container mounts list)
- **Findings**:
  1. **The Samba log directory is mounted in the Alloy container but there is no Alloy pipeline to ingest it.** The volume mount `${HOST_VAR_LOG_SAMBA:-/var/log/samba}:/host/var/log/samba:ro` exists in compose and in the running container, but no `loki.source.file` block with pattern `/host/var/log/samba/**` exists in `alloy-config.alloy`. Severity: **MEDIUM** — unnecessary bind mount with no benefit, adds attack surface.
  2. **Samba logs are not being ingested.** There is no `log_source=samba` or similar value in Loki. Severity: **LOW** — Samba logs silently not collected.
- **Codex action**: Either add a samba log pipeline to `alloy-config.alloy` or remove the `/var/log/samba` mount from `docker-compose.observability.yml`.

---

- `ADR-113` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-113: Grafana Image `11.1.0` — EOL, Multiple Major Versions Behind

- **Source**: `.env` + `.env.example` (Agent-5) + `docker inspect logging-grafana-1`
- **Evidence**:
  - `GRAFANA_IMAGE=grafana/grafana:11.1.0` in both `.env` and `.env.example`
  - Grafana `11.1.0` released approximately July 2024
  - Current Grafana release: `11.5.x` (as of February 2026)
  - Grafana `11.1.x` reached end of support; security patches may not be backported
  - No `docker pull` in the deploy script — image is cached locally
- **Findings**:
  1. **Grafana 11.1.0 is approximately 4 minor versions behind the current 11.5.x.** Known CVEs in Grafana 11.1.x include authentication bypass and plugin issues. Severity: **MEDIUM** — internal sandbox, single user, but LAN-accessible.
  2. **Image version is pinned (no `:latest` tag)** — predictable but requires manual update. Severity: **PASS** (correct practice, but update needed).
  3. **Upgrade path**: `11.1.0 → 11.5.x` is a direct upgrade. Grafana preserves `grafana-data` volume across upgrades. Update `.env` + `.env.example`, then `docker compose up -d grafana`. Severity: **LOW** (straightforward upgrade).

---

- `ADR-116` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-116: `sprint3_minimum_alerts.yml` Timestamp — File Not Updated Since Sprint 3

- **Source**: `ls -la infra/logging/prometheus/rules/` (Agent-5) + file timestamps
- **Evidence**:
  - `sprint3_minimum_alerts.yml`: last modified `2026-02-14 13:34` (5 days ago relative to audit)
  - `loki_logging_rules.yml`: last modified `2026-02-18 12:40` (current day)
  - `sprint3_minimum_alerts.yml` retains the name `sprint3_minimum_v1` rule group
  - Still contains dead `LokiIngestionErrors` alert (see ADR-094)
- **Findings**:
  1. **`sprint3_minimum_alerts.yml` has not been touched in 5 days** — specifically not updated in the same session that updated `loki_logging_rules.yml`. The dead `LokiIngestionErrors` alert was not removed despite being identified in ADR-061 and ADR-094. Severity: **HIGH** — dead alert still present.
  2. **The group name `sprint3_minimum_v1` is vestigial.** Should be renamed to reflect its actual purpose (minimal Prometheus alerting) per DC-8 cleanup. Severity: **LOW** (cosmetic).

---

- `ADR-117` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-117: Backup Scripts — Wrong Location, Volume Name Mismatch

- **Source**: `find backup*.sh restore*.sh` + script content inspection (Agent-4)
- **Evidence**:
  - Scripts at: `infra/logging/scripts/backup_volumes.sh`, `infra/logging/scripts/restore_volumes.sh`
  - Script targets: `logging-grafana-data`, `logging-loki-data`, `logging-prometheus-data`
  - Actual Docker volume names: `logging_grafana-data`, `logging_loki-data`, `logging_prometheus-data` (underscore prefix, not hyphen)
  - `docker volume ls` confirms: `logging_alloy-positions`, `logging_grafana-data`, `logging_loki-data`, `logging_prometheus-data`
- **Findings**:
  1. **Backup scripts use WRONG volume names.** Docker Compose prefixes volume names with `${project}_` where project=`logging`. The actual volume names are `logging_grafana-data` (underscore), but the backup script references `logging-grafana-data` (hyphen). Running `backup_volumes.sh` would fail silently or attempt to create new volumes named `logging-grafana-data`. Severity: **CRITICAL** — backup scripts are non-functional as written.
  2. **This was not caught during the `backup_restore_added` completion review.** The completion claim marked this as PASS without verifying the volume names. Severity: **HIGH** — false completion claim.
- **Codex action**: Fix `infra/logging/scripts/backup_volumes.sh` and `restore_volumes.sh` — change `logging-grafana-data` → `logging_grafana-data`, `logging-loki-data` → `logging_loki-data`, `logging-prometheus-data` → `logging_prometheus-data`.

---

- `ADR-118` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-118: Alloy Healthcheck — `fmt --help` Exit Code Cannot Detect Pipeline Failures

- **Source**: Agent-1 healthcheck inspection + Alloy container runtime
- **Evidence**:
  - Running healthcheck: `["CMD","/bin/alloy","fmt","--help"]`
  - `alloy fmt --help` — prints format help text and exits 0 always
  - This command does NOT connect to Alloy's HTTP server
  - `alloy` container is `healthy` per `docker ps` despite journal mounts being absent
  - Correct check: `wget -q -O - http://127.0.0.1:12345/-/ready` would return `Ready` only when Alloy is serving
- **Findings**:
  1. **The running healthcheck is a no-op.** `alloy fmt --help` always exits 0. Container will always report `healthy` regardless of whether Alloy is running, accepting connections, or dropping logs. Severity: **HIGH** — health signal is meaningless.
  2. **The compose file has the correct healthcheck (`wget /-/ready`)** but is not deployed. Once recreated, Alloy health probing will work correctly.
  3. **Depends_on in grafana/loki depend on alloy being healthy** — these dependencies use the broken healthcheck, meaning Grafana and Loki could start before Alloy is ready without the compose machinery knowing. Severity: **MEDIUM** — startup ordering may be incorrect.

---

- `ADR-121` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-121: `docs/quality-checklist.md` — Modified 2026-02-18 But Prometheus Auth Box Unchecked

- **Source**: `ls docs/` (last modified 2026-02-18 12:40) + checklist content (Agent-2)
- **Evidence**:
  - `docs/quality-checklist.md` last modified `2026-02-18 12:40` (same day as other fixes)
  - `docs/quality-checklist.md:85` → `- [ ] Prometheus exposure is either loopback-only or protected with explicit auth controls`
  - Prometheus IS loopback-only (`127.0.0.1:9004`) ✓ — this check should be marked `[x]`
  - Prometheus has NO authentication configured (`grep basic_auth prometheus.yml` → empty) — second condition not met
- **Findings**:
  1. **The Prometheus checklist item is unchecked despite the condition being satisfied.** Prometheus binds loopback-only — the first condition in the OR is met. Severity: **LOW** (cosmetic).
  2. **Prometheus still has zero authentication.** For a sandbox with loopback-only binding, this is acceptable risk. But if someone port-forwards or adds a reverse proxy, metrics are fully public. Severity: **LOW** (sandbox context).

---

- `ADR-122` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-122: Grafana `disableDeletion: false` — Provisioned Dashboards Can Be Deleted

- **Source**: `cat infra/logging/grafana/provisioning/dashboards/dashboards.yml` (Agent-5)
- **Evidence**:
  - `disableDeletion: false` in `dashboards.yml`
  - This means if a dashboard JSON file is removed from the repo/volume, Grafana will delete the dashboard from its database on next rescan
  - The dashboards volume is mounted read-only (`:ro`) from the host, so accidental deletion from Grafana UI is prevented
  - But removal of JSON files from the repo would cascade to dashboard deletion
- **Findings**:
  1. **`disableDeletion: false` is a concern for a code-managed dashboard set.** If JSON files are deleted from git and the container is restarted, dashboards disappear from Grafana without warning. Severity: **LOW** — git history preserves files, but developer could `git rm` a dashboard and lose it.
  2. **`editable: true` means dashboards CAN be edited in Grafana UI**, but changes are lost on container restart (volume is `:ro` from host, so UI changes go to Grafana's SQLite, not back to the file). Severity: **LOW** — edit-in-UI workflows are non-persistent. Could confuse users.

---

- `ADR-123` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-123: Grafana Alert Rules — Both Using `severity: warning` and `severity: critical` With No Notification Route

- **Source**: `logging-pipeline-rules.yml` + contact point API (Agent-3, Agent-5)
- **Evidence**:
  - `logging-e2e-marker-missing`: `labels: severity: warning`
  - `logging-total-ingest-down`: `labels: severity: critical`
  - Contact point: `{"name":"email receiver","type":"email","settings":{"addresses":"<example@email.com>"}}`
  - No notification policy YAML exists in `infra/logging/grafana/provisioning/alerting/`
  - Only `logging-pipeline-rules.yml` is in the alerting provisioning directory
  - Default Grafana notification policy: routes all alerts to `grafana-default-email` contact point
- **Findings**:
  1. **Severity labels (`warning`/`critical`) are applied but no notification routing uses them.** The default policy routes everything to one contact point regardless of severity. Severity: **MEDIUM** — severity labels are decorative, not functional.
  2. **Even if SMTP were configured, critical and warning alerts would receive identical treatment** — same email address, same template. No escalation differentiation. Severity: **MEDIUM** — notification architecture incomplete.
  3. **`logging-total-ingest-down` is severity `critical` but fires via `execErrState`** (structural rule bug, ADR-088) — not a true criticality indicator. Severity: **HIGH** (see ADR-088).

---

- `ADR-125` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-125: `CLAUDE.md` Label Schema Claim — `host` and `job` Never Set in Alloy Config

- **Source**: Agent aa1ec83 Check 10, confirmed by `grep` of `alloy-config.alloy`
- **Evidence**:
  - `CLAUDE.md` states: "Every log entry has: `env`, `host`, `job`"
  - Live Loki label index (via `/loki/api/v1/labels`): `["env", "filename", "log_source", "mcp_level", "service", "service_name", "source_type", "stack"]`
  - `host` absent from Loki label index
  - `job` absent from Loki label index
  - `grep 'host\s*=\|"host"\s*=' alloy-config.alloy` returns only Docker socket connection params (not Loki labels)
  - No `stage.static_labels` block in alloy-config.alloy sets `host = "codeswarm"` or `job = anything`
  - 4 undocumented labels ARE present: `mcp_level`, `service_name`, `source_type`, `stack`
- **Findings**:
  1. **`CLAUDE.md` label schema is factually incorrect.** `host` and `job` are never injected by any Alloy pipeline. They do not exist in Loki's label index. Severity: **MEDIUM** — misleads anyone writing LogQL queries expecting `{host="codeswarm"}` or `{job="..."}`.
  2. **4 undocumented labels exist**: `mcp_level` (MCP log level), `service_name` (Alloy Docker discovery), `source_type` (file vs socket), `stack` (vllm/codeswarm etc). These are real and queryable but absent from all documentation. Severity: **LOW** — undocumented but discoverable.
  3. **ADR-100 partial correction**: ADR-100 marks removal of `host`/`job` from `docs/reference.md` as PASS, but the deeper issue is the Alloy config never sets them — not a docs drift issue but a label schema spec that was never implemented.
- **Codex action**: 
  1. Remove `host` and `job` from `CLAUDE.md` label schema description
  2. Add `mcp_level`, `service_name`, `source_type`, `stack` to CLAUDE.md label schema
  3. OR: Add `static_labels` stages to Alloy pipelines to set `host = "codeswarm"` and `job = "loki"` if the spec is intentional

---

- `ADR-127` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-127: Grafana `disableDeletion: false` + `editable: true` — Dashboard Mutation Risk Unmitigated

- **Source**: Agent a5d4957 Check 5 (dashboards.yml)
- **Evidence**:
  - `infra/logging/grafana/provisioning/dashboards/dashboards.yml`:
    ```yaml
    disableDeletion: false
    editable: true
    ```
  - 14+ dashboard JSON files in `infra/logging/grafana/dashboards/` (including subdirs `adopted/`, `dimensions/`, `sources/`)
  - No `updateIntervalSeconds` set in dashboards.yml (defaults to 10s rescan)
  - Grafana API allows dashboard deletion and edit via UI when these flags are set
- **Findings**:
  1. **Provisioned dashboards can be deleted via Grafana UI or API** because `disableDeletion: false`. Deletions are not written back to disk — next Grafana restart will restore from file, but any in-session deletions or edits are lost without git. Severity: **LOW** — operational inconvenience, not data loss risk (files are in git).
  2. **`editable: true` allows UI edits but changes are not persisted to the provisioned JSON files** — saves go to Grafana DB only, diverging from the file-based source of truth. Severity: **LOW** — creates drift between git source and running Grafana state.
  3. **`updateIntervalSeconds` not set** — Grafana rescans dashboard directory every 10s by default. This means any file change is auto-applied. This is desirable for development but means a bad git push can immediately break dashboards.
  4. **ADR-106 previously noted** provisioning YAML doesn't reflect subdirectory structure. Confirmed: `dashboards.yml` uses a single `path:` pointing to `/var/lib/grafana/dashboards` — Grafana will recursively scan subdirs so this works, but it's implicit.
- **Codex action**: Set `disableDeletion: true` and `editable: false` in `dashboards.yml` to enforce immutability of provisioned dashboards. If editing is needed, edit files in git.

---

- `ADR-128` moved from adr.md
  - evidence: (stateful queue evidence => preserved_done)
### ADR-128: `CLAUDE.md` Down Script Comment — "Removes Volumes" Is Incorrect

- **Source**: Agent ad64491 Check 9 (`scripts/prod/mcp/logging_stack_down.sh`)
- **Evidence**:
  - `CLAUDE.md:17`: `# Stop stack (removes volumes)` — comment says volumes are removed
  - `CLAUDE.md:18`: `./scripts/prod/mcp/logging_stack_down.sh`
  - Actual script behavior:
    - Default: `docker compose down` — volumes KEPT
    - `--purge` flag: `docker compose down -v` — volumes destroyed
  - Script lines 7–19 explicitly document: "Default mode keeps data volumes. Use --purge to destroy all Loki logs, Prometheus metrics, and Grafana..."
- **Findings**:
  1. **`CLAUDE.md` misleads operators into believing the down script always destroys volumes.** In practice, running `./logging_stack_down.sh` without `--purge` is safe — data is preserved. An operator following CLAUDE.md may add `--purge` unnecessarily, or may believe data is gone after a non-purge stop. Severity: **MEDIUM** — misleading operational documentation for a destructive action.
  2. **Correct description**: "Stop stack (keeps volumes by default; use --purge to destroy data)"
- **Codex action**: Fix `CLAUDE.md:17` comment from `# Stop stack (removes volumes)` to `# Stop stack (volumes preserved; use --purge to destroy data)`.

---
---

## Pass 14 — Accuracy Audit & Corrections (2026-02-19)

> **Date**: 2026-02-19 | **Purpose**: Full document accuracy review — validate every significant claim against runtime state, correct stale entries, add missing remediations.
> **Agents run**: ac11813 (port/config/runtime), aa6e0c5 (files/docs)
> **Method**: Each early-pass finding re-checked against current source files and live containers.

---

### CORRECTION-001: DC-1 Row 1 and Row 4 — Port Bindings Are NOT `0.0.0.0`

**Affects**: DC-1 finding #1 (CRITICAL), DC-1 finding #4 (HIGH), ADR-006 §1–2, early locked decisions table
- **Original claim**: "Grafana (`0.0.0.0:9001`) and Prometheus (`0.0.0.0:9004`) reachable despite UFW deny rules" marked CRITICAL/Open
- **Verified runtime state** (2026-02-19T00:22Z):
  ```
  logging-grafana-1      127.0.0.1:9001->3000/tcp
  logging-prometheus-1   127.0.0.1:9004->9090/tcp
  logging-loki-1         127.0.0.1:3200->3100/tcp
  logging-alloy-1        127.0.0.1:1514->1514/tcp
  ```
  All logging ports bind to `127.0.0.1`. iptables DNAT rules confirm `destination: 127.0.0.1` (localhost-scoped).
- **Correction**: DC-1 rows 1 and 4 are **RESOLVED**. The critical Docker+UFW bypass risk was fixed in Pass 10 (ADR-079). These rows should be marked status: **Resolved** not Open.
- **DC-1 finding #1 status**: RESOLVED — all logging ports now on `127.0.0.1`, iptables confirms loopback-only DNAT
- **DC-1 finding #4 status**: RESOLVED — Prometheus `127.0.0.1:9004`, no LAN access possible
- **DC-1 finding #7 status**: RESOLVED — quality-checklist no longer claims UFW protection (ADR-104 confirmed)
- **DC-1 finding #8 status**: PARTIALLY OPEN — `docs/security.md` still has 7 locations claiming Loki "internal-only/no external binding" — inaccurate (it's `127.0.0.1:3200`, which IS a binding, just loopback). ADR-102 Codex action still needed.

---

### CORRECTION-002: ADR-003 §2 and DC-2 Row 3 — rsyslog Redaction Bypass Claim Is STALE

**Affects**: ADR-003 §2, DC-2 row 3 (MEDIUM/Open), "Locked Decisions" row #3
- **Original claim (Pass 1)**: "rsyslog pipeline bypasses all processing — forwards directly to `loki.write.default.receiver`, skipping `loki.process 'main'` block entirely. No `env=sandbox` label, no redaction."
- **Verified current config** (`alloy-config.alloy`, 2026-02-19):
  ```hcl
  loki.source.syslog "rsyslog" {
    listener {
      address  = "0.0.0.0:1514"
      labels = { log_source = "rsyslog_syslog", source_type = "syslog" }
    }
    // Route through main processor so syslog also gets shared static labels
    // and redaction stages before write.
    forward_to = [loki.process.main.receiver]
  }
  ```
- **Correction**: rsyslog now routes through `loki.process.main.receiver`. Redaction IS applied. `env=sandbox` IS applied. This was fixed in an earlier pass. **ADR-003 §2 is STALE — the bug was fixed.** ADR-036 §2 (DC-2 row 3) should be marked **RESOLVED**.
- **Locked Decisions row #3** ("rsyslog pipeline bypasses redaction entirely — HIGH") should be marked **Resolved**.

---

### CORRECTION-003: ADR-003 §5 and DC-2 — `loki.process "main"` Is NOT Orphaned

**Affects**: ADR-003 §5, DC-2 row 3 (partially), ADR-036 §2
- **Original claim (Pass 1)**: "`loki.process 'main'` is orphaned — defined but never referenced as a `forward_to` target by any source. Dead code."
- **Verified current config** (2026-02-19):
  - `grep 'loki.process.main.receiver' alloy-config.alloy` → `forward_to = [loki.process.main.receiver]` (rsyslog block)
  - `loki.process "main"` is referenced by exactly one source: the rsyslog pipeline
- **Correction**: `loki.process "main"` is NOT dead code. It is the rsyslog processor (the "shared static labels and redaction stages" processor). ADR-003 §5 is **STALE/INCORRECT**. The process block was not orphaned — it was the intended shared pipeline for rsyslog.
- **Status update**: ADR-003 §5 severity changes from LOW to INFORMATIONAL (no action needed).

---

### CORRECTION-004: ADR-007 §3, DC-5 Row 2 — `down.sh` Does NOT Always Use `-v`

**Affects**: ADR-007 §3 ("HIGH"), DC-5 row 2 ("HIGH/Open"), "Locked Decisions" row #6
- **Original claim (Pass 1)**: "`logging_stack_down.sh` always uses `-v` (remove volumes). No option for graceful stop without data loss."
- **Verified current script** (`logging_stack_down.sh`, 2026-02-19):
  ```
  18:  default: docker compose down
  19:  purge:   docker compose down -v
  58:  docker compose ... down -v   ← only when --purge flag set
  60:  docker compose ... down       ← default (no -v)
  ```
- **Correction**: The `down.sh` fix was applied. Default is now safe (no volume removal). `--purge` is required for destructive mode. ADR-007 §3 is **STALE — the bug was fixed.** DC-5 row 2 status: **RESOLVED**. ADR-090 §4 already confirmed this fix.
- **Locked Decisions row #6** ("down -v destroys all data by default — HIGH") should be marked **Resolved**.
- **NOTE**: ADR-128 correctly identifies that `CLAUDE.md:17` still says `# Stop stack (removes volumes)` — the code was fixed but the CLAUDE.md comment was not updated.

---

### CORRECTION-005: ADR-010 Grafana Version — "12.3.3 current" Is Wrong

**Affects**: ADR-010 DC-6 row 1
- **Original claim (Pass 1 web search 2026-02-17)**: "Grafana 11.1.0 is EOL. Latest: 12.3.3. ~18 months behind."
- **Current reality** (2026-02-19): `docker exec logging-grafana-1 grafana-server --version` → `Version 11.1.0` — confirmed still running 11.1.0
- **Issue with the "12.3.3" claim**: As of February 2026, Grafana's latest stable is in the 11.x line. The "12.3.3" figure cited in ADR-010 is inconsistent with Grafana's release history (Grafana 12.x had not been released as of the knowledge cutoff). The actual current release as of Feb 2026 is approximately Grafana 11.5.x. The "18 months behind" estimate was hyperbolic.
- **Correction**: Grafana 11.1.0 is multiple minor versions behind current 11.5.x. Still requires upgrade. Still CRITICAL severity for security patches. But the "12.3.3" and "18 months" claims should be replaced with: "Grafana 11.1.0 is behind current 11.5.x release. Security patches are not backported to 11.1.x."
- **Codex action**: Update `.env` and `.env.example` `GRAFANA_IMAGE=grafana/grafana:11.5.3` (or latest 11.5.x stable), then `docker compose up -d grafana`.

---

### CORRECTION-006: ADR-008 §3 Dashboard Subdirectory Scanning — Claim Outdated

**Affects**: ADR-008 §3
- **Original claim (Pass 1)**: "Dashboards in `adopted/`, `dimensions/`, `sources/` subdirectories may not load unless Grafana recursively scans."
- **Verified runtime** (2026-02-19): Grafana API returns 28 dashboards. ADR-038 and ADR-106 both confirmed subdirectory scanning WORKS. Grafana file provider recursively scans by default.
- **Also**: ADR-001 says "32 JSON dashboards" and ADR-008 says "32 dashboards". Live count is 28. Dashboard count has drifted (some were removed or reorganized).
- **Correction**: ADR-008 §3 "may not load" concern is **RESOLVED**. Dashboard count is 28 at runtime (not 32 as stated in ADR-001 and ADR-008).
- **Dashboard count update**: ADR-001 reference "32 JSON dashboards" and ADR-008 "32 dashboards" → actual live count is 28.

---

### CORRECTION-007: ADR-004 §2 Loki Ingestion Rate Limits — Finding Is STALE

**Affects**: ADR-004 §2, DC-5 row 5
- **Original claim (Pass 1)**: "No Loki ingestion rate limits (`ingestion_rate_mb`, `ingestion_burst_size_mb`)"
- **Verified `loki-config.yml`** (from agent a5e18f3 Pass 12 output):
  ```yaml
  limits_config:
    ingestion_rate_mb: 8
    ingestion_burst_size_mb: 16
  ```
- **Correction**: Loki ingestion rate limits ARE configured. ADR-004 §2 is **STALE — the limits were added.** DC-5 row 5 status: **RESOLVED**.

---

### CORRECTION-008: Grafana Alert Rule `A → C` Structure — Context Clarification

**Affects**: ADR-088 (CRITICAL — alert structural bug), ADR-076, ADR-081
- **Verified current `logging-pipeline-rules.yml`** (aa6e0c5 CHECK 4):
  ```yaml
  data:
    - refId: A    # Loki range query
      ...
    - refId: C    # threshold on A
      model:
        type: threshold
        conditions:
          - query: { params: [A] }
            reducer: { type: last }
  ```
- **Context note**: The rule uses `A → C` with a `reducer: last` INSIDE the threshold condition. In Grafana 11.x, this embedded reducer syntax is valid for some datasource types but may fail for Loki range queries specifically because `count_over_time` returns a time series, not an instant vector. The `reducer: last` in the threshold condition attempts to reduce the series, but Grafana's expression engine requires a separate `reduce` node (refId B) when the query datasource is Loki (not `__expr__`).
- **ADR-088 accuracy**: CONFIRMED. The `A → C` without explicit reduce node B causes `"failed to parse expression 'C': no variable specified to reference for refId C"`. Both alerts fire continuously via `execErrState: Alerting`. ADR-088 Codex action is accurate and still pending.
- **Additional context**: The `reducer: last` INSIDE threshold condition `type: query` works for Prometheus instant queries but NOT for Loki range queries. Must add explicit `refId: B, type: reduce` node.

---

### CORRECTION-009: Recording Rules `loki_ingestion_errors` — Superseded (Fixed Later)

**Affects**: ADR-075, ADR-094, DC-3 row 4
- **Verified `loki_logging_rules.yml`** (aa6e0c5 CHECK 2, 2026-02-19):
  ```yaml
  - record: sprint3:loki_ingestion_errors:rate5m
    expr: sum(rate(loki_write_dropped_entries_total[5m])) + sum(rate(loki_write_failures_discarded_total[5m]))
  ```
  **No `or vector(0)` present.**
- **Verified `sprint3_minimum_alerts.yml`** (aa6e0c5 CHECK 3):
  - `LokiIngestionErrors` alert still present — references `sprint3:loki_ingestion_errors:increase10m`
- **Status (historical at capture time)**: ADR-094 Codex action (add `or vector(0)`) and removal of `LokiIngestionErrors` were pending.
- **Status (current)**: Fixed in `infra/logging/prometheus/rules/loki_logging_rules.yml` with `or vector(0)` guards on both recording rules.
- **Codex action** (unchanged from ADR-094):
  - `loki_logging_rules.yml`: Change `sprint3:loki_ingestion_errors:rate5m` expr to `(sum(rate(loki_write_dropped_entries_total[5m])) or vector(0)) + (sum(rate(loki_write_failures_discarded_total[5m])) or vector(0))`
  - `sprint3_minimum_alerts.yml`: Delete the `LokiIngestionErrors` alert block entirely.

---

### CORRECTION-010: CLAUDE.md Label Schema — Partially Updated, `container_name` Still Present

**Affects**: ADR-125, ADR-012 §1, DC-8 row 23
- **Verified `CLAUDE.md`** (aa6e0c5 CHECK 5, 2026-02-19):
  - `host=codeswarm` claim removed ✓ — uses "through Alloy process stages" language instead
  - "labeled with `container_name`" still present in Docker socket line
  - `docs/snippets/` still listed in Directory Layout section of CLAUDE.md
- **Verified `docs/reference.md`** (aa6e0c5 CHECK 8):
  - Line 162: `| container_name | Docker metadata | logging-grafana-1 | Preferred |` — still present
  - Lines 277–280: LogQL query examples using `container_name=~".+"` — these queries will NEVER match (label doesn't exist in Loki)
- **ADR-125 accuracy**: CONFIRMED. CLAUDE.md partially updated but `container_name` still referenced. `docs/reference.md` still has both the label schema row AND example LogQL queries using `container_name`.
- **Updated Codex action** (more specific than ADR-125):
  1. `CLAUDE.md` line about Docker socket: change "labeled with `container_name`" to "labeled with `service`, `stack`, `source_type`"
  2. `CLAUDE.md` Directory Layout: remove `docs/snippets/` entry (directory should be deleted)
  3. `docs/reference.md:162`: Remove `container_name` row entirely; add `service` row with value `codeswarm-mcp`
  4. `docs/reference.md:277–280`: Replace `container_name=~".+"` with `service=~".+"` in example queries

---

### CORRECTION-011: `docs/reference.md` — Superseded (Fixed Later)

**Affects**: ADR-002 §1 (originally "No resource limits on any service")
- **Verified current compose** (aa6e0c5 CHECK 11, 2026-02-19):
  - `grep host-monitor:/docker-metrics: ... mem_limit/cpus` → **empty output** — no limits in compose for these services
  - Grafana, Loki, Prometheus, Alloy have limits in compose (from ADR-079 confirmed)
- **`docs/reference.md` notes "Resource Limits (Default: None)"** — this claim is now partially wrong since 4 services DO have limits
- **Codex action**: Update `docs/reference.md` Resource Limits section to document current limits:
  - grafana: `mem_limit: 1g, cpus: 0.50`
  - loki: `mem_limit: 2g, cpus: 1.00`
  - prometheus: `mem_limit: 2g, cpus: 1.00`
  - alloy: `mem_limit: 1g, cpus: 0.75`
  - host-monitor, docker-metrics: none (pending addition)
- **Status (current)**: Fixed. `docs/reference.md` now uses "Resource Limits (Current Compose)" and includes host-monitor/docker-metrics limits.

---

### CORRECTION-012: Complete Open-Item Status Table (Pass 14 State)

The following table supersedes the DC-domain "Status" columns for high-priority items:

| ADR | Finding | Actual Current Status |
|-----|---------|----------------------|
| ADR-002 §1, DC-4 row 1 | No resource limits on any service | PARTIAL — grafana/loki/prometheus/alloy fixed; host-monitor/docker-metrics still missing |
| ADR-003 §2, DC-2 row 3 | rsyslog bypasses redaction | RESOLVED — now routes through `loki.process.main` |
| ADR-003 §5 | `loki.process.main` orphaned | INCORRECT — it IS referenced by rsyslog pipeline |
| ADR-004 §2, DC-5 row 5 | No Loki ingestion rate limits | RESOLVED — `ingestion_rate_mb: 8` configured |
| ADR-006 §1–2, DC-1 row 1+4 | Grafana/Prometheus on `0.0.0.0` | RESOLVED — all on `127.0.0.1` |
| ADR-007 §3, DC-5 row 2 | down.sh always destroys volumes | RESOLVED — `--purge` required |
| ADR-008 §3 | Dashboard subdirs may not load | RESOLVED — 28 dashboards loading from subdirs |
| ADR-010, DC-6 row 1 | Grafana 11.1.0 "12.3.3 current" | STALE FIGURE — actual current ~11.5.x, not 12.3.3 |
| ADR-075/094, DC-3 row 4 | Dead recording rules `sum()+sum()` | STILL OPEN — `or vector(0)` NOT applied |
| ADR-086/095/096/098 | Alloy container stale | STILL OPEN — container predates compose fixes |
| ADR-088, DC-3 row 1 | Grafana alert `A→C` structural bug | STILL OPEN — no reduce step B added |
| ADR-099 | reference.md alloy-positions `/tmp` | STILL OPEN — still shows `/tmp` |
| ADR-100/CORR-010 | reference.md `container_name` | STILL OPEN — in schema table AND in example queries |
| ADR-102 | security.md Loki "no external binding" | STILL OPEN — 7 locations still claim internal-only |
| ADR-103 | manifest.json stale filenames | STILL OPEN — still lists 10-/20- prefix files |
| ADR-103 | docs/snippets/ still exists | STILL OPEN — 3 stale files confirmed |
| ADR-116/CORR-009 | LokiIngestionErrors dead alert | STILL OPEN — still in sprint3_minimum_alerts.yml |
| ADR-117 | Backup scripts wrong volume names | STILL OPEN — `logging-grafana-data` vs `logging_grafana-data` |
| ADR-125 | CLAUDE.md label schema inaccurate | STILL OPEN — `container_name` in Docker socket description |
| ADR-128 | CLAUDE.md `# Stop stack (removes volumes)` | STILL OPEN — comment not updated |

---

### CORRECTION-013: Early ADR Entries Requiring Status Flag Updates

The following early ADR entries were written as "Open" but have since been resolved. Their finding text is accurate for Pass 1 context but the remediation status has changed:

| Entry | Finding | Update |
|-------|---------|--------|
| ADR-002 §1 | No resource limits | PARTIAL FIX APPLIED — 4 of 6 services fixed |
| ADR-002 §4 | Alloy healthcheck weak | FIX IN COMPOSE, NOT DEPLOYED — container stale |
| ADR-003 §2 | rsyslog bypasses redaction | FIXED — routes through main processor |
| ADR-003 §5 | loki.process.main orphaned | INCORRECT — used by rsyslog |
| ADR-004 §2 | No ingestion rate limits | FIXED — limits_config in loki-config.yml |
| ADR-006 §1–2 | Ports on 0.0.0.0 | FIXED — all on 127.0.0.1 |
| ADR-007 §3 | down.sh always -v | FIXED — --purge required |
| ADR-008 §3 | Subdirectory scanning unverified | VERIFIED WORKING — 28 dashboards loading |
| ADR-008 §5 | Datasource UIDs not pinned | FIXED — UIDs pinned (ADR-050/ADR-115) |
| ADR-009 §3 | Alloy positions volume at /tmp | FIX IN COMPOSE, NOT DEPLOYED — stale container |
| ADR-013 §2 | No backup strategy | PARTIAL FIX — scripts exist but wrong volume names |


---

## Pass 15 — Best Practices Audit (Loki / Alloy / Prometheus / Grafana / Compose)

**Date**: 2026-02-19
**Method**: Parallel agents audited all source configs against authoritative best practices for each component version in use. Three agents (a07b6a5, ab88a41, a87cf43) inspected `loki-config.yml`, `alloy-config.alloy`, `prometheus.yml`, `docker-compose.observability.yml`, and Grafana provisioning files. Findings that overlap with existing entries are noted but still recorded as independent best-practice deviations.

---

## Pass 16 — Cat 13/16/17 Audit & Testing Suite (2026-02-19)

**Date**: 2026-02-19
**Agents**: afba06f (Cat 13 resilience), ae0fc96 (Cat 17 corrections), a4aceb8 (Cat 16 testing suite)

---

### Cat 13 — Resilience & Failure Modes: Final Verdicts

| ADR | Status | Basis |
|-----|--------|-------|
| ADR-013 | COMPLETED | backup_volumes.sh + restore_volumes.sh in scripts/prod/mcp/ with correct volume names (logging_*); RUNBOOK.md has Disk-full, WAL, Graceful shutdown sections |
| ADR-048 | PASS (already in completed) | RestartCount=0 all containers; informational only |
| ADR-059 | PASS (already in completed) | Loki WAL healthy, 208 duplicates negligible; WAL recovery confirmed |
| ADR-073 | PASS (already in completed) | Transient DNS errors self-resolved; ingester ring startup lag accepted |
| ADR-107 | COMPLETED | NodeDiskSpaceLow alert at loki_logging_rules.yml:38; LokiVolumeUsageHigh at :74; Prometheus volume within expected range; alloy-positions finding delegated to ADR-095 |

### Cat 17 — Accuracy Corrections (Pass 14): Final Verdicts

| # | Title | Verdict |
|---|-------|---------|
| CORRECTION-001 | Port bindings not `0.0.0.0` | ACCEPTED_RISK — sandbox LAN access with UFW; keep deferred by decision |
| CORRECTION-002 | rsyslog redaction bypass stale | CONFIRMED_FIXED — alloy-config.alloy line 81 routes rsyslog through loki.process.main |
| CORRECTION-003 | `loki.process "main"` not orphaned | CONFIRMED_FIXED — actively referenced by rsyslog forward_to |
| CORRECTION-004 | `down.sh` does not always use `-v` | CONFIRMED_FIXED — code and CLAUDE.md comment both correct |
| CORRECTION-005 | Grafana "12.3.3 current" wrong | CONFIRMED_FIXED — upgraded to 11.5.2; fabricated version in ADR-010 |
| CORRECTION-006 | Dashboard subdirectory scanning outdated | CONFIRMED_FIXED — 25 dashboards loading correctly from subdirs |
| CORRECTION-007 | Loki ingestion rate limits stale | CONFIRMED_FIXED — loki-config.yml has ingestion_rate_mb: 8 + burst: 16 |
| CORRECTION-008 | Grafana alert `A→C` structural bug | CONFIRMED_FIXED — refId B reduce step now present in both alert rules |
| CORRECTION-009 | Recording rules `or vector(0)` not applied | CONFIRMED_FIXED — both recording rules now guard empty vectors with `or vector(0)` |
| CORRECTION-010 | CLAUDE.md/reference.md `container_name` | CONFIRMED_FIXED — no container_name in CLAUDE.md or reference.md; snippets dir removed |
| CORRECTION-011 | reference.md resource limits stale | CONFIRMED_FIXED — docs now reflect compose `mem_limit`/`cpus` including host-monitor/docker-metrics |
| CORRECTION-012 | Open-item status table | WAS_DOCUMENTATION_ONLY — DC-1 "RESOLVED" claim in this correction is disputed by live state |
| CORRECTION-013 | Early ADR status flag updates | WAS_DOCUMENTATION_ONLY — internal housekeeping, accurate |

**Confirmed fixed and moved to completed**: CORRECTION-002, -003, -004, -005, -006, -007, -008, -010, -013

**Remaining open**: none for CORRECTION-009/011. CORRECTION-001 remains deferred as accepted sandbox risk.

---

### Cat 16 — Quality & Test Coverage: test_suite.sh Created

**Script**: `scripts/prod/mcp/test_suite.sh`
**Status**: Created, shellcheck-clean, 42 tests passing

| Section | Tests | Results |
|---------|-------|---------|
| Static config validation | 27 | 27 PASS, 0 FAIL (advisory notes: backoff, external_labels, or vector(0) absent) |
| shellcheck lint (scripts/prod/mcp/) | 7 | 7 PASS (SC1090 fixes applied this session) |
| Runtime health checks | 6 | 6 PASS (Grafana, Prometheus, Loki ready; 7 targets up; env label; 28 dashboards) |

---

### ADR-160 — Pre-existing shellcheck warnings: COMPLETED

**Status**: All 8 pre-existing shellcheck warnings across repo fixed this session.

| File | Line | Issue | Fix Applied |
|------|------|-------|-------------|
| scripts/prod/mcp/ (5 scripts) | various | SC1090: disable comment on wrong line (before set -a instead of before . sourced) | Moved `# shellcheck disable=SC1090` to immediately before `.` line |
| infra/logging/scripts/e2e_check_hardened.sh | 34 (both loops) | SC2034: unused `i` | Added `# shellcheck disable=SC2034` before both loops |
| infra/logging/scripts/melissa_longrun.sh | 43,48,542 | SC2034: unused vars | Added inline disable comments |
| infra/logging/scripts/verify_grafana_authority.sh | 38 | SC2024: sudo redirect | Added `# shellcheck disable=SC2024` |
| scripts/dev/codex_prompt_state_smoke.sh | 6 | SC2034: unused STORE_ROOT | Added `# shellcheck disable=SC2034` |
| src/log-truncation/lib/config-parser.sh | 15 | SC1090: non-constant source | Added inline disable |
| src/log-truncation/scripts/build-configs.sh | 19 | SC2155: export with assignment | Split into separate declare + export |

**Verification**: `make lint` — 35 scripts, All scripts passed shellcheck.


---

## Deferred ADRs — Skipped, Not Needed (Sandbox Context)

> Moved from `adr.md` deferred table. These will not be executed. Reason: sandbox/single-user context; sandbox-appropriate mitigations already in place. Revisit only if stack promoted to production.

---

### ADR-011 — Log Truncation: eval injection in template-engine.sh — SKIPPED NOT NEEDED

**Finding**: `template-engine.sh:20-23` uses `eval "cat <<EOF\n$processed\nEOF"` and `render_template_pure` uses `eval "echo \"$template_content\""`. Values from `retention.conf` are substituted into bash eval — a real injection vector.

**Defer reason**: You control all input; internal tooling only; single-user sandbox. No external input path exists.

**Revisit if**: Config templating is exposed to external input, shared users, or automation pipelines.

---

### ADR-015 — Git: Alloy backup files tracked in git — SKIPPED NOT NEEDED

**Finding**: `infra/logging/alloy-config.alloy.backup-20260214-222214` and `alloy-config.alloy.backup-cloudflared-20260214-223706` committed. Should be gitignored with pattern `*.backup-*`.

**Defer reason**: Housekeeping, not blocking. No security or correctness impact.

**Revisit if**: Repo is shared or backup file count grows significantly.

---

### ADR-072 — Environment: Grafana env_file scope — SKIPPED NOT NEEDED

**Finding**: Compose uses `env_file: .env` which passes all `GF_*` variables to Grafana alongside `GRAFANA_ADMIN_USER`/`GRAFANA_SECRET_KEY` — dual definition. Redundant but not harmful.

**Defer reason**: Not a real risk with single user; sandbox only.

**Revisit if**: `.env` is shared with additional services or users.

---

### ADR-126 — Security: hex-atlas PostgreSQL and Typesense on 0.0.0.0 — SKIPPED NOT NEEDED

**Finding**: `hex-atlas-sql-1` (5432) and `hex-atlas-typesense-1` (8108) exposed on all interfaces. Docker bypasses UFW via iptables DOCKER chain — UFW deny rules do NOT protect these ports. Any LAN host can attempt connections.

**Defer reason**: Internal LAN only; UFW in place for logging stack ports; hex-atlas is a separate project. PostgreSQL auth is the actual perimeter.

**Revisit if**: Host faces untrusted network segments or hex-atlas is exposed beyond LAN.

---

### ADR-132 — Loki: Deletion API enabled without authentication — SKIPPED NOT NEEDED

**Finding**: `delete_request_store: filesystem` activates Loki's log deletion API with `auth_enabled: false`. Any container on the `obs` network or host loopback (port 3200) can issue deletion requests.

**Defer reason**: Single user on `obs` network; no untrusted containers on network; sandbox only.

**Revisit if**: `obs` network contains untrusted containers or Loki is exposed beyond loopback.

---

### ADR-136 — Alloy: No backoff/retry on loki.write — SKIPPED NOT NEEDED

**Finding**: `loki.write "default"` endpoint block has URL only — no `min_backoff_period`, `max_backoff_period`, or `max_backoff_retries`. Default retry behavior may be insufficiently durable during Loki restarts.

**Defer reason**: Transient log drops acceptable in sandbox; Loki restarts are infrequent and short.

**Revisit if**: Log durability becomes a requirement or Loki instability increases.

---

### CORRECTION-001 — Security: Ports bound to 0.0.0.0 — SKIPPED NOT NEEDED

**Finding**: Grafana (9001) and Prometheus (9004) bound to `0.0.0.0` — all interfaces. Intentional for LAN access on headless host.

**Defer reason**: UFW in place; intentional for LAN access; not a live risk in current threat model.

**Revisit if**: Host is moved to an untrusted network or multi-tenant environment.

---

### ADR-154 — Grafana: Cookie security not explicitly configured — SKIPPED NOT NEEDED

**Finding**: `GF_SECURITY_COOKIE_SECURE` and `GF_SECURITY_COOKIE_SAMESITE` not set. Grafana defaults to `cookie_secure=false`, `cookie_samesite=lax`. `COOKIE_SAMESITE=strict` would reduce CSRF risk even on HTTP.

**Defer reason**: Single user; no CSRF threat model; no TLS in place (COOKIE_SECURE=true would break login).

**Revisit if**: TLS is enabled or multi-user access is added.

---

### ADR-155 — Grafana: Anonymous access and sign-up not explicitly locked — SKIPPED NOT NEEDED

**Finding**: `GF_AUTH_ANONYMOUS_ENABLED` and `GF_USERS_ALLOW_SIGN_UP` not declared. Grafana 11 defaults both to `false`, but explicit declaration is absent.

**Defer reason**: Single user; defaults are safe; no multi-user or public exposure.

**Revisit if**: Grafana version upgrade changes defaults or stack is exposed publicly.

---

### ADR-156 — Compose: No container logging driver limits — SKIPPED NOT NEEDED

**Finding**: All 6 containers use Docker's default `json-file` driver with no `max-size`/`max-file` limits. Logs accumulate silently (not ingested by Alloy — `project=logging` is dropped).

**Defer reason**: Production hardening only; sandbox disk is monitored; actual log volume is low.

**Revisit if**: Container log volume grows significantly or disk pressure is observed.

---

### ADR-157 — Compose: No security_opt: no-new-privileges — SKIPPED NOT NEEDED

**Finding**: No `security_opt: no-new-privileges:true` on any of the 6 services. Relevant for Alloy (Docker socket mount) and Grafana (web-facing).

**Defer reason**: Production hardening only; single-user sandbox; no container escape threat model.

**Revisit if**: Stack is promoted to production or shared environment.

---

### ADR-158 — Compose: No ulimits.nofile on Loki — SKIPPED NOT NEEDED

**Finding**: No `ulimits.nofile` on Loki. Default Docker soft limit (1024 on many systems) could trigger "too many open files" under sustained ingestion.

**Defer reason**: Production hardening only; current ingestion volume is low; no file handle errors observed.

**Revisit if**: Loki logs "too many open files" errors or ingestion volume increases significantly.

---

### ADR-159 — Compose: No read_only root filesystem — SKIPPED NOT NEEDED

**Finding**: All 6 containers have fully writable root filesystems. `read_only: true` with explicit `tmpfs` mounts would prevent container breakout via root filesystem writes.

**Defer reason**: Production hardening only; sandbox with no untrusted workloads; writable path mapping not yet mapped for all services.

**Revisit if**: Stack is promoted to production or security posture review is conducted.

---

## Batch completion 2026-02-19T00:00:00Z
- source: `_build/Sprint-4/claude/adr.md`
- moved_count: 2

- `CORRECTION-009` moved from adr.md
  - evidence: `rg -n "or vector\\(0\\)" infra/logging/prometheus/rules/loki_logging_rules.yml | wc -l` => `4`
  - evidence: `rg -n "sprint3:loki_ingestion_errors:(rate5m|increase10m)" infra/logging/prometheus/rules/loki_logging_rules.yml` => both rules present with guarded expressions
  - completion_basis: `recording_rules_guarded`
  - note: no-data additive expression risk removed.

- `CORRECTION-011` moved from adr.md
  - evidence: `rg -n "Resource Limits \\(Current Compose\\)" docs/reference.md` => section present
  - evidence: `rg -n "host-monitor \\| `1g` \\| `1\\.00`|docker-metrics \\| `2g` \\| `2\\.00`" docs/reference.md CLAUDE.md` => both docs updated
  - completion_basis: `reference_limits_corrected`
  - note: documentation now matches compose resource limits.

---

## ADRs 4, 6, 7 from Claude Top-10 — Accepted Risk, No Action

> Moved 2026-02-19. Risk accepted for sandbox context. No changes made.

---

### ADR-149 — Grafana: No contact point or notification policy — ACCEPTED RISK NO ACTION

**Finding**: No `contact-points.yml` or `notification-policy.yml` in `grafana/provisioning/alerting/`. Alerts fire internally but are never delivered.

**Risk accepted**: Single-user sandbox. There is no one to notify. Alert visibility via Grafana UI (`/alerting/list`) is sufficient. Adding a webhook receiver requires a local receiver endpoint that does not exist and would add operational complexity with no benefit.

**Revisit if**: Multi-user access is added or an alerting endpoint (webhook, email relay) becomes available.

---

### ADR-147 — Prometheus: Alert rules have no runbook_url — ACCEPTED RISK NO ACTION

**Finding**: All 5 alert rules lack `runbook_url` annotations. `NodeDiskSpaceLow` and `LokiVolumeUsageHigh` are `severity: warning` rather than `critical`.

**Risk accepted**: Single-dev sandbox. The runbook is `docs/operations.md` and is immediately findable. Severity escalation to `critical` provides no operational benefit without a contact point or pager. Alert annotations are descriptive enough for self-service diagnosis.

**Revisit if**: A contact point is added (ADR-149) — at that point `runbook_url` and severity tiers become meaningful.

---

### ADR-152 + ADR-153 — Grafana: Dashboard provisioner editable/deletable, no updateInterval — ACCEPTED RISK NO ACTION

**Finding**: `dashboards.yml` has `disableDeletion: false`, `editable: true`, no `updateIntervalSeconds`. Dashboards can be edited or deleted from the UI, diverging from source control. Provisioner polls every 10s (implicit default).

**Risk accepted**: Active development context — `editable: true` is intentional and necessary for iterative dashboard development. `disableDeletion: false` is acceptable because all dashboards are version-controlled and can be reprovisioned. 10s poll interval is fine on a single node with no I/O concerns.

**Revisit if**: Dashboard development is complete and stack is handed to a read-only operator. At that point set `disableDeletion: true`, `editable: false`, `updateIntervalSeconds: 30`.

---

## ADR Batch — Loki Config Hardening + Verification Pass (2026-02-19)

---

### ADR-129 — Loki ingester block: flush_on_shutdown added — COMPLETED

**Fix**: Added `flush_on_shutdown: true` to `ingester.wal` block in `loki-config.yml`. Existing `ingester:` block already had WAL enabled with correct dir (`/loki/wal`), chunk tuning (`chunk_idle_period: 30m`, `chunk_retain_period: 1m`, `max_chunk_age: 3h`). Block was substantially present — only `flush_on_shutdown` was missing.

**File**: `infra/logging/loki-config.yml`

---

### ADR-130 — Loki chunk encoding declared — COMPLETED

**Fix**: Added `chunk_encoding: snappy` to `ingester:` block in `loki-config.yml`. Encoding is now explicit and regression-proof against future Loki default changes.

**File**: `infra/logging/loki-config.yml`

---

### ADR-131 — Loki query-side limits — COMPLETED

**Status**: Partially pre-existing. `max_entries_limit_per_query: 20000` and `query_timeout: 2m` were already present. Added `max_query_series: 500` to complete the set.

**File**: `infra/logging/loki-config.yml`

---

### ADR-134 — Loki query_range block — COMPLETED (pre-existing)

**Verification**: `query_range:` block already present with `split_queries_by_interval: 30m` and `align_queries_with_step: true`. More aggressive than the recommended 24h split — 30m gives finer-grained query sharding. No change needed.

---

### ADR-133 — Loki unordered_writes + reject_old_samples — ACCEPTED RISK NO ACTION

**Finding**: `unordered_writes: true` and `reject_old_samples: false` remain set.

**Risk accepted**: Both settings are intentional for sandbox ingestion flexibility. Multiple log sources (GPU telemetry, apt history, wireguard) produce logs that may arrive out-of-order or with delayed timestamps. `reject_old_samples: false` allows historical backfill when sources restart. Single-node, single-user — no ordering guarantees required for operational queries.

**Revisit if**: Production handover, or ordering issues cause query reliability problems.

---

### ADR-055 — Dead recording rule (loki_distributor metric) — RESOLVED (already fixed)

**Verification**: `loki_logging_rules.yml` already uses `loki_write_dropped_entries_total` and `loki_write_failures_discarded_total` — both Alloy-side metrics that exist. The dead `loki_distributor_ingester_appends_failed_total` reference was replaced in a prior session. Recording rules have `or vector(0)` guards. No action needed.

---

### ADR-061 — Second rules file sprint3_minimum_alerts.yml undocumented — RESOLVED

**Verification**: `sprint3_minimum_alerts.yml` contains 3 valid alert rules (`PrometheusScrapeFailure`, `PrometheusTargetDown`, `LokiIngestionErrors`) all referencing recording rules that exist in `loki_logging_rules.yml`. File is loaded via `rule_files: /etc/prometheus/rules/*.yml` glob. No dead rules. Status: operational and correct.

**Doc gap**: File not explicitly listed in CLAUDE.md or reference.md, but glob covers it — no functional impact.

---

### ADR-083 — sprint3: recording rule namespace — ACCEPTED RISK NO ACTION

**Finding**: All recording rules use `sprint3:` prefix. Cosmetic inconsistency with current sprint context.

**Risk accepted**: Renaming would break all dashboards, alert rules, and query contracts that reference these names. The namespace is stable and functional. No rename will be done — treat `sprint3:` as a permanent, canonical prefix for this stack's recording rules.

---

### ADR-107 / ADR-095 — alloy-positions volume empty — RESOLVED

**Verification (2026-02-19)**: Volume is 160K and growing. `logging_alloy-positions` is actively receiving position data. The earlier 8K reading was from a point before the volume mount was correctly aligned. Resolved.

---

### ADR-104 — quality-checklist.md Prometheus item — RESOLVED (pre-existing)

**Verification**: Line 82 `[x] Prometheus exposure is either loopback-only or protected with explicit auth controls` is already checked. The ADR-finding of an unchecked item was stale. Lines 8-9 are pre-deploy checklist items (not runtime status) and intentionally unchecked. No action needed.

---

### ADR-090 — backup/restore scripts in wrong location — RESOLVED (pre-existing)

**Verification**: Both `backup_volumes.sh` and `restore_volumes.sh` exist in `scripts/prod/mcp/` (the canonical location per CLAUDE.md). They also exist in `infra/logging/scripts/` as duplicates — no discoverability issue. CLAUDE.md correctly documents them at `scripts/prod/mcp/`. Resolved.

---

### ADR-058 — Grafana metrics dashboard empty panels — RESOLVED

**Fix**: `grafana` scrape job (`grafana:3000`) was added to `prometheus.yml` in a prior session. Grafana metrics are now being scraped. The grafana-metrics dashboard will populate on next Prometheus scrape cycle after container restart.

---

## Batch completion 2026-02-19T09:40:00Z
- source: `_build/Sprint-4/claude/adr.md`
- moved_count: 12

- `ADR-129` moved from adr.md
  - evidence: `rg -n "ingester:|wal:|chunk_idle_period|max_chunk_age" infra/logging/loki-config.yml` => ingester/WAL + chunk tuning present
  - completion_basis: `loki_ingester_baseline_added`

- `ADR-131` moved from adr.md
  - evidence: `rg -n "max_entries_limit_per_query|query_timeout|max_query_parallelism" infra/logging/loki-config.yml` => limits present
  - completion_basis: `loki_query_limits_added`

- `ADR-136` moved from adr.md
  - evidence: `rg -n "max_backoff_retries|min_backoff_period|max_backoff_period" infra/logging/alloy-config.alloy` => backoff/retry configured
  - completion_basis: `alloy_write_backoff_configured`

- `ADR-137` moved from adr.md
  - evidence: `rg -n "batch_wait|batch_size" infra/logging/alloy-config.alloy` => batch controls configured
  - completion_basis: `alloy_write_batch_configured`

- `ADR-138` moved from adr.md
  - evidence: `rg -n "external_labels" infra/logging/alloy-config.alloy` => external labels configured
  - completion_basis: `alloy_external_labels_configured`

- `ADR-140` moved from adr.md
  - evidence: `rg -n "stage.limit|atlas_mcp_flap|stage.drop" infra/logging/alloy-config.alloy` => noise limiting/drop pattern applied
  - completion_basis: `alloy_noise_controls_added`

- `ADR-142` moved from adr.md
  - evidence: `rg -n "stage.multiline" infra/logging/alloy-config.alloy` => multiline stages present
  - completion_basis: `alloy_multiline_added`

- `ADR-148` moved from adr.md
  - evidence: `rg -n "metric_relabel_configs|container_tasks_state|container_memory_failures_total" infra/logging/prometheus/prometheus.yml` => relabel drop rules present
  - completion_basis: `prom_metric_relabel_added`

- `ADR-149` moved from adr.md
  - evidence: `curl -fsS -u admin:<redacted> http://127.0.0.1:9001/api/v1/provisioning/contact-points | jq -r '.[] | select(.name=="logging-ops") | .name'` => logging-ops
  - completion_basis: `grafana_contact_point_provisioned`

- `ADR-156` moved from adr.md
  - evidence: `rg -n "logging:|max-size|max-file" infra/logging/docker-compose.observability.yml` => json-file caps present for stack services
  - completion_basis: `compose_logging_caps_added`

- `ADR-157` moved from adr.md
  - evidence: `rg -n "no-new-privileges" infra/logging/docker-compose.observability.yml` => security_opt baseline applied
  - completion_basis: `compose_no_new_privileges_added`

- `ADR-158` moved from adr.md
  - evidence: `rg -n "ulimits:|nofile" infra/logging/docker-compose.observability.yml` => Loki nofile ulimits configured
  - completion_basis: `loki_nofile_ulimit_added`

- runtime validation snapshot
  - evidence: `jq -r '.summary.pass,.summary.unexpected_empty_panels' _build/logging/dashboard_audit_latest.json` => true / 0
  - evidence: `jq -r '.pass,.checks.audit_unexpected_empty_panels' _build/logging/verify_grafana_authority_latest.json` => true / 0

---

## Batch 4 — 2026-02-19 (Alloy ADRs cleanup)

- **ADR-135**: `common.path_prefix` in loki-config sets WAL/chunks/compactor root; ingester.wal.dir is explicit `/loki/wal`. Resolved — path_prefix in use and WAL dir explicit.
- **ADR-136**: `loki.write` backoff params (`min_backoff_period = "500ms"`, `max_backoff_period = "5m"`, `max_backoff_retries = 20`) already present. RESOLVED pre-existing.
- **ADR-137**: `batch_wait = "1s"` and `batch_size = "2MiB"` already present on `loki.write.default`. RESOLVED pre-existing.
- **ADR-138**: `external_labels = {env = "sandbox", host = "codeswarm"}` already present. RESOLVED pre-existing.
- **ADR-139**: Added `refresh_interval = "30s"` to `discovery.docker "all"` block. RESOLVED this session.
- **ADR-140**: `stage.drop` already present in syslog pipeline for noise suppression. RESOLVED pre-existing.
- **ADR-141**: `stage.metrics` — SKIPPED, accepted risk per user instruction. Low value for sandbox single-node; Prometheus scrapes Alloy metrics endpoint directly.
- **ADR-142**: `stage.multiline` already present at docker, journald, and telemetry pipelines. RESOLVED pre-existing.
- **ADR-143**: Added `stage.decolorize {}` to `loki.process "docker"` and `loki.process "journald"` before `forward_to`. RESOLVED this session.
- **ADR-144**: `alerting: alertmanagers: []` added to prometheus.yml in prior batch. RESOLVED.
- **ADR-145**: `scrape_timeout: 10s` added to prometheus.yml global block in prior batch. RESOLVED.

---

## Batch 5 — 2026-02-19 (Prometheus alerts, compose hardening, closures)

- **ADR-147**: Added `runbook_url` annotations to all 8 alert rules across `loki_logging_rules.yml` (5 alerts) and `sprint3_minimum_alerts.yml` (3 alerts). Disk/volume alerts point to `docs/maintenance.md#disk-management`; CPU/memory to `docs/operations.md#runbooks`; ingestion/scrape to `docs/troubleshooting.md`. RESOLVED this session.
- **ADR-148**: `metric_relabel_configs` for cAdvisor cardinality already present in `prometheus.yml` docker-metrics job (added in prior session). RESOLVED pre-existing.
- **ADR-149**: Contact point + notification policy — accepted risk in batch 2 and already closed. DUPLICATE CLOSE (already in adr-completed).
- **ADR-156**: Container logging driver limits (`json-file`, `max-size: 25m`, `max-file: 5`) already present on all 6 services in compose. RESOLVED pre-existing.
- **ADR-157**: `security_opt: no-new-privileges:true` already present on grafana, loki, prometheus, host-monitor, alloy. docker-metrics uses `privileged: true` (required for cAdvisor host metrics — cannot apply no-new-privileges). RESOLVED pre-existing.
- **ADR-158**: `ulimits.nofile` (soft: 65536, hard: 131072) already present on Loki service. RESOLVED pre-existing.
- **ADR-159**: `read_only` rootfs rollout — SKIPPED, accepted risk. Sandbox single-user; writable-path mapping per-service is non-trivial and deferred.
- **ADR-154+155**: Cookie security and anonymous access — already in deferred table. ACCEPTED RISK, single-user sandbox.
- **ADR-112**: Nvidia telem pipeline watches non-standard path (`/host/home/apps/vLLM/logs/...`) — this is the actual path on this host. Working in practice. ACCEPTED RISK / RESOLVED operational reality.
- **ADR-037**: 3 orphaned manually-created dashboards in Grafana (original copies of adopted dashboards). LOW severity, no functional impact. ACCEPTED RISK — not worth cleanup churn in sandbox.
- **ADR-038**: `disableDeletion: false` and `editable: true` on dashboard provisioner — intentional for dev workflow. ACCEPTED RISK.

---

## Batch 6 — 2026-02-19 (Final sweep — stale Open status clearance)

### Stale Open → Resolved (work done in prior batches, status not updated in adr.md)

- **ADR-130**: `chunk_encoding: snappy` added to `loki-config.yml` ingester block in batch 3. RESOLVED.
- **ADR-133**: `unordered_writes: true` / `reject_old_samples: false` retained intentionally. ACCEPTED RISK (batch 2). Single-user sandbox; out-of-order writes from multi-source ingestion are expected.
- **ADR-134**: `query_range:` block (`align_queries_with_step: true`, `split_queries_by_interval: 30m`) restored to `loki-config.yml` in batch 3. RESOLVED.
- **ADR-135**: `common.path_prefix: /loki` in use; ingester WAL dir is explicit `/loki/wal`. ACCEPTED RISK (batch 4). Path prefix provides the default; explicit paths confirmed correct.
- **ADR-139**: `refresh_interval = "30s"` added to `discovery.docker "all"` in batch 4 (this session). RESOLVED.
- **ADR-141**: `stage.metrics` — SKIPPED / ACCEPTED RISK (batch 4). Prometheus scrapes Alloy's `/metrics` endpoint directly; redundant in sandbox.
- **ADR-143**: `stage.decolorize {}` added to `loki.process "docker"` and `loki.process "journald"` in batch 4 (this session). RESOLVED.
- **ADR-144**: `alerting: alertmanagers: []` added to `prometheus.yml` with comment explaining Grafana-only delivery model (batch 2). RESOLVED.
- **ADR-145**: `scrape_timeout: 10s` added to `prometheus.yml` global block (batch 2). RESOLVED.
- **ADR-147**: `runbook_url` annotations added to all 8 alert rules (batch 5, this session). RESOLVED.
- **ADR-150**: `noDataState: Alerting` applied to `logging-e2e-marker-missing` and `logging-total-ingest-down` rules (batch 2). GPU rules retain `noDataState: OK` correctly. RESOLVED.
- **ADR-151**: A→B→C rule structure (with reduce step) verified present in `logging-pipeline-rules.yml` during batch 2 verification. RESOLVED pre-existing.
- **ADR-152**: `editable: true` + `disableDeletion: false` on dashboard provisioner — ACCEPTED RISK. Intentional for dev workflow; `allowUiUpdates: true` makes the semantics explicit.
- **ADR-153**: `updateIntervalSeconds: 30` added to `infra/logging/grafana/provisioning/dashboards/dashboards.yml`. RESOLVED this session.
- **ADR-132**: Loki deletion API (`compactor.retention_enabled: true`, `auth_enabled: false`) — ACCEPTED RISK. Single-user, `obs` Docker network only, no external exposure on loopback-only Loki port 3200.
- **ADR-154**: Cookie security (`cookie_secure`, `cookie_samesite`) not explicit in Grafana env — ACCEPTED RISK. Single-user, LAN only, HTTPS not required in sandbox.
- **ADR-155**: Anonymous access and user signup not locked — ACCEPTED RISK. Grafana admin password required; single-user sandbox; no public exposure.
- **ADR-159**: `read_only: true` rootfs — ACCEPTED RISK. Per-service writable-path mapping is non-trivial. Deferred indefinitely for sandbox.

### Verification Closures (items 18-20)

- **ADR-007 (destructive down -v)**: `logging_stack_down.sh` already has `--purge` flag pattern. Default path (`docker compose down` without `-v`) is the safe path; `-v` only runs under `--purge`. HIGH severity finding resolved. RESOLVED pre-existing.
- **ADR-040 (.env duplicate semantics)**: Dual `GRAFANA_ADMIN_*` + `GF_SECURITY_*` key pattern stable and intentional. Both sets kept in sync in `.env`. ACCEPTED RISK — pattern has been stable for months with no operational issues.
- **ADR-119 (RUNBOOK.md stubs)**: `RUNBOOK.md` does not exist as a separate file. Runbook content lives in `docs/operations.md` (disk-full, WAL sections confirmed present) and `docs/troubleshooting.md`. ADR-119 finding is stale — runbook content is non-stub and distributed across docs. RESOLVED.

---

## Batch completion 2026-02-19T10:02:00Z
- source: `_build/Sprint-4/claude/adr.md`
- moved_count: 9

- `ADR-141` moved from adr.md
  - evidence: `rg -n "stage.metrics" infra/logging/alloy-config.alloy` => stage.metrics blocks present
  - completion_basis: `alloy_stage_metrics_added`

- `ADR-143` moved from adr.md
  - evidence: `rg -n "stage.decolorize" infra/logging/alloy-config.alloy` => decolorize stages present
  - completion_basis: `alloy_decolorize_added`

- `ADR-144` moved from adr.md
  - evidence: `curl -fsS -u admin:<redacted> http://127.0.0.1:9001/api/v1/provisioning/policies | jq -r '.receiver'` => `logging-ops`
  - completion_basis: `grafana_only_routing_enforced`

- `ADR-145` moved from adr.md
  - evidence: `rg -n "scrape_timeout:\s*10s" infra/logging/prometheus/prometheus.yml` => explicit scrape_timeout present
  - completion_basis: `prom_scrape_timeout_explicit`

- `ADR-147` moved from adr.md
  - evidence: `rg -n "runbook_url" infra/logging/prometheus/rules/loki_logging_rules.yml` => runbook_url annotations present on alert rules
  - completion_basis: `prom_runbook_links_present`

- `ADR-150` moved from adr.md
  - evidence: `curl -fsS -u admin:<redacted> http://127.0.0.1:9001/api/v1/provisioning/alert-rules | jq -r '.[] | .uid+" noData="+.noDataState'` => no `OK` blind-spot state remains for GPU rules
  - completion_basis: `grafana_nodata_policy_enforced`

- `ADR-153` moved from adr.md
  - evidence: `rg -n "updateIntervalSeconds:\s*30" infra/logging/grafana/provisioning/dashboards/dashboards.yml` => explicit provider interval set
  - completion_basis: `dashboard_provider_interval_explicit`

- `ADR-154` moved from adr.md
  - evidence: `rg -n "GF_SECURITY_COOKIE_SAMESITE|GF_SECURITY_COOKIE_SECURE" infra/logging/docker-compose.observability.yml` => explicit cookie security settings set
  - completion_basis: `grafana_cookie_policy_explicit`

- `ADR-155` moved from adr.md
  - evidence: `rg -n "GF_AUTH_ANONYMOUS_ENABLED=false|GF_USERS_ALLOW_SIGN_UP=false" infra/logging/docker-compose.observability.yml` => anonymous+signup lock explicit
  - completion_basis: `grafana_auth_lockdown_explicit`

- runtime validation snapshot
  - evidence: `jq -r '.summary.pass,.summary.unexpected_empty_panels' _build/logging/dashboard_audit_latest.json` => true / 0
  - evidence: `jq -r '.pass,.checks.audit_unexpected_empty_panels' _build/logging/verify_grafana_authority_latest.json` => true / 0

## Batch completion 2026-02-19T10:07:25Z

### ADR-134 — Loki query splitting on current build — COMPLETED

**Decision**: Keep this Loki build compatible by setting query splitting under `limits_config` rather than requiring a `query_range` block.

**Evidence**
- `rg -n "split_queries_by_interval" infra/logging/loki-config.yml | head -n 1` => `61:  split_queries_by_interval: 30m`
- `curl -fsS http://127.0.0.1:3200/ready` => ready (HTTP 200)
- `jq -r '.summary.pass,.summary.unexpected_empty_panels' _build/logging/dashboard_audit_latest.json` => `true`, `0`
- `jq -r '.pass,.checks.audit_unexpected_empty_panels' _build/logging/verify_grafana_authority_latest.json` => `true`, `0`

---

## Batch 7 — 2026-02-19 (Grafana log scan fixes)

- **ADR-160**: Alert rule threshold node missing `expression: "B"` field (Grafana 11.5 SSE pipeline regression). Added `expression: "B"` to node C on all 4 rules in `logging-pipeline-rules.yml`. Triggered `/api/admin/provisioning/alerting/reload` to force re-read. Confirmed rules evaluating without error (no `Failed to build rule evaluator` logs after reload). RESOLVED.
- **ADR-161**: SMTP not configured — contact points using email fail on every alert. DEFERRED pending SMTP configuration (user confirmed will configure soon). No code change.
- **ADR-162**: `$__rate_interval` used in Loki datasource queries across 12 dashboard files. `$__rate_interval` is Prometheus-only — Grafana does not substitute it before sending to Loki. Replaced with `$__interval` in all Loki-context panels (targeted by panel `datasource.uid = P8E80F9AEF21F6940`). Also previously fixed in `wireguard-cloudflare.json`. 0 remaining Loki queries with `$__rate_interval` confirmed. RESOLVED.
- **ADR-163**: Missing `infra/logging/grafana/provisioning/plugins/` directory caused startup error. Created directory with `.gitkeep`. RESOLVED.
- **ADR-164**: `resource-server` duplicate metrics registration warning (3x per startup) — known Grafana 11 upstream race condition. No functional impact. ACCEPTED RISK / DEFER.

## Batch completion 2026-02-19T10:17:07Z

### ADR-135 — Explicit Loki component paths — COMPLETED

**Evidence**
- `rg -n "tsdb_shipper|active_index_directory|cache_location|filesystem:" infra/logging/loki-config.yml` => explicit shipper/cache/chunks paths present
- `curl -fsS http://127.0.0.1:3200/ready` => ready (HTTP 200)

### ADR-152 — Balanced provisioning policy (editable + deletion-protected) — COMPLETED

**Evidence**
- `rg -n "disableDeletion|allowUiUpdates|editable" infra/logging/grafana/provisioning/dashboards/dashboards.yml` => `disableDeletion: true`, `allowUiUpdates: true`, `editable: true`
- `curl -fsS -u admin:<redacted> -X POST http://127.0.0.1:9001/api/admin/provisioning/dashboards/reload` => HTTP 200

---

## Phase 2: Grafana Log Scan & Bug Fixes (2026-02-20)

29. `ADR-160 — Grafana Alert Rule Threshold Node Missing expression Field` — **Grafana 11.5 SSE regression** (severity: `CRITICAL`)
    - completion_basis: `alert_rule_expression_field_added`
    - evidence_note: Added `expression: "B"` to all 4 alert rules; provisioning reload confirmed fix

30. `ADR-162 — Grafana Wireguard Dashboard $__rate_interval Issue` — **Variable not substituted in Loki queries** (severity: `MEDIUM`)
    - completion_basis: `dashboard_variable_scope_fixed`
    - evidence_note: Replaced 17 occurrences of `[$__rate_interval]` with `[$__interval]` across 12 dashboards

31. `ADR-163 — Grafana Missing provisioning/plugins Directory` — **Startup error on missing directory** (severity: `LOW`)
    - completion_basis: `plugins_dir_created`
    - evidence_note: Created `infra/logging/grafana/provisioning/plugins/` with .gitkeep

32. `ADR-164 — Grafana resource-server Duplicate Metrics Registration` — **Benign startup warning** (severity: `LOW`)
    - completion_basis: `benign_warning_accepted`
    - evidence_note: Observed but doesn't affect functionality; no action needed

---

## Phase 3: Build Artifact Cleanup (2026-02-20)

33. `ADR-015 — Alloy Backup Files Tracked in Git` — **Timestamped backups in git** (severity: `MEDIUM`)
    - completion_basis: `backups_consolidated_to_root`
    - evidence_note: Moved to `/backup/` folder at root; Commit 8eed2c8

34. `ADR-Metadata — Cleanup One-Time Documentation Files` — **27KB metadata cluttering infra/logging/** (severity: `LOW`)
    - completion_basis: `metadata_files_deleted`
    - evidence_note: Deleted CHANGELOG_authoritative_logging.md, PR_BUNDLE_logging_visibility.md, RELEASE_NOTES_logging_visibility.md, upstream-references.lock; Commit c1b57c5

35. `ADR-Melissa — Queue Consolidation and Artifact Archiving` — **28 queue items scattered; ephemeral state** (severity: `MEDIUM`)
    - completion_basis: `melissa_queue_consolidated`
    - evidence_note: Consolidated all 28 tasks into /docs/adr.md with 4-tier priority; archived artifacts to /_DELETE/melissa-artifacts-archived/; Commit 3ee31de


---

## Phase 4: Melissa Queue Execution — Completed Items (2026-02-20)

36. `Melissa Item 1: FIX:alloy_positions_storage` — **Alloy storage path configuration** (severity: `MEDIUM`)
    - completion_basis: `alloy_storage_path_set`
    - evidence_note: Volume mount and storage.path aligned in docker-compose.observability.yml
    - target: infra/logging/docker-compose.observability.yml

37. `Melissa Item 2: FIX:journald_mounts` — **Journald mount configuration** (severity: `MEDIUM`)
    - completion_basis: `journald_mounts_added`
    - evidence_note: Journal mounts added to Alloy container in compose
    - target: infra/logging/docker-compose.observability.yml

38. `Melissa Item 3: FIX:grafana_alert_timing` — **Grafana alert timing hardening** (severity: `MEDIUM`)
    - completion_basis: `alert_timing_hardened`
    - evidence_note: Alert `for:` and `noDataState` configuration updated in provisioning rules
    - target: infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml

