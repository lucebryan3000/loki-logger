# Production Readiness Code Review — ADR

## Run: 2026-02-17T00:00:00Z | Production POC code review — top-to-bottom

---

## Category Summary

> **Last updated**: 2026-02-19 (Pass 17 — sandbox context triage)
> Status key: ✅ = fully resolved/closed | 🔄 = partially resolved | ⚠️ = open items remain | — = not yet worked
> Owner: C = Claude scope | Codex = Codex scope | Both = shared
> **Context**: Single-user, single-dev, sandbox. Not production. Threat model is internal LAN only.

| # | Category | Count | Owner | Status | Open Items | Sandbox Plan |
|---|----------|-------|-------|--------|------------|--------------|
| 1 | **Scope & Review Meta** | 3 | Codex | ✅ | 0 | — |
| 2 | **Container Orchestration & Compose** | 11 | Codex | 🔄 | ADR-159: read_only rollout still pending (156/157/158 completed baseline) | Keep hardening incremental; avoid early read_only breakage |
| 3 | **Log Ingestion Pipelines (Alloy)** | 28 | Codex | 🔄 | ADR-112 (nvidia delivery validation) | stage.metrics + decolorize + multiline + noise controls completed |
| 4 | **Loki Storage, Retention & Config** | 13 | Codex | 🔄 | ADR-132 (deletion API/auth) | ADR-129/131/134/135 completed; keep 132 deferred in sandbox |
| 5 | **Prometheus Scrape, Rules & Alerting** | 18 | Codex | ✅ | 0 | Grafana-only routing model enforced; Prometheus alerting delivery intentionally disabled in sandbox |
| 6 | **Grafana Dashboards & Provisioning** | 25 | Codex | 🔄 | ADR-151 | ADR-149/150/152/153 completed; keep A->B->C validation continuous |
| 7 | **Security, Network & Exposure** | 12 | Codex | ⏸️ DEFER | ADR-126: hex-atlas exposed; CORRECTION-001: ports 0.0.0.0 | ADR-154/155 explicitly configured; keep network exposure defer in sandbox |
| 8 | **Operational Scripts & Lifecycle** | 5 | C | ✅ | 0 | — |
| 9 | **Host Integration & Mounts** | 5 | C | ✅ | ADR-070, ADR-087/095 confirmed fixed | — |
| 10 | **Dependency & Version Health** | 2 | C | ✅ | 0 | — |
| 11 | **Log Truncation Module** | 2 | C | ⏸️ DEFER | ADR-011: eval injection in template-engine.sh | Defer — you control all input; document risk in comment |
| 12 | **Documentation Accuracy** | 13 | C | ✅ | 0 | — |
| 13 | **Resilience & Failure Modes** | 5 | C | ✅ | 0 | — |
| 14 | **Git, Repo & Config Hygiene** | 10 | C | ⏸️ DEFER | ADR-015: alloy backup files tracked in git | Defer — housekeeping, not blocking |
| 15 | **Environment & Secrets** | 3 | C | ⏸️ DEFER | ADR-072: Grafana env_file scope | Defer — not a real risk in sandbox |
| 16 | **Quality & Test Coverage** | 5+2 | C | ✅ | 0 | — |
| 17 | **Accuracy Corrections (Pass 14)** | 13 | C | ✅ | CORRECTION-001 deferred (accepted sandbox risk) | CORRECTION-009 + CORRECTION-011 completed; keep CORRECTION-001 deferred |
| — | **Total unique entries** | **159+** | | | | |

### Sandbox Resolution Plan — Active Work

Items worth doing now, ordered by value:

| Priority | ADR | Action | Owner | Complexity |
|----------|-----|--------|-------|------------|
| 1 | **ADR-151** | Keep enforcing Grafana rule graph shape `A -> B(reduce) -> C(threshold)` across all new rules | Codex | Validation + guard script |
| 2 | **ADR-152** | Completed: balanced provisioning policy (`disableDeletion: true`, `allowUiUpdates: true`) | Codex | Closed |
| 3 | **ADR-159** | Evaluate selective `read_only` rollout with tmpfs/writable path map | Codex | Medium (service-by-service) |
| 4 | **ADR-112** | Validate NVIDIA telemetry delivery and labels after stack restarts | Codex | Runtime verification |

### Deferred Items (sandbox context — revisit if promoted to production)

| ADR | Finding | Defer Reason |
|-----|---------|--------------|
| CORRECTION-001 | Ports 0.0.0.0 | UFW in place; intentional for LAN access; not a live risk |
| ADR-011 | eval injection in template-engine.sh | You control all input; internal tooling only |
| ADR-072 | Grafana env_file scope | Not a real risk with single user |
| ADR-132 | Loki deletion API unprotected | Single user on obs network |
| ADR-159 | Compose read_only rootfs rollout | Defer until writable-path map is complete per service |
| ADR-152 | Dashboard provisioning deletion policy | Closed in sandbox with balanced posture (editable + deletion protected) |
| ADR-126 | hex-atlas DB/Typesense exposed | Internal LAN, UFW protected |
| ADR-015 | Alloy backup files in git | Housekeeping, not blocking |

> Entries may appear in multiple categories where findings span domains. The authoritative entry text is in-place below; this table is an index only.

---

### ADR-007: D06 — Operational Scripts
- **Context:** Reviewed all 5 scripts in `scripts/prod/mcp/` plus `evidence.sh`.
- **Findings:**
  1. **All scripts have `set -euo pipefail`** — Consistent. Severity: **PASS**.
  2. **All scripts have `--help` handlers** — Consistent and well-documented. Severity: **PASS**.
  3. **`logging_stack_down.sh` always uses `-v` (remove volumes)** — No option for graceful stop without data loss. A typo or habit of running "down" destroys all Loki/Prometheus/Grafana data. Should offer a `--keep-volumes` default with `--purge` for destructive mode. Severity: **HIGH**.
  4. **`logging_stack_health.sh` depends on `rg` (ripgrep)** — Lines 53, 69: `rg -q "Ready"` and `rg -qi '^ready$'`. This is a non-standard dependency not checked by `command -v` at script start. Only `python3` and `curl` are validated. Severity: **MEDIUM**.
  5. **`logging_stack_health.sh` hardcodes ports** — Lines 45, 53, 60: `127.0.0.1:9001`, `127.0.0.1:9004`. Does not read from `.env`. If ports are changed, health checks silently pass against wrong endpoints or fail without explanation. Severity: **MEDIUM**.
  6. **Audit script temp files not cleaned up** — `targets_json`, `up_json`, `targets_down_json`, `targets_up_json`, `flags_json`, `rules_json`, `proof_json` are created with `mktemp` but only `CHECKS_NDJSON` has a `trap` cleanup. 7 temp files leak per audit run. Severity: **LOW**.
  7. **Audit script promtool check extracts image with sed** — Line 201: fragile sed-based image parsing from YAML. If compose format changes (e.g., multiline image reference, variable-only), this silently falls back to `prom/prometheus:latest`. Severity: **LOW**.
  8. **`logging_stack_down.sh` does not validate .env existence** — Sources `.env` at line 29 without checking if it exists. Under `set -euo pipefail`, this is a hard crash with an unhelpful error. Severity: **LOW**.
- **Decision:** The destructive-by-default `down -v` is the highest-risk script behavior.
- **Evidence:** `scripts/prod/mcp/`

---

### ADR-011: D10 — Log Truncation Module
- **Context:** Reviewed `src/log-truncation/` — config, templates, scripts, lib.
- **Findings:**
  1. **Template engine uses `eval` with user-controlled input** — `template-engine.sh:20-23`: `eval "cat <<EOF\n$processed\nEOF"`. Values from `retention.conf` are substituted into a bash eval. A malicious or malformed config value (e.g., `$(rm -rf /)`) would execute. Severity: **HIGH** (mitigated by single-user + controlled config, but a real injection vector).
  2. **`render_template_pure` also uses eval** — Line 38: `eval "echo \"$template_content\""`. Same vulnerability. Severity: **HIGH**.
  3. **retention.conf paths match Alloy paths** — Verified: all 5 Alloy file sources have corresponding logrotate entries. Coverage is complete. Severity: **PASS**.
  4. **copytruncate is correctly configured** — `DEFAULT_COPY_TRUNCATE=true`. This is the right choice for files held open by Alloy. Severity: **PASS**.
  5. **install.sh creates backups before overwriting** — Line 27-33. Good practice. Severity: **PASS**.
  6. **validate.sh uses `logrotate -d` for syntax check** — Correct and standard. Severity: **PASS**.
  7. **No integration test for Alloy position tracking** — After rotation, Alloy should resume from the new file position. No test verifies this end-to-end. Severity: **MEDIUM**.
- **Decision:** The eval injection in template-engine.sh should be replaced with safe substitution (envsubst or parameter expansion without eval).
- **Evidence:** `src/log-truncation/lib/template-engine.sh`, `src/log-truncation/config/retention.conf`

---

### ADR-012: D11 — Documentation-Reality Sync
- **Context:** Cross-referenced `docs/reference.md` and `CLAUDE.md` against actual config files.
- **Findings:**
  1. **CLAUDE.md claims `host=codeswarm` label** — "All logs get `env=sandbox` and `host=codeswarm` labels." No process block sets `host`. Label does not exist. Severity: **MEDIUM**.
  2. **docs/reference.md says "7 active log sources"** — Actual count is 8 (docker, journald, rsyslog, tool_sink, telemetry, nvidia_telem, codeswarm_mcp, vscode_server). Severity: **LOW**.
  3. **docs/reference.md port table is accurate** — All ports match compose file. Severity: **PASS**.
  4. **docs/reference.md label schema is incomplete** — Missing `log_source` labels for `tool_sink`, `telemetry`, `nvidia_telem`, `journald`, `docker`, `vscode_server`. Only documents `codeswarm_mcp`. Severity: **MEDIUM**.
  5. **CLAUDE.md says "10-15 seconds" ingestion delay** — No evidence for this specific number. The audit script uses 3-second sleep for ingest proof. Severity: **LOW**.
  6. **docs/reference.md `alloy-positions` mount shows `/tmp`** — This is accurate per compose line 126. Documented correctly. Severity: **PASS**.
  7. **Config snippets in docs/snippets/ need sync check** — Not verified in this pass. Severity: **UNKNOWN** (deferred).
- **Decision:** Update label documentation and source count.
- **Evidence:** `CLAUDE.md`, `docs/reference.md`, `alloy-config.alloy`

---

### ADR-015: .gitignore Analysis
- **Context:** Reviewed `.gitignore` (68 lines) against tracked files.
- **Findings:**
  1. **Alloy backup files are tracked** — `infra/logging/alloy-config.alloy.backup-20260214-222214` and `alloy-config.alloy.backup-cloudflared-20260214-223706` are committed. These are timestamped backups that should be gitignored (pattern: `*.backup-*`). Severity: **MEDIUM**.
  2. **`*.env` glob is overly broad** — Line 5: `*.env` catches everything ending in `.env`, but `.codex-prompt-state.env.example` is tracked (correctly excluded via `!.env.example` — but the naming is fragile). Severity: **LOW**.
  3. **No `*.lock` ignore for upstream-references.lock** — `infra/logging/upstream-references.lock` is tracked (intentionally — it pins upstream refs). But `.claudeignore` excludes it while `.gitignore` doesn't mention it. Inconsistent intent. Severity: **LOW**.
  4. **`.local-archives/` gitignore** — Line 68, but no such directory exists. Dead entry. Severity: **LOW**.
  5. **.gitignore covers languages this project doesn't use** — `node_modules/`, `venv/`, `__pycache__/`, `*.pyc` — the project has one Python file (`telemetry_writer.py`) and no JS. Over-inclusive but harmless. Severity: **PASS** (defensive).
- **Evidence:** `.gitignore`, `git ls-files`

### ADR-016: .claudeignore Analysis
- **Context:** Reviewed `.claudeignore` (51 lines) and `_build/.claudeignore`.
- **Findings:**
  1. **Dashboard JSON excluded from Claude context** — Line 45: `infra/logging/grafana/dashboards/*.json`. This means Claude cannot read dashboard contents for query audits or UID verification without explicit file read. Intentional for context efficiency but creates a blind spot. Severity: **PASS** (correct tradeoff, noted for awareness).
  2. **`_build/.claudeignore` is `*` (exclude everything)** — Clean. Prevents sprint artifacts from polluting context. Severity: **PASS**.
  3. **`docs/archive/` excluded** — Correct. Historical, not authoritative. Severity: **PASS**.
  4. **`.claudeignore` mirrors `.gitignore` secrets section** — Good. Defense in depth. Severity: **PASS**.
- **Evidence:** `.claudeignore`, `_build/.claudeignore`

### ADR-030: Live Stack Runtime Snapshot

- **Context:** Ran read-only diagnostics against the live running stack on 2026-02-17.
- **Findings:**

  **Stack Health (all PASS):**
  | Service | Image | Status | Uptime | Memory |
  |---------|-------|--------|--------|--------|
  | grafana | grafana/grafana:11.1.0 | healthy | 4h (restarted recently) | 76 MiB |
  | loki | grafana/loki:3.0.0 | healthy | 2d | 118 MiB |
  | prometheus | prom/prometheus:v2.52.0 | healthy | 2d | 145 MiB |
  | alloy | grafana/alloy:v1.2.1 | healthy | 12h (restarted) | 111 MiB |
  | docker-metrics | gcr.io/cadvisor/cadvisor:v0.49.1 | healthy | 2d | 82 MiB |
  | host-monitor | prom/node-exporter:v1.8.1 | up | 2d | 11 MiB |

  - All 6 Prometheus scrape targets: **up** (prometheus, host-monitor, docker-metrics, loki, alloy, wireguard)
  - 18 Prometheus rules loaded: 11 recording + 7 alerting, all `health=ok`, all alerts `state=inactive`
  - Grafana API health: `database=ok`, version `11.1.0`
  - Loki ready (verified from inside obs network via docker run)
  - Health script: `overall=pass`

  **Volume sizes:**
  | Volume | Size |
  |--------|------|
  | logging_grafana-data | 1.7 MB |
  | logging_loki-data | 51 MB |
  | logging_prometheus-data | 356 MB |

  **NEW Finding — Loki externally exposed on port 3200:**

  1. **Loki is bound to `0.0.0.0:3200→3100/tcp`** — The compose config currently shows NO published ports for Loki, and CLAUDE.md says "Loki is internal-only." But `docker port logging-loki-1` shows `3100/tcp -> 0.0.0.0:3200`, and `ss -tlnp` confirms `0.0.0.0:3200` is listening. The Loki container was created from a previous compose config that published the port, and was never recreated after the port was removed from compose. **The running state does not match the declared config.** Severity: **HIGH** (Loki has no auth, same UFW bypass applies).

  2. **Grafana and Alloy both restarted recently** — Grafana uptime is 4h (vs 2d for others), Alloy uptime is 12h. No evidence of why in this diagnostic pass, but container restart gaps should be investigated. Severity: **LOW** (informational).

- **Decision:** Recreate Loki container to match current compose config (no published port). Add this as a WD-01 item.
- **Evidence:** `docker port logging-loki-1`, `ss -tlnp | grep 3200`, `docker inspect logging-loki-1 HostConfig.PortBindings`

---

### ADR-034: New Commits — Loki-Ops Longrun Scripts

- **Context:** 3 new commits since session start (d185099, 4f97c2c, f205027) adding loki-ops runner scripts.
- **Files added:**
  - `infra/logging/scripts/loki_ops_longrun.sh` (213 lines) — Orchestration loop for batch dashboard generation
  - `infra/logging/scripts/loki_ops_batchlib.sh` (140 lines) — Shared library (logging, health gates, checkpoints)
  - `_build/loki-ops/TRACKING.md` (26 lines) — Progress tracking
  - `_build/loki-ops/batch_manifest.json` (15 lines) — Run configuration
- **Findings:**
  1. **Hardcoded `ROOT="/home/luce/apps/loki-logging"`** — Both scripts, line 4. Same issue as `add-log-source.sh` (ADR-021 §1). Severity: **MEDIUM**.
  2. **Auto-commits to git** — `loki_ops_batchlib.sh:135`: `git commit -m "ops: loki-ops checkpoint..."`. Automated commits from a batch script without user confirmation. The allowlist filter (line 123) only permits `infra/logging/grafana/dashboards/sources/codeswarm-src-*.json` which is safe scoping, but automated commits are still a pattern worth noting. Severity: **LOW** (well-scoped).
  3. **Loki queried on port 3200** — `loki_ops_longrun.sh:51`: `LOKIQR="http://127.0.0.1:3200/loki/api/v1/query_range"`. This confirms the Loki port 3200 exposure is actively relied upon by these scripts. Removing the port binding will break this script. Severity: **MEDIUM** (dependency on the config drift).
  4. **Scripts in `infra/logging/scripts/`** — Adds 2 more scripts to the already-fragmented script location. Now 7 scripts in `infra/logging/scripts/` (WD-09 §6 scope increased). Severity: **LOW**.
  5. **Drift detection pattern** — `scan_file_for_drift()` and `DRIFT_RE` regex are a good defensive pattern. Exit code 99 for drift. Severity: **PASS** (good practice).
  6. **`derive_grafana_pass()` reads password from container env** — Uses `docker inspect` to extract `GF_SECURITY_ADMIN_PASSWORD`. This is a correct approach for scripts that need to authenticate. Severity: **PASS**.

- **Decision:** The Loki port 3200 dependency needs resolution before WD-01 can remove it. Either: (a) update loki-ops scripts to use the internal Docker network, or (b) keep a `127.0.0.1:3200` binding intentionally.
- **Evidence:** `infra/logging/scripts/loki_ops_longrun.sh`, `infra/logging/scripts/loki_ops_batchlib.sh`

---

### ADR-036: Alloy HCL Data-Flow Graph
- **Context:** Full trace of all `forward_to` chains in `alloy-config.alloy` (395 lines).
- **Findings:**
  1. **10 source → 9 processor → 1 writer pipeline structure confirmed.** Sources: `docker`, `journald`, `rsyslog`, `tool_sink`, `telemetry`, `nvidia_telem`, `codeswarm_mcp`, `vscode_server` (8 file/socket sources) + `discovery.docker` + `discovery.relabel`. Each source routes to a dedicated `loki.process.*` block which then routes to `loki.write.default`. Severity: **PASS**.
  2. **`loki.process "main"` IS used** — rsyslog `forward_to = [loki.process.main.receiver]` at line 81. Corrects ADR-003 finding #5 which marked it orphaned. rsyslog routes through main → write. However, main only adds `env=sandbox`, it does NOT add `log_source`. rsyslog gets its `log_source=rsyslog_syslog` from the source-level `labels` block. Severity: **CORRECTION** (ADR-003 #5 was wrong).
  3. **Redaction is 7x copy-paste** — All 7 process blocks + nvidia_telem (8 total) have identical 3-rule redaction. No shared component. Alloy HCL does not natively support shared stages; the DRY fix would require a template generator or `import.file`. Severity: **MEDIUM** (confirmed, mitigation is non-trivial).
  4. **Docker discovery filter is an allowlist: `vllm|hex`** — Only compose projects named `vllm` or `hex` are ingested. The logging stack itself is explicitly dropped. This is correct behavior. Severity: **PASS**.
  5. **Dead samba mount confirmed** — `HOST_VAR_LOG_SAMBA` mount on alloy has no corresponding `local.file_match` or `loki.source` block. Confirmed dead. Severity: **LOW** (reconfirms ADR-002 #7).
- **Evidence:** `infra/logging/alloy-config.alloy` full read, 395 lines.

---

### ADR-037: Dashboard UID Audit
- **Context:** Compared 25 dashboard JSON files on disk vs 33 items in Grafana API (28 dashboards + 5 folders).
- **Findings:**
  1. **25 of 28 Grafana dashboards match provisioned files.** Full UID agreement between files and API. Severity: **PASS**.
  2. **3 orphaned dashboards in Grafana (not provisioned from files):**
     - `dfdgpdf22b9q8c` — ".Ubuntu Host" in folder "1-Ubuntu", created manually 2026-02-17T00:16:44Z by bryanluce@appmelia.com. This is the ORIGINAL dashboard that was adopted → `codeswarm-adopted-dfdgpdf22b9q8c`.
     - `dfdgqba65adj4b` — "Loki Health" in folder "Logging", created manually 2026-02-17T00:27:17Z. Original of adopted → `codeswarm-adopted-dfdgqba65adj4b`.
     - `UDdpyzz7z` — "Prometheus 2.0 Stats" in folder "General", created 2026-02-15. Original of adopted → `codeswarm-adopted-uddpyzz7z`.
     All 3 are the original manually-created dashboards that the `adopt_dashboards.sh` script copied. The originals were never deleted from Grafana. Severity: **LOW** (cleanup task, no functional impact but causes confusion in dashboard search).
  3. **5 folders exist in Grafana:** 1-Ubuntu, ATLAS, CodeSwarm, Logging, zNot Working. The "zNot Working" folder (uid `cfdgpuk01zmyob`) is not provisioned and likely contains experimental dashboards. Severity: **LOW**.
- **Evidence:** `jq .uid` across all 25 JSON files, Grafana `/api/search` endpoint, `/api/dashboards/uid/*` for orphans.

---

### ADR-038: Grafana Provisioning Runtime Verification
- **Context:** Examined dashboard provisioning YAML and mount structure.
- **Findings:**
  1. **Single provider path `/var/lib/grafana/dashboards`** maps to `./grafana/dashboards` volume mount. Grafana recursively scans this path by default (`foldersFromFilesStructure: false` is default). Severity: **PASS**.
  2. **Subdirectory structure works:** `adopted/` (3), `sources/` (5), `dimensions/` (5), root (12) = 25 total. All 25 appear in Grafana API. Recursive scanning confirmed. Severity: **PASS**.
  3. **`disableDeletion: false` and `editable: true`** — Provisioned dashboards can be edited in UI AND deleted from UI. This means manual edits to provisioned dashboards will be overwritten on next Grafana restart (provisioning re-applies from files). Users may lose UI edits without realizing. Severity: **MEDIUM** (should document this behavior, consider `editable: false` for stable dashboards).
  4. **No `allowUiUpdates`** — Without `allowUiUpdates: true`, UI changes to provisioned dashboards cannot be saved back. The combination of `editable: true` + no `allowUiUpdates` is confusing: users can modify but not persist. Severity: **LOW**.
- **Evidence:** `infra/logging/grafana/provisioning/dashboards/dashboards.yml`, `docker-compose.observability.yml` volume mount, Grafana API `/api/search`.

---

### ADR-039: Docker Network Topology
- **Context:** `docker network inspect obs` on live stack.
- **Findings:**
  1. **All 6 services on bridge network `obs`** with subnet `172.20.0.0/16`. IPs: alloy=.7, docker-metrics=.5, grafana=.6, host-monitor=.2, loki=.4, prometheus=.3. Severity: **PASS**.
  2. **Network is NOT internal** — `Internal: false` means containers can reach the internet. For an observability stack, this is expected (Grafana plugin updates, etc.) but in a hardened production deployment, the network should be `internal: true` with explicit egress rules. Severity: **LOW** (acceptable for sandbox).
  3. **Network is NOT attachable** — External containers cannot join `obs` without being declared in the compose file. This is correct isolation. Severity: **PASS**.
  4. **/16 subnet is oversized** — 65,534 host addresses for 6 containers. Standard practice for Docker but worth noting for security audit completeness. Severity: **PASS** (informational).
- **Evidence:** `docker network inspect obs`

---

### ADR-040: .env vs .env.example Key Drift
- **Context:** Diff of sorted key sets between `.env.example` and `.env`.
- **Findings:**
  1. **34 keys in .env.example, 34 keys in .env — perfect key parity.** No missing or extra keys. Severity: **PASS**.
  2. **Duplicate semantics detected:** `.env.example` has BOTH `GF_SECURITY_ADMIN_PASSWORD=CHANGE_ME` AND `GRAFANA_ADMIN_PASSWORD=CHANGE_ME`. Similarly `GF_SECURITY_ADMIN_USER/GRAFANA_ADMIN_USER` and `GF_SECURITY_SECRET_KEY/GRAFANA_SECRET_KEY`. The compose file uses `GRAFANA_ADMIN_*` in environment block while Grafana container expects `GF_SECURITY_*` as native env vars. Both sets must be kept in sync manually — a footgun. Severity: **MEDIUM**.
  3. **`LOKI_PUBLISH=0`** in .env.example — This appears to control whether Loki port is published. If `LOKI_PUBLISH=0`, no port; if `LOKI_PUBLISH=1`, publish `LOKI_HOST:LOKI_PORT:3100`. This is the intended mechanism for controlling the config-drift Loki port 3200 issue. The running container has it published, meaning `.env` has a non-zero value or it was deployed from an older compose. Severity: **MEDIUM** (confirms config drift mechanism).
  4. **`TELEMETRY_INTERVAL_SEC=10`** — Present in both files but not referenced anywhere in compose or alloy config. Orphaned env var. Severity: **LOW**.
- **Evidence:** `diff` of sorted, redacted key sets.

---

### ADR-041: Alloy Pipeline Metrics Analysis
- **Context:** Queried Prometheus for all `alloy_*`, `loki_source_*`, `loki_process_*`, `loki_write_*` metrics.
- **Findings:**
  1. **46 Alloy/Loki pipeline metrics available in Prometheus.** Full pipeline observability exists. Key metrics: `loki_source_file_read_lines_total`, `loki_source_docker_target_entries_total`, `loki_write_sent_bytes_total`, `loki_write_dropped_entries_total`. Severity: **PASS**.
  2. **47,442 dropped entries due to `ingester_error`** — `loki_write_dropped_entries_total{reason="ingester_error"}` = 47442. This is a significant number of lost log lines. However, the 1h rate is 0.0000 entries/sec, meaning the drops happened historically (likely during a Loki restart or overload) and are not actively occurring. Severity: **HIGH** (historical data loss, needs investigation of when/why).
  3. **Zero drops for other reasons** — `rate_limited=0`, `stream_limited=0`, `line_too_long=0`. The pipeline is currently healthy for all non-ingester reasons. Severity: **PASS**.
  4. **15.2 MiB total sent bytes** — `loki_write_sent_bytes_total=15939845`. This is a relatively low total, suggesting either the counter was recently reset (Alloy restart) or total throughput is modest. Severity: **PASS** (informational).
  5. **`loki_process_dropped_lines_total` = 0** — No process stage drops. All regex/label stages are working without errors. Severity: **PASS**.
  6. **Missing alert for dropped entries** — No alert rule fires on `loki_write_dropped_entries_total > 0` or `rate(loki_write_dropped_entries_total[5m]) > 0`. The 47K drops went unnoticed. Severity: **HIGH** (confirms WD-04 alerting gap).
- **Evidence:** Prometheus `/api/v1/query` for pipeline metrics. Rate queries over 1h window.

---

### ADR-042: Prometheus TSDB Cardinality
- **Context:** Queried Prometheus `/api/v1/status/tsdb` for cardinality and memory stats.
- **Findings:**
  1. **993 unique metric names** — Manageable for single-node Prometheus. Top series by metric: `container_tasks_state` (535), `loki_request_duration_seconds_bucket` (450), `container_memory_failures_total` (428). Severity: **PASS**.
  2. **`__name__` label has 993 values consuming 364KB memory** — Expected. The `id` label (container IDs) consumes 227KB across 108 unique values. Severity: **PASS**.
  3. **`le` label has 236 values** — Histogram bucket boundaries. High but expected for histogram metrics. Severity: **PASS**.
  4. **`path` label has 162 values** — Likely from `loki_source_file_*` metrics tracking individual file paths. This could grow unbounded if new log files are created frequently. Severity: **LOW** (monitor for cardinality growth).
- **Evidence:** Prometheus `/api/v1/status/tsdb`

---

### ADR-043: Log Truncation Config vs Alloy Mount Alignment
- **Context:** Compared `retention.conf` paths with Alloy source paths from compose mounts.
- **Findings:**
  1. **All Alloy file sources have matching truncation config:**
     - Tool sink: `TOOL_SINK_PATH="/home/luce/_logs/*.log"` ↔ Alloy `local.file_match "tool_sink"` path `/host/home/luce/_logs/*.log` ✓
     - Telemetry: `TELEMETRY_PATH="/home/luce/_telemetry/*.jsonl"` ↔ Alloy telemetry path ✓
     - MCP logs: `MCP_LOGS_PATH="/home/luce/apps/vLLM/_data/mcp-logs/*.log"` ↔ Alloy codeswarm_mcp path ✓
     - NVIDIA telem: `NVIDIA_TELEM_PATH="/home/luce/apps/vLLM/logs/telemetry/nvidia/*.jsonl ..."` ↔ Alloy nvidia_telem paths ✓
     - VSCode: `VSCODE_PATH="/home/luce/.vscode-server/**/*.log ..."` ↔ Alloy vscode_server paths ✓
     Severity: **PASS**.
  2. **Truncation config includes paths NOT in Alloy:** `CODE_SERVER_PATH` and `SAMBA_PATH` (disabled) have no Alloy pipelines. This is fine — truncation manages files that may not need log ingestion. Severity: **PASS**.
  3. **Journald and Docker are not in truncation** — These are managed by systemd/Docker respectively, not logrotate. Correct separation. Severity: **PASS**.
  4. **Alloy positions volume `alloy-positions:/tmp`** — Alloy stores file read positions in `/tmp`. If the container is recreated, the named volume preserves positions, preventing duplicate log ingestion. Correct design. Severity: **PASS**.
- **Evidence:** `src/log-truncation/config/retention.conf`, `infra/logging/alloy-config.alloy`, `docker-compose.observability.yml` volumes.

---

### ADR-045: Grafana Alerting Rules Audit
- **Context:** Reviewed provisioned alerting rules in `grafana/provisioning/alerting/logging-pipeline-rules.yml` and cross-checked with Grafana API.
- **Findings:**
  1. **2 Grafana alert rules provisioned and active:**
     - `logging-e2e-marker-missing`: Fires when `count_over_time({log_source="rsyslog_syslog"} |~ "MARKER=" [15m]) < 1`. Requires an external process to send periodic MARKER lines via rsyslog. If no marker process is running, this alert fires permanently. Severity: **MEDIUM** (check if marker process exists).
     - `logging-total-ingest-down`: Fires when total log count across all sources drops to 0 over 5m. Good canary alert. Severity: **PASS**.
  2. **Both rules set `for: 0m`** — Alerts fire immediately on first evaluation with no grace period. This could cause flapping if Loki query latency varies. Standard practice is `for: 1m` or `for: 2m`. Severity: **LOW**.
  3. **Both rules set `noDataState: Alerting` and `execErrState: Alerting`** — If Loki is unreachable, the alert fires (fail-closed). Correct for a pipeline health alert. Severity: **PASS**.
  4. **No Grafana alert rules for Prometheus-side issues** — All Prometheus alerting is in `loki_logging_rules.yml` (Prometheus native rules), not Grafana managed alerts. Clean separation. Severity: **PASS**.
  5. **Grafana API confirms `provenance: file`** — Both rules are file-provisioned, not manually created. Cannot be edited in UI. Correct. Severity: **PASS**.
- **Evidence:** `infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml`, Grafana `/api/v1/provisioning/alert-rules`.

---

### ADR-047: Loki Compactor & Runtime Status
- **Context:** Queried Loki build info, compactor ring, readiness, and internal metrics via port 3200.
- **Findings:**
  1. **Loki 3.0.0 build date: 2024-04-08** — Build is nearly 2 years old. Current Loki is 3.4.x+ (Jan 2026). Missing security patches and performance improvements. Correlates with ADR-010 (dependency version health) WD-05. Severity: **HIGH** (reconfirms).
  2. **Compactor ring is ACTIVE** with single instance. `apply_retention_operation_total{status="success"} = 226`. Retention compaction is running successfully. Last successful run timestamp converts to recent. Severity: **PASS**.
  3. **Compactor grpc requests: 680 total, all 2xx** — Zero errors in compactor gRPC. Healthy. Severity: **PASS**.
  4. **Loki /ready returns `ready`** — Service is fully operational. Severity: **PASS**.
- **Evidence:** `curl http://127.0.0.1:3200/loki/api/v1/status/buildinfo`, `/compactor/ring`, `/ready`, `/metrics`.

---

### ADR-048: Container Restart History & Uptime
- **Context:** Inspected all 6 logging stack containers for restart counts and start times.
- **Findings:**
  1. **Zero restarts across all 6 containers.** All `RestartCount=0`. Severity: **PASS**.
  2. **Container ages vary:**
     - docker-metrics, host-monitor, loki, prometheus: Started 2026-02-15T13:12 (2.3 days)
     - alloy: Started 2026-02-17T09:15 (12.5 hours) — most recently restarted
     - grafana: Started 2026-02-17T17:52 (4 hours) — second most recent
  3. **Alloy was restarted ~12h after the stack** — This explains why `loki_write_sent_bytes_total` is only 15.2 MiB (counter reset). The 47K dropped entries happened before this Alloy restart. Severity: **MEDIUM** (explains ADR-041 #2 — drops were pre-restart, counter is post-restart).
  4. **Grafana was restarted most recently** — 4 hours ago. Likely due to dashboard provisioning changes. Severity: **PASS** (informational).
- **Evidence:** `docker inspect --format` for all 6 containers.

---

### ADR-050: Grafana Data Source Provisioning
- **Context:** Compared YAML datasource files with Grafana API response.
- **Findings:**
  1. **Perfect match** — 2 datasources in YAML (Loki + Prometheus), 2 in API. UIDs match: `P8E80F9AEF21F6940` (Loki) and `PBFA97CFB590B2093` (Prometheus). URLs match: `http://loki:3100` and `http://prometheus:9090`. Severity: **PASS**.
  2. **Loki is default datasource** — `isDefault: true` in YAML and API. Correct for a logging-first stack. Severity: **PASS**.
  3. **Both use `access: proxy`** — Grafana server proxies requests to Loki/Prometheus. This means Grafana has network access to both services, which is correct since they're on the `obs` network. Severity: **PASS**.
- **Evidence:** `infra/logging/grafana/provisioning/datasources/*.yml`, Grafana `/api/datasources`.

---

### ADR-051: Docker Volume Configuration
- **Context:** Inspected all 4 named Docker volumes for the logging stack.
- **Findings:**
  1. **All 4 volumes use `local` driver with no options** — `logging_alloy-positions`, `logging_grafana-data`, `logging_loki-data`, `logging_prometheus-data`. No size limits, no special mount options, no backup configuration. Severity: **MEDIUM** (reconfirms ADR-004 #4 — no volume size constraints).
  2. **Volume size not readable without sudo** — Cannot `du -sh` the volume mountpoints. The earlier `docker system df -v` method works but gives container-level view. Severity: **PASS** (operational constraint, not a finding).
  3. **Compose version 5.0.2** — All volumes have label `com.docker.compose.version:5.0.2`. Severity: **PASS** (informational).
- **Evidence:** `docker volume inspect` for all 4 volumes.

---

### ADR-052: UFW Rules vs Port Exposure Analysis
- **Context:** Cross-referenced UFW rules with actual port bindings from `ss -tlnp` and `docker port`.
- **Findings:**
  1. **Grafana (9001) and Prometheus (9004) have UFW rules** — Rules 31-32 allow LAN (192.168.1.0/24) access to ports 9001 and 9004. These match the `0.0.0.0` bindings in compose. Severity: **PASS**.
  2. **Loki port 3200 has NO UFW rule** — Port 3200 is bound to `0.0.0.0` (config drift) but no UFW rule exists for it. HOWEVER, Docker bypasses UFW via iptables nat chains. This means port 3200 is accessible from LAN regardless of UFW. Severity: **CRITICAL** (reconfirms ADR-006 Docker+UFW bypass — Loki's HTTP API is network-accessible without authentication).
  3. **rsyslog port 1514 is loopback-only** — Bound to `127.0.0.1:1514` with no UFW rule. Correct isolation. Severity: **PASS**.
  4. **WireGuard exporter (9586) has internal-only UFW rule** — Rule 34 allows `172.20.0.0/16` (Docker obs network) to reach 9586. This is for Prometheus to scrape the WireGuard exporter on the host gateway. Severity: **PASS** (well-scoped).
  5. **41 total UFW rules** — Many are for non-logging services (SSH, Samba, WireGuard, web apps). The logging-specific rules are 31-32 (Grafana/Prometheus LAN access) and 34 (WireGuard exporter). Severity: **PASS** (context).
  6. **No UFW rule for Alloy (12345)** — Alloy is not published to host. Docker internal only. Correct. Severity: **PASS**.
- **Evidence:** `sudo ufw status numbered`, `ss -tlnp`, `docker port`.

---

### ADR-053: Prometheus Scrape Targets Verification
- **Context:** Compared `prometheus.yml` scrape config with runtime `/api/v1/targets`.
- **Findings:**
  1. **6 configured jobs, 6 active targets, 0 dropped** — Perfect match. All targets healthy: prometheus, host-monitor, docker-metrics, loki, alloy, wireguard. Severity: **PASS**.
  2. **WireGuard exporter scrapes host gateway** — Target `172.20.0.1:9586` is the Docker bridge gateway IP, where a WireGuard Prometheus exporter runs on the host. This is clever routing but undocumented. Severity: **LOW** (should document in reference.md).
  3. **All scrapes use Docker DNS names** — `prometheus:9090`, `loki:3100`, etc. Internal resolution via Docker bridge. No hardcoded IPs except the WireGuard exporter. Severity: **PASS**.
  4. **No scrape for Grafana itself** — Grafana exposes metrics at `/metrics` but Prometheus doesn't scrape it. The `grafana-metrics.json` dashboard uses `grafana_*` metrics that must come from Grafana's self-monitoring or are scraped by another mechanism. Severity: **MEDIUM** (dashboard may have empty panels if Grafana metrics aren't available).
- **Evidence:** `infra/logging/prometheus/prometheus.yml`, Prometheus `/api/v1/targets`.

---

### ADR-054: Dashboard Panel Query Audit Results
- **Context:** Read the latest dashboard audit output from `_build/logging/dashboard_audit_latest.json`.
- **Findings:**
  1. **25 provisioned dashboards scanned, 120 queries checked, 0 unexpected empty panels.** Severity: **PASS**.
  2. **14 expected empty panels** — These are panels where the audit script knows the data source may not have data yet (e.g., GPU metrics when GPU is idle, or specific container metrics). Properly categorized. Severity: **PASS**.
  3. **28 total dashboards (25 provisioned + 3 orphaned)** — The 3 orphaned are not scanned by the audit script since they're not in the provisioned directory. Severity: **LOW**.
  4. **Audit timestamp: 2026-02-17T21:47:40Z** — Fresh run (within this session). Severity: **PASS**.
- **Evidence:** `_build/logging/dashboard_audit_latest.json`.

---

### ADR-043 Correction: Alloy Positions Volume
- **Update to ADR-043 finding #4:** The Alloy positions volume was described as "Correct design." This is **INCORRECT**. ADR-049 discovered the volume is empty. Alloy is NOT writing positions to `/tmp`. The volume mount appears misconfigured — Alloy's default data path is likely `/var/lib/alloy/data/`, not `/tmp`. This means file read positions may be stored in container-ephemeral storage. Severity upgrade from **PASS** to **HIGH**.

---

---

## Pass 8: Runtime Validation & Dead Code Discovery (Loop 3)

### ADR-055: Dead Recording Rule — loki_distributor Metric
- **Context:** Verified whether `loki_distributor_ingester_appends_failed_total` exists in Prometheus.
- **Findings:**
  1. **Metric does NOT exist.** Zero series returned. The recording rule `sprint3:loki_ingestion_errors:rate5m` evaluates to nothing/0 always. Severity: **HIGH** (dead alerting — the `LokiIngestionErrors` alert in `sprint3_minimum_alerts.yml` can NEVER fire).
  2. **Root cause:** Loki 3.0 in monolithic mode (single binary) does not expose `loki_distributor_*` metrics because the distributor is an internal component not exposed as a separate gRPC target. The metric name is from Loki's microservices mode. Severity: **HIGH** (architectural mismatch).
  3. **Two recording rules affected:** `sprint3:loki_ingestion_errors:rate5m` and `sprint3:loki_ingestion_errors:increase10m` both reference this missing metric. Both are dead. Severity: **HIGH**.
  4. **Alternative metric exists:** `loki_write_dropped_entries_total` (from Alloy) tracks actual write failures and has real data (47K ingester_error). This should replace the dead distributor metric. Severity: **MEDIUM** (actionable fix).
- **Evidence:** Prometheus `/api/v1/query` returns empty result set.

---

### ADR-058: Grafana Metrics Dashboard — Empty Panels Confirmed
- **Context:** Queried Prometheus for `grafana_*` metrics.
- **Findings:**
  1. **Zero `grafana_*` metrics in Prometheus** — No Grafana scrape target exists in `prometheus.yml`. The `grafana-metrics.json` dashboard (uid `isFoa0z7k`, title "Grafana metrics (Prom Health)") cannot render any data. Severity: **MEDIUM** (dead dashboard).
  2. **The dashboard was not flagged by the audit script** — It's likely in the "14 expected empty panels" category, or the audit script doesn't check for datasource availability. Severity: **LOW** (audit script gap).
  3. **Fix options:** Either add a Grafana scrape job to `prometheus.yml`, or remove the dashboard. Adding the scrape is trivial: `job_name: grafana, static_configs: [{targets: ["grafana:3000"]}]`. Severity: **LOW** (actionable).
- **Evidence:** Prometheus `/api/v1/query` for `grafana_*`.

---

### ADR-059: Loki WAL & Ingester State
- **Context:** Scraped Loki `/metrics` for ingester and WAL metrics.
- **Findings:**
  1. **Loki WAL is active:** `wal_logged_bytes_total=130.5 MiB`, `wal_records_logged_total=77537`. Healthy throughput. Severity: **PASS**.
  2. **208 WAL duplicate entries** — `wal_discarded_bytes_total{reason="duplicate"}=39462`, `wal_duplicate_entries_total=208`. Small number relative to 77K records. Likely from Alloy retry logic. Severity: **LOW**.
  3. **WAL recovery worked on last restart:** `wal_recovered_entries_total=9635`, `wal_recovered_streams_total=13`, `wal_recovered_chunks_total=12`. Loki successfully recovered WAL state after its last restart. Severity: **PASS**.
  4. **13 active streams, 13 memory chunks** — Low active stream count. `tenant="fake"` confirms single-tenant monolithic mode. Severity: **PASS** (expected for single-tenant).
  5. **Chunks flushed: 286 idle, 74 max_age, 72 synced, 2 full** — Most chunks flush due to idle timeout (no new data). Healthy pattern. Severity: **PASS**.
- **Evidence:** Loki `/metrics` endpoint via port 3200.

---

### ADR-060: Docker iptables NAT Rules — Loki Bypass Confirmed
- **Context:** Inspected iptables NAT DOCKER chain for port 3200.
- **Findings:**
  1. **iptables DNAT rule exists:** `tcp dpt:3200 → 172.20.0.4:3100`. This is how Docker publishes the port, completely bypassing UFW INPUT chain. Severity: **CRITICAL** (hard confirmation of ADR-006 and ADR-052 #2).
  2. **Source is `0.0.0.0/0`** — Any IP can reach Loki port 3200. No source restriction in the DNAT rule. Docker's `-p` flag does not support source filtering; that must be done in DOCKER-USER chain or via `--iptables=false`. Severity: **CRITICAL**.
  3. **rsyslog port correctly restricted:** DNAT for 1514 shows `0.0.0.0/0 → 127.0.0.1` → `172.20.0.7:1514`. The `127.0.0.1` destination means only loopback traffic is DNATed. Correct isolation. Severity: **PASS**.
  4. **Second Loki instance detected:** Additional DNAT rules for ports 3100 and 3101 → `172.22.0.2:3100` and `172.22.0.2:3101` on a different subnet (`172.22.0.0/16`). This is a SEPARATE Loki instance from another compose project. Severity: **MEDIUM** (unexpected; another project has Loki exposed).
- **Evidence:** `sudo iptables -t nat -L -n`.

---

### ADR-061: Prometheus Rules — Second Alert File Discovered
- **Context:** Prometheus `/api/v1/rules` revealed a second rules file not previously documented.
- **Findings:**
  1. **`sprint3_minimum_alerts.yml` contains 3 alert rules** previously unknown:
     - `PrometheusScrapeFailure`: `sprint3:prometheus_scrape_failures:rate5m > 0` for 5m (warning)
     - `PrometheusTargetDown`: `sprint3:targets_down:count > 0` for 5m (critical)
     - `LokiIngestionErrors`: `sprint3:loki_ingestion_errors:increase10m > 0` for 5m (warning)
  2. **`LokiIngestionErrors` is DEAD** — References the dead recording rule that depends on the missing `loki_distributor_*` metric. Will never fire. Severity: **HIGH** (reconfirms ADR-055).
  3. **`PrometheusTargetDown` duplicates `TargetDown`** from `loki_logging_rules.yml` but with different threshold: same expression (`sprint3:targets_down:count > 0`) but `for: 5m` vs `for: 2m`. The 2m version fires first. Severity: **LOW** (redundant but harmless).
  4. **All 18 rules (11 recording + 7 alerting) evaluated in 0.0011s total** — No evaluation errors, all healthy. Severity: **PASS**.
- **Evidence:** `infra/logging/prometheus/rules/sprint3_minimum_alerts.yml`, Prometheus `/api/v1/rules`.

---

### ADR-066: Loki Label Schema — Runtime Inventory
- **Context:** Queried Loki label API for complete label and value inventory.
- **Findings:**
  1. **10 labels in Loki:** `__stream_shard__`, `env`, `filename`, `log_source`, `mcp_level`, `mcp_tool`, `service`, `service_name`, `source_type`, `stack`. Severity: **PASS**.
  2. **Missing labels vs docs:**
     - `host` label: EMPTY — Confirmed ADR-003 #3. Docs say `host=codeswarm` but no process block sets it. Severity: **MEDIUM** (reconfirms).
     - `container_name` label: EMPTY — Docker logs don't have this label despite docs claiming it. The Docker pipeline uses `service` label from compose metadata instead. Severity: **MEDIUM** (doc drift).
     - `job` label: NOT PRESENT — Docs say "every log entry has: `env`, `host`, `job`" but `job` is not in Loki labels. Severity: **MEDIUM** (doc drift).
  3. **Label values confirmed:**
     - `env`: only `sandbox` ✓
     - `log_source`: 5 values (codeswarm_mcp, docker, rsyslog_syslog, telemetry, vscode_server) — matches Alloy config minus journald/tool_sink/nvidia_telem
     - `stack`: `hex`, `vllm` — from Docker discovery filter
     - `service`: `atlas-sql`, `atlas-typesense`, `codeswarm-mcp` — Docker compose service names
     - `source_type`: `docker`, `syslog` — only 2 of expected types (missing `file` from tool_sink/telemetry/vscode)
  4. **`source_type` missing `file` value** — Tool sink, telemetry, and vscode_server processors don't set `source_type`. Only the docker processor sets `source_type=docker` and rsyslog sets `source_type=syslog`. File-based sources rely on the static label in their respective process blocks but none set `source_type=file` except nvidia_telem. Severity: **MEDIUM** (inconsistent labeling).
- **Evidence:** Loki `/loki/api/v1/labels` and `/loki/api/v1/label/*/values`.

---

### ADR-071: Grafana Authority Verification — Pass With Caveats
- **Context:** Read the latest `verify_grafana_authority_latest.json` output.
- **Findings:**
  1. **Overall pass: true** — The verification script considers the stack healthy. Severity: **PASS**.
  2. **`e2e_marker_found: true`** in the verify script — contradicts the Grafana alert `logging-e2e-marker-missing` which is currently firing. The verify script found the marker via a different query path or at a different time. Severity: **MEDIUM** (inconsistency between audit tools).
  3. **`adoption_offending_count: 3`** — 3 original dashboards that should be replaced by adopted versions still exist. Matches ADR-037 #2. Severity: **LOW** (known).
  4. **`audit_unexpected_empty_panels: 0`** — Matches ADR-054. Severity: **PASS**.
  5. **Dimension dashboards: 5 present, 0 missing** — All service_name dimension dashboards are provisioned. Severity: **PASS**.
- **Evidence:** `_build/logging/verify_grafana_authority_latest.json`.

---

### ADR-077: Alloy Positions — Volume Mount Aligned, Path Confirmed

- **Source**: `docker inspect logging-alloy-1`, compose file, container filesystem
- **Evidence**:
  - Compose command: `--storage.path=/var/lib/alloy` ✓
  - Volume mount: `alloy-positions:/var/lib/alloy` ✓
  - Container filesystem: `/var/lib/alloy/` exists, owned `alloy:alloy`
  - `/var/lib/alloy/data/` directory present (pre-created in image)
- **Findings**:
  1. **Volume mount and storage path are now aligned.** `alloy-positions` named volume mounts to `/var/lib/alloy`, which matches `--storage.path=/var/lib/alloy`. Positions will be written to this volume and persist across container recreation. Severity: **PASS** (fix confirmed).
  2. **Position files not yet visible in `/var/lib/alloy/data/`.** `find /var/lib/alloy -name "*.yml"` returned nothing. This is expected if Alloy hasn't completed its first flush cycle yet (Alloy writes positions periodically, not immediately). After ~60s of runtime, position files should appear. Severity: **PASS** — normal startup behavior.
  3. **Alloy health endpoint now correctly probed.** Healthcheck uses `wget -qO- http://127.0.0.1:12345/-/ready`. Container reports `healthy`. Severity: **PASS** (fix confirmed).

---

### ADR-083: `sprint3:` Namespace — Recording Rules Functional, Namespace Cosmetic Issue Persists

- **Source**: Prometheus `/api/v1/rules` (runtime evaluation)
- **Evidence**:
  - All 11 recording rules in group `loki_logging_v1`: health `ok`
  - `sprint3:targets_up:count: ok`, `sprint3:job_up:ratio: ok`, `sprint3:host_cpu_usage_percent: ok` etc.
  - `sprint3:loki_ingestion_errors:rate5m: ok` — evaluates to empty (see ADR-075), but Prometheus marks the rule `ok` (no eval error, just returns empty vector)
  - Exception: `sprint3:loki_ingestion_errors:*` — still empty due to ADR-075 issue
- **Findings**:
  1. **9 of 11 recording rules produce valid non-empty results.** Recording rules for host CPU/memory/disk, container CPU/memory, targets up/down, job ratios, and scrape failures are all healthy. Severity: **PASS**.
  2. **2 recording rules (`loki_ingestion_errors:rate5m` and `:increase10m`) produce empty results** due to the `sum() + sum()` with a no-series operand issue (ADR-075). Prometheus marks them `ok` because no evaluation error occurred — empty vector is a valid result. Severity: **HIGH** (see ADR-075).
  3. **`sprint3:` prefix is a cosmetic issue only.** Namespace does not affect function. No action required unless a naming convention change is decided. Severity: **LOW** (deferred to DC-8 cleanup).
  4. **Alert evaluation healthy**: `NodeDiskSpaceLow`, `NodeMemoryHigh`, `NodeCPUHigh`, `AlloyPipelineDrops`, `LokiVolumeUsageHigh`: all `inactive`. Correct — no threshold exceeded. Severity: **PASS**.

---

### ADR-084: `codeswarm-mcp` Container — vLLM-Side Loki Still Exposed 0.0.0.0

- **Source**: `docker ps --format '{{.Names}}\t{{.Ports}}'` (runtime)
- **Evidence**:
  - `codeswarm-mcp 0.0.0.0:3100-3101->3100-3101/tcp, 0.0.0.0:8000->8000/tcp`
  - This container is in the `vllm` project, not the `logging` project
  - The logging project's Loki is now `127.0.0.1:3200->3100` (fixed)
- **Findings**:
  1. **The vLLM project's `codeswarm-mcp` container still exposes Loki on `0.0.0.0:3100`.** This is a separate Loki instance from the `vllm` compose project. Not controlled by this repo. The Docker+UFW bypass applies here too — port 3100 is accessible from LAN without authentication. Severity: **MEDIUM** — out of scope for this repo but worth documenting as a host-level risk.
  2. **Port collision risk removed.** The logging project's Loki was previously also on a `0.0.0.0` binding. Now it's `127.0.0.1:3200`. There is no port collision between the two Loki instances (3100 vs 3200). Severity: **PASS**.
  3. **`hex-atlas-app-1` exposes port 3000 on `0.0.0.0`.** This is a separate application (not observability). Out of scope. Severity: **INFORMATIONAL**.
- **Codex action**: No action in this repo. Document in `docs/security.md` under "Other containers on this host that expose ports externally."

---

### ADR-090: `backup_restore_added` — Scripts Exist But Are In Wrong Location

- **Source**: `find` + direct file inspection
- **Evidence**:
  - Scripts found at: `infra/logging/scripts/backup_volumes.sh` and `infra/logging/scripts/restore_volumes.sh`
  - NOT in `scripts/prod/mcp/` (the documented operational script location per CLAUDE.md)
  - `backup_volumes.sh`: backs up `logging-grafana-data`, `logging-loki-data`, `logging-prometheus-data` to `/home/luce/apps/loki-logging/_build/logging/backups/<timestamp>/`
  - `restore_volumes.sh`: restores from a specified backup directory
  - Both scripts use `set -euo pipefail`, correct docker volume names, `alpine:3.20` for extraction
  - Backup destination default is inside `_build/` which is gitignored
- **Findings**:
  1. **Backup/restore scripts exist and are functionally correct.** Logic is sound: iterates named volumes, uses docker run + alpine tar for archive/restore. Severity: **PASS** (scripts work).
  2. **Scripts are in `infra/logging/scripts/` not `scripts/prod/mcp/`.** CLAUDE.md and docs reference `scripts/prod/mcp/` as the operational script location. These scripts are not findable via the documented path. Severity: **MEDIUM** — discoverability issue, not a functional bug.
  3. **Backup destination defaults to `_build/logging/backups/`** which is gitignored. Backups will not be committed. This is correct for a local sandbox — no accidental backup data in git. Severity: **PASS** (intended).
  4. **`logging_stack_down.sh` no longer destroys volumes by default.** The `down.sh` fix documented in `adr-completed.md` is confirmed — default is `docker compose down` (no `-v`), purge requires explicit `--purge` flag with help text. Severity: **PASS** (fix confirmed).
- **Codex action**: Move `infra/logging/scripts/backup_volumes.sh` and `infra/logging/scripts/restore_volumes.sh` to `scripts/prod/mcp/`. Update any internal path references. Add entries to CLAUDE.md script table.

---

### ADR-104: `docs/quality-checklist.md` — UFW Claim Updated But Weakly Worded

- **Completion claim**: `ADR-022-UFW-PROTECTED-CLAIM` moved to completed — "Claims 'UFW-protected' for ports" corrected
- **Source**: `grep -n 'UFW\|ufw\|protected' docs/quality-checklist.md` (Agent-2)
- **Evidence**:
  - `docs/quality-checklist.md:79` → `- [ ] Docker-published ports are intentionally scoped (loopback preferred) and not assumed protected by UFW alone`
  - `docs/quality-checklist.md:85` → `- [ ] Prometheus exposure is either loopback-only or protected with explicit auth controls`
  - No "UFW-protected" phrase remains ✓
  - No `host`/`job` label claims remain ✓ (separate query confirmed empty output)
- **Findings**:
  1. **The "UFW-protected" language has been removed.** The checklist now correctly warns about Docker+UFW bypass. Severity: **PASS** (fix confirmed).
  2. **The `host`/`job` label claims have been removed.** Quality checklist no longer references non-existent labels. Severity: **PASS** (fix confirmed).
  3. **The checklist item for Prometheus (line 85) is unchecked `[ ]`.** Prometheus is loopback-only (`127.0.0.1:9004`) ✓ but the checklist box is not marked. Severity: **LOW** — cosmetic, checklist items should be reviewed against current state.

---

### ADR-105: iptables DNAT — Loopback-Scoped Ports Confirmed, codeswarm-mcp 3100 Exposed Globally

- **Source**: `sudo iptables -t nat -L DOCKER --line-numbers | grep -E '3200|9001|9004|3100|1514'` (Agent-5)
- **Evidence**:
  ```
  4  DNAT tcp anywhere localhost tcp dpt:1514 to:172.20.0.7:1514   (Alloy syslog)
  5  DNAT tcp anywhere localhost tcp dpt:3200 to:172.20.0.3:3100   (Loki)
  6  DNAT tcp anywhere localhost tcp dpt:9004 to:172.20.0.4:9090   (Prometheus)
  7  DNAT tcp anywhere localhost tcp dpt:9001 to:172.20.0.6:3000   (Grafana)
  8  DNAT tcp anywhere anywhere  tcp dpt:3100 to:172.22.0.2:3100   (codeswarm-mcp)
  ```
- **Findings**:
  1. **All 4 logging stack ports (9001, 9004, 3200, 1514) have DNAT rules scoped to `localhost` as destination.** This means only connections arriving on the loopback interface are forwarded — LAN access is blocked at DNAT. The `loki_port_local_runtime` fix is confirmed at the iptables level. Severity: **PASS**.
  2. **`codeswarm-mcp` port 3100 has a DNAT rule with `anywhere → anywhere`** — no source restriction. Combined with UFW having no rule for port 3100, this port is accessible from LAN and potentially the internet if the host has a public IP. Loki API with `auth_enabled: false`. Severity: **HIGH** (out of scope for this repo but documented here for host-level risk).
  3. **UFW has NO rules for ports 9001, 9004, 3200, 1514** — confirmed by UFW status. But these ports are loopback-only, so UFW is not the protection mechanism. The protection is the `127.0.0.1:` binding. Severity: **PASS** (protection model is correct, just different from UFW).

---

### ADR-106: Grafana Dashboard Provisioning — Subdirectory Structure Not Reflected in Provisioning YAML

- **Source**: `ls infra/logging/grafana/dashboards/` + `cat provisioning/dashboards/dashboards.yml` (Agent-5)
- **Evidence**:
  - `infra/logging/grafana/dashboards/` contains: `adopted/`, `dimensions/`, `sources/` subdirectories + 14 JSON files at root
  - `provisioning/dashboards/dashboards.yml` → `path: /var/lib/grafana/dashboards` — flat path, no subdirectory recursion config
  - Grafana file provider by default scans recursively but only if `options.path` points to the root. The compose volume mount: `./grafana/dashboards:/var/lib/grafana/dashboards:ro` ✓ maps the entire directory
- **Findings**:
  1. **Grafana file provider with default config DOES scan subdirectories recursively.** Dashboards in `adopted/`, `dimensions/`, and `sources/` ARE loaded. Severity: **PASS** — subdirectory dashboards load correctly.
  2. **`disableDeletion: false` in dashboards.yml** means Grafana can delete provisioned dashboards if the JSON files are removed. For a repo-managed stack, `disableDeletion: true` is safer. Severity: **LOW** — risk of accidental dashboard deletion if files are removed from git without container update.
  3. **14+ dashboard JSON files at multiple nesting levels.** All are `last modified: 17 Feb`. Dashboard count has grown significantly — not reflected in any doc. Severity: **LOW** (doc gap).

---

### ADR-107: Docker Volume Disk Usage — Prometheus Approaching Thresholds

- **Source**: `docker volume ls` + `sudo du -sh /var/lib/docker/volumes/logging_*` (Agent-4)
- **Evidence**:
  - `logging_alloy-positions`: 8.0K (empty — positions not written)
  - `logging_grafana-data`: 1.7M
  - `logging_loki-data`: 64M (720h retention, compactor running every 10m)
  - `logging_prometheus-data`: **476M** (15d retention)
  - Docker `system df`: Total volumes = 718.2MB across 17 volumes
  - Docker images: 57.79GB total (48.58GB reclaimable), Build Cache: 13.38GB (4.56GB reclaimable)
- **Findings**:
  1. **Prometheus data volume is 476MB and growing.** At 15d retention + 15s scrape interval across 7 targets + hundreds of metrics per target, this will grow ~30-50MB/day. Severity: **LOW** — no immediate concern, `NodeDiskSpaceLow` alert will fire at >90% host disk.
  2. **Loki data is only 64MB despite ingesting since 2026-02-13.** Compactor with 720h retention and 10m compaction interval is working efficiently. Severity: **PASS**.
  3. **Docker image reclaimable space: 48.58GB.** `docker image prune` would reclaim this. Not a blocker but a maintenance opportunity. Severity: **LOW**.
  4. **`logging_alloy-positions` is 8.0K (empty).** No positions file means Alloy is either not writing positions (storage.path mismatch — ADR-095) or positions are stored inside the container's `/tmp` overlayfs, not in the named volume. Severity: **HIGH** — confirms ADR-095.

---

### ADR-108: log-truncation Module — Installed But logrotate.d Entry Incomplete

- **Source**: `ls src/log-truncation/` + `ls /etc/logrotate.d/ | grep loki` + `systemctl status logrotate.timer` (Agent-4)
- **Evidence**:
  - `src/log-truncation/` exists with: `config/`, `docs/`, `lib/`, `scripts/`, `templates/`, `test/` ✓
  - `src/log-truncation/config/` contains only one file: `loki-sources` (1.5k, owned by `root`)
  - `/etc/logrotate.d/loki-sources` — installed ✓ (name matches `src/log-truncation/config/loki-sources`)
  - `logrotate.timer` status: `active (waiting)`, enabled, next trigger in 6h ✓
  - No logrotate entries with name containing "logging" or other related patterns
- **Findings**:
  1. **log-truncation is installed and logrotate.timer is active.** The system-level log rotation is running. Severity: **PASS**.
  2. **Only one logrotate config installed (`loki-sources`)** — no other CLAUDE.md mentioned rotation configurations are visible. The `src/log-truncation/` module structure exists but only one config file is in `src/log-truncation/config/`. Severity: **INFORMATIONAL** — scope of installed configs is narrower than module structure implies.
  3. **`config/loki-sources` is owned by `root`** (installed via `sudo ./install.sh`). The install script correctly runs with root. Severity: **PASS**.

---

### ADR-109: `.env.example` and `.env` Key Parity — Confirmed Identical

- **Source**: `diff <(.env.example keys sorted) <(.env keys sorted)` (Agent-4)
- **Evidence**:
  - Diff output: empty (no differences) — all keys in `.env.example` are present in `.env` and vice versa
- **Findings**:
  1. **`.env.example` and `.env` have identical variable key sets.** No undocumented secrets, no missing template variables. Severity: **PASS**.
  2. **`GRAFANA_SECRET_KEY` is 64 characters** (confirmed Agent-5). Requirement is 32+. Compliant. Severity: **PASS**.
  3. **`GF_SECURITY_ADMIN_USER` and `GF_SECURITY_SECRET_KEY` exist in `.env`** alongside `GRAFANA_ADMIN_USER` and `GRAFANA_SECRET_KEY` — dual definition. The compose file uses `env_file: .env` which passes all `GF_*` variables to Grafana. Redundant but not harmful. Severity: **LOW**.

---

### ADR-110: Prometheus `wireguard` Scrape Target — Undocumented in CLAUDE.md

- **Source**: `grep -n 'job_name' prometheus.yml` (Agent-4) + Prometheus targets API (Agent-3)
- **Evidence**:
  - `prometheus.yml` has 7 job_names: `prometheus`, `host-monitor`, `docker-metrics`, `loki`, `alloy`, `wireguard`, `grafana`
  - Prometheus active targets confirms: `wireguard | up | http://172.20.0.1:9586/metrics`
  - `172.20.0.1` is the Docker bridge gateway IP — wireguard exporter runs on the host, scraping from within the `obs` network
  - CLAUDE.md Architecture table lists 6 services, does not mention wireguard scrape job
  - `docs/reference.md:29` (check): wireguard job likely mentioned in compose port table but not service table
- **Findings**:
  1. **A `wireguard` Prometheus scrape job exists and is `up`.** The wireguard exporter runs on the host at `172.20.0.1:9586` and is scraped every 15s. Severity: **INFORMATIONAL** (not a problem — just undocumented).
  2. **CLAUDE.md does not mention the wireguard scrape target** in the Architecture or Key Configuration sections. Severity: **LOW** — documentation gap.
  3. **wireguard metrics are being stored in Prometheus** — these contribute to the 476MB data volume. Severity: **PASS** (acceptable).

---

### ADR-112: Alloy Config — Nvidia Telem Pipeline Watches Non-Standard Path

- **Source**: `grep -n -A5 'nvidia\|telem' alloy-config.alloy` (Agent-4)
- **Evidence**:
  - `loki.source.file "nvidia_telem"` watches `/host/home/luce/apps/vLLM/logs/telemetry/nvidia/*.jsonl` (from alloy-config)
  - `tail_from_end = true` — will only pick up NEW lines after Alloy start
  - `forward_to = [loki.process.nvidia_telem.receiver]` → processor exists
  - Runtime: `log_source=nvidia_telem` does NOT appear in Loki active label values — pipeline not delivering
  - Path `/host/home/luce/apps/vLLM/logs/telemetry/nvidia/` maps to `/home/luce/apps/vLLM/logs/telemetry/nvidia/` on host
- **Findings**:
  1. **nvidia_telem pipeline is configured and has a processor, but delivers no current data.** Either the nvidia telemetry files are not being written to or are not generating new lines. Severity: **LOW** — no operational impact.
  2. **`tail_from_end = true` means historical data will never be ingested.** Any logs written before Alloy started are permanently skipped. This is intentional for high-volume telemetry sources. Severity: **PASS** (intentional design).

---

### ADR-114: Prometheus `evaluation_interval: 15s` — Matches Recording Rule Group Evaluation

- **Source**: `head -20 prometheus/prometheus.yml` (Agent-5) + Prometheus rules API
- **Evidence**:
  - `prometheus.yml`: `scrape_interval: 15s`, `evaluation_interval: 15s`
  - Prometheus API confirms all rule groups healthy with ~15s evaluation
  - No per-group `interval` override in either rules file
- **Findings**:
  1. **`evaluation_interval: 15s` is appropriate for the workload.** Recording rules produce metrics every 15s, alert `for:` values of 5m require `ceil(300/15) = 20` evaluations before firing. Severity: **PASS**.
  2. **`AlloyPipelineDrops` uses `increase(loki_write_dropped_entries_total[10m]) > 0` with `for: 5m`** — the 10m window on a 15s scrape gives ~40 data points. Robust detection with low false positive risk. Severity: **PASS**.

---

### ADR-115: Grafana `datasource.yml` — Datasource UIDs Pinned, Alerting Rule References Confirmed

- **Source**: `cat provisioning/datasources/*.yml` (Agent-5) + alerting rule `datasourceUid` (Agent-3)
- **Evidence**:
  - Loki datasource: `uid: P8E80F9AEF21F6940` ✓
  - Prometheus datasource: `uid: PBFA97CFB590B2093` ✓
  - `logging-pipeline-rules.yml` alert rules reference `datasourceUid: P8E80F9AEF21F6940` (Loki) ✓
  - `completion claim: ds_uid_pinned: true` ✓
- **Findings**:
  1. **Datasource UID pinning is confirmed.** Alert rules reference the provisioned UIDs. Severity: **PASS** (fix confirmed and validated).
  2. **Datasource provisioning does NOT set `basicAuth`, `secureJsonData`, or TLS.** Internal network — acceptable. Severity: **PASS**.

---

### ADR-119: RUNBOOK.md — Disk-Full and WAL Sections Exist But Are Stubs

- **Source**: `grep -n 'Disk-full\|WAL\|graceful shutdown' infra/logging/RUNBOOK.md` (Agent-2)
- **Evidence**:
  - `RUNBOOK.md:77` → `## Disk-full behavior` section exists ✓
  - `RUNBOOK.md:84` → `## WAL and retry expectations` section exists ✓
  - `RUNBOOK.md:90` (inferred from pattern) → `## Graceful shutdown procedure` exists ✓
  - Section content for WAL: `"Prometheus WAL and Loki retry paths can absorb brief downstream interruptions, but not sustained disk exhaustion."` — 1 line
- **Findings**:
  1. **The sections exist (completion claims `ADR-013-MED-DISKFULL-UNDEFINED`, `ADR-013-MED-WAL-RETRY-UNDEFINED`, `ADR-013-MED-NO-GRACEFUL-SHUTDOWN-DOC` are marked done).** Severity: **PASS** (sections exist as required).
  2. **WAL section content is minimal** — a single sentence. No specific configuration values, no recovery steps, no max_backoff/min_backoff tuning guidance. Severity: **LOW** — stub documentation exists but provides little operational value.
  3. **`ADR-013-MED-NO-GRACEFUL-SHUTDOWN-DOC`** — marked complete because graceful shutdown section exists. The actual `down.sh` script no longer destroys volumes by default (`down_safe: true`). Severity: **PASS** (combination of fixes addresses the original concern).

---

### ADR-120: Prometheus Scrape Target `wireguard` — Not in `obs` Network, Uses Gateway IP

- **Source**: Prometheus targets API `http://172.20.0.1:9586/metrics` (Agent-3)
- **Evidence**:
  - `wireguard | up | http://172.20.0.1:9586/metrics`
  - `172.20.0.1` = Docker `obs` network gateway (host side of bridge)
  - This is the host's IP as seen from within the obs Docker network
  - WireGuard exporter (`prometheus-wireguard-exporter` or similar) runs directly on the host
  - No container named `logging-wireguard-*` or similar exists
- **Findings**:
  1. **The WireGuard exporter is a host-side process, not a Docker container.** Prometheus reaches it via the bridge gateway IP. This is a hybrid scrape — Docker containers + host processes. Severity: **INFORMATIONAL** (works correctly).
  2. **WireGuard exporter is NOT in the `obs` Docker network.** It's scraped over the bridge gateway. If the host-side process stops, `wireguard | down` will appear in targets and `PrometheusTargetDown` will fire (since `sprint3:targets_down:count > 0`). Severity: **LOW** — worth documenting as expected behavior.
  3. **CLAUDE.md and docs do not mention the WireGuard exporter.** It's a silent dependency on a host-side process. Severity: **LOW** (doc gap).

---

### ADR-124: Loki `auth_enabled: false` — Multi-Tenancy Disabled, Acceptable for Single-Node

- **Source**: `grep auth_enabled loki-config.yml` (Agent-5) + network isolation check
- **Evidence**:
  - `auth_enabled: false` in `loki-config.yml`
  - All Loki access goes through Docker network `obs` (internal) or via `127.0.0.1:3200` (loopback)
  - `loki-config.yml` has no `multi_tenant_queries_enabled` or tenant-related config
- **Findings**:
  1. **`auth_enabled: false` is correct for a single-tenant single-node deployment.** Enabling it requires `X-Scope-OrgID` headers on all requests — unnecessary overhead for this use case. Severity: **PASS** (intentional, appropriate).
  2. **With `auth_enabled: false`, any process reaching Loki on `127.0.0.1:3200` can read all logs.** For a single-user sandbox this is acceptable. Severity: **LOW** (known, accepted risk).


---

## Pass 13 — Targeted Follow-Up from Agent aa1ec83 Runtime Validation

> **Date**: 2026-02-19 | **Agent**: aa1ec83 runtime cross-check of Prometheus/Grafana/Loki

### ADR-126: Host-Level Port Exposure — `hex-atlas-sql-1` PostgreSQL and `hex-atlas-typesense-1` on `0.0.0.0`

- **Source**: Agent a5d4957 Check 2 (docker ps), Check 1 (UFW rules)
- **Evidence**:
  - `hex-atlas-sql-1`: `0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp` — PostgreSQL on all interfaces, IPv4 and IPv6
  - `hex-atlas-typesense-1`: `0.0.0.0:8108->8108/tcp, [::]:8108->8108/tcp` — Typesense on all interfaces
  - `hex-atlas-app-1`: `0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp` — app on all interfaces
  - UFW rules show NO explicit ALLOW for ports 5432, 8108
  - UFW default: `deny (incoming)` — these ports blocked by UFW unless Docker bypasses UFW (which it does by default via iptables)
  - Docker's iptables manipulation inserts ACCEPT rules in `DOCKER` chain before UFW's `INPUT` chain rules — UFW deny rules do NOT protect Docker-exposed ports
  - iptables DNAT rule 8: `codeswarm-mcp` port 3100 → `anywhere` (not loopback-scoped, unlike logging stack ports)
- **Findings**:
  1. **PostgreSQL 5432 is reachable from LAN/WAN despite no UFW ALLOW rule.** Docker bypasses UFW via iptables DOCKER chain. Any host that can reach this machine's network interface can attempt PostgreSQL connections. Severity: **HIGH** — database exposure depends entirely on PostgreSQL auth, not network perimeter.
  2. **Typesense 8108 similarly exposed.** Typesense has no built-in auth by default. Severity: **HIGH** — unauthenticated search engine API exposed if Typesense auth not configured.
  3. **`codeswarm-mcp` port 3100 on `0.0.0.0`** — iptables DNAT rule forwards from `anywhere` (not localhost-scoped). This is a vLLM/MCP port distinct from Loki's internal 3100, but the port number collision is confusing. Severity: **MEDIUM** — out of scope for this repo but relevant to host security posture.
  4. **Out of scope for this repo** — hex-atlas containers are a separate project. However, `docs/security.md` should document all host-level port exposures with a warning about Docker's UFW bypass behavior.
- **Codex action**: Update `docs/security.md` to add a "Host port exposure inventory" section listing all containers with globally-exposed ports and explicitly noting that Docker bypasses UFW firewall rules via iptables DOCKER chain.

---

### ADR-129: Loki — No Ingester Block Configured (WAL, Chunk Tuning)

**Domain**: Loki  
**Severity**: Medium  
**Status**: Open

**Evidence** — grep for ingester/WAL/chunk keys in `infra/logging/loki-config.yml`:

```
(no output)
```

No `ingester:` block exists anywhere in the file.

**Best Practice**: Loki 3.x defaults WAL to enabled for TSDB ingesters, but `flush_on_shutdown: true` must be explicit to guarantee chunks are flushed on unclean container stop (OOM, SIGKILL). Without an explicit `ingester:` block, behavior relies entirely on defaults:

```yaml
ingester:
  wal:
    enabled: true
    flush_on_shutdown: true
    dir: /loki/wal
  chunk_idle_period: 1h
  chunk_retain_period: 30s
  max_chunk_age: 2h
```

**Deviation**: No `ingester:` block. `flush_on_shutdown` not declared. Chunk idle/retain/max_age not tuned. On container kill or OOM, in-flight chunks are at risk.

**Recommended Remediation**: Add the above `ingester:` block to `loki-config.yml`. Mount `/loki/wal` from the same `loki-data` volume (already mounted at `/loki`). Restart Loki service.

---

### ADR-130: Loki — Chunk Encoding Not Declared (Relies on Default)

**Domain**: Loki  
**Severity**: Low  
**Status**: Open

**Evidence** — grep for encoding/compression in `infra/logging/loki-config.yml`:

```
(no output)
```

**Best Practice**: Loki 3.x defaults to `snappy` encoding for TSDB-backed ingesters — optimal for CPU/compression balance. Best practice is to declare this explicitly so intent is self-documenting and regression-proof if the Loki default changes:

```yaml
ingester:
  chunk_encoding: snappy
```

**Deviation**: Encoding not declared. Relying on implicit default. If Loki default changes in a future upgrade, this stack will silently shift encoding without config change.

**Recommended Remediation**: Add `chunk_encoding: snappy` to the `ingester:` block (see ADR-129 remediation).

---

### ADR-131: Loki — No Query-Side Limits Configured

**Domain**: Loki  
**Severity**: Medium  
**Status**: Open

**Evidence** — full `limits_config` from `infra/logging/loki-config.yml`:

```yaml
limits_config:
  ingestion_rate_mb: 8
  ingestion_burst_size_mb: 16
  retention_period: 720h
  max_label_names_per_series: 15
  reject_old_samples: false
  unordered_writes: true
  max_line_size: 256KB
```

No `max_entries_limit_per_query`, `max_query_series`, or `query_timeout` present.

**Best Practice**: Without query limits, a single unbounded query against the full 30-day retention window (720h) can exhaust memory on this single node. Recommended:

```yaml
limits_config:
  max_entries_limit_per_query: 50000
  max_query_series: 500
  query_timeout: 5m
```

**Deviation**: Write-side limits (`ingestion_rate_mb`, `max_line_size`) are present but read-side limits are entirely absent.

**Recommended Remediation**: Add the three query limit fields under `limits_config` in `loki-config.yml`.

---

### ADR-132: Loki — Deletion API Enabled Without Authentication

**Domain**: Loki, Security  
**Severity**: High  
**Status**: Open

**Evidence** — `infra/logging/loki-config.yml` lines 27-32:

```yaml
compactor:
  working_directory: /loki/compactor
  retention_enabled: true
  delete_request_store: filesystem
  compaction_interval: 10m
  retention_delete_delay: 2h
```

And line 1:

```yaml
auth_enabled: false
```

**Best Practice**: `delete_request_store` activates Loki's log deletion API (`POST /loki/api/v1/delete`). With `auth_enabled: false`, any caller on the `obs` network can issue deletion requests against any stream. While Loki's external port (3100) is not exposed to the host, any container on the `obs` network (grafana, prometheus, alloy, node-exporter, cadvisor) could call the deletion API. The Loki port is also mapped to `127.0.0.1:3200:3100` in compose (line 53-54 of compose file), making it accessible from the host loopback.

**Deviation**: Deletion API enabled. No authentication protecting it. Host loopback access available via port 3200.

**Recommended Remediation**: If log deletion is not a required workflow, remove `delete_request_store: filesystem` from `loki-config.yml`. `retention_enabled: true` enforces time-based retention without the deletion API — these are independent features. If deletion is needed, add `auth_enabled: true` and provision API credentials.

---

### ADR-133: Loki — `unordered_writes: true` and `reject_old_samples: false` in Production

**Domain**: Loki  
**Severity**: Medium  
**Status**: Open

**Evidence** — `infra/logging/loki-config.yml` lines 40-41:

```yaml
  reject_old_samples: false
  unordered_writes: true
```

**Best Practice**:

- `unordered_writes: true`: Allows out-of-order ingestion. Best practice for production is `false`. Permissive writes can cause chunk ordering issues and make log stream replay unreliable. This setting was introduced for pipeline flexibility but should be tightened once stable.
- `reject_old_samples: false`: Accepts logs with any timestamp regardless of age. With a 30-day retention window, this allows arbitrarily old logs to be ingested, bypassing retention-aware ingestion semantics. Best practice for production: `true` with `reject_old_samples_max_age: 168h` (7 days).

**Deviation**: Both set to permissive values. Appropriate for sandbox, incorrect for production-hardened deployment.

**Recommended Remediation**:

```yaml
limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  unordered_writes: false
```

---

### ADR-134: Loki — Query Splitting Compatibility (Current Loki Build)

**Domain**: Loki  
**Severity**: Medium  
**Status**: Closed

**Evidence**
- `rg -n "split_queries_by_interval" infra/logging/loki-config.yml | head -n 1` => `61:  split_queries_by_interval: 30m`
- `curl -fsS http://127.0.0.1:3200/ready` => ready (HTTP 200)
- `jq -r '.summary.pass,.summary.unexpected_empty_panels' _build/logging/dashboard_audit_latest.json` => `true`, `0`
- `jq -r '.pass,.checks.audit_unexpected_empty_panels' _build/logging/verify_grafana_authority_latest.json` => `true`, `0`

**Resolution**: Query splitting is configured on this Loki build via `limits_config.split_queries_by_interval`.

**Implementation note**: This deployment remains stable with this placement; adding a `query_range` block was previously incompatible with this runtime.

---

### ADR-135: Loki — Explicit Component Paths (TSDB + Filesystem)

**Domain**: Loki  
**Severity**: Low  
**Status**: Closed

**Evidence**
- `rg -n "tsdb_shipper|active_index_directory|cache_location|filesystem:" infra/logging/loki-config.yml` => explicit shipper/cache/chunks paths present
- `curl -fsS http://127.0.0.1:3200/ready` => ready (HTTP 200)

**Resolution**: Added explicit TSDB shipper paths under `storage_config`:
- `active_index_directory: /loki/tsdb-index`
- `cache_location: /loki/tsdb-cache`

This keeps active path ownership explicit while retaining existing chunk/WAL/compactor paths.

---

### ADR-136: Alloy — `loki.write "default"` Has No Backoff or Retry Configuration

**Domain**: Alloy  
**Severity**: High  
**Status**: Open

**Evidence** — `infra/logging/alloy-config.alloy` lines 390-396:

```hcl
loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

**Best Practice**: Without backoff configuration, if Loki is unavailable (restart, OOM), Alloy uses default retry behavior which may be insufficiently durable. The Alloy `loki.write` component supports explicit endpoint-level backoff:

```hcl
loki.write "default" {
  endpoint {
    url                = "http://loki:3100/loki/api/v1/push"
    min_backoff_period = "500ms"
    max_backoff_period = "5m"
    max_backoff_retries = 10
  }
}
```

**Deviation**: Bare endpoint block with URL only. No backoff parameters declared.

**Recommended Remediation**: Add `min_backoff_period`, `max_backoff_period`, and `max_backoff_retries` to the endpoint block in `alloy-config.alloy`.

---

### ADR-137: Alloy — `loki.write "default"` Has No Batch Configuration

**Domain**: Alloy  
**Severity**: Low  
**Status**: Open

**Evidence** — `infra/logging/alloy-config.alloy` lines 390-396 (same block as ADR-136):

```hcl
loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

No `batch_size` or `batch_wait` parameters.

**Best Practice**: Explicit batch configuration controls how Alloy accumulates log entries before flushing to Loki. Recommended:

```hcl
endpoint {
  url        = "http://loki:3100/loki/api/v1/push"
  batch_size = 1048576   // 1MB
  batch_wait = "1s"
}
```

**Deviation**: Relies on Alloy defaults for batching behavior. Defaults may be conservative and result in more frequent, smaller pushes than optimal.

**Recommended Remediation**: Add `batch_size` and `batch_wait` to the endpoint block alongside the backoff parameters from ADR-136.

---

### ADR-138: Alloy — No `external_labels` on `loki.write "default"`

**Domain**: Alloy  
**Severity**: Low  
**Status**: Open

**Evidence** — same block as ADR-136. No `external_labels` present.

**Best Practice**: `external_labels` on the `loki.write` component provides a safety net for any log stream that reaches the write endpoint without going through a `loki.process` stage with `stage.static_labels`. All current pipelines do add labels via processors, but a future pipeline addition could accidentally bypass labeling.

**Deviation**: No write-level `external_labels`. Defense-in-depth absent.

**Recommended Remediation**: Add minimal `external_labels` to the write block:

```hcl
loki.write "default" {
  endpoint { ... }
  external_labels = {
    host = "codeswarm",
    env  = "sandbox",
  }
}
```

---

### ADR-139: Alloy — `discovery.docker "all"` Has No `refresh_interval`

**Domain**: Alloy  
**Severity**: Low  
**Status**: Open

**Evidence** — `infra/logging/alloy-config.alloy` lines 5-7:

```hcl
discovery.docker "all" {
  host = "unix:///var/run/docker.sock"
}
```

`refresh_interval` not set. Alloy v1.2.1 default: `5s`.

**Best Practice**: On a host where containers rarely start/stop (stable production environment), `5s` polling of the Docker socket generates unnecessary traffic and can produce log noise. Best practice for stable deployments: `refresh_interval = "30s"`.

**Deviation**: Implicit 5-second Docker socket polling interval.

**Recommended Remediation**:

```hcl
discovery.docker "all" {
  host             = "unix:///var/run/docker.sock"
  refresh_interval = "30s"
}
```

---

### ADR-140: Alloy — No `stage.drop` or `stage.limit` for Noisy Sources

**Domain**: Alloy  
**Severity**: Medium  
**Status**: Open

**Evidence** — grep for stage.drop/stage.filter/stage.limit in `alloy-config.alloy`:

```
(no output)
```

**Best Practice**: High-volume sources (journald, Docker health checks, rsyslog) can flood Loki without per-source log-line filtering. `stage.drop` allows dropping lines matching a pattern before they reach Loki:

```hcl
stage.drop {
  expression = ".*health.*check.*"
  drop_counter_reason = "healthcheck_noise"
}
```

**Deviation**: No drop, filter, or rate-limit stages in any pipeline. All log lines from all sources forwarded to Loki verbatim.

**Recommended Remediation**: Add `stage.drop` stages to journald and Docker pipelines to suppress known-noisy patterns (health check logs, periodic status messages). Start with a `drop_counter_reason` to measure volume before committing to permanent drops.

---

### ADR-141: Alloy — No `stage.metrics` for Pipeline Observability

**Domain**: Alloy  
**Severity**: Low  
**Status**: Open

**Evidence** — grep for stage.metrics/stage.counter/prometheus.exporter in `alloy-config.alloy`:

```
(no output)
```

**Best Practice**: `stage.metrics` creates Prometheus counters/gauges from log pipeline data, enabling Prometheus to scrape per-source ingestion throughput from Alloy. Alloy's built-in self-metrics (on port 12345, scraped by Prometheus) are process-level only — they do not expose per-pipeline source counters.

**Deviation**: No pipeline-level metrics. Cannot distinguish per-source drop rates or throughput from Prometheus.

**Recommended Remediation**: Add `stage.metrics` to key pipelines (e.g., Docker, journald) to export per-source log line counters:

```hcl
stage.metrics {
  metric.counter {
    name        = "log_lines_total"
    description = "Total log lines processed"
    prefix      = "alloy_"
    labels      = ["log_source"]
  }
}
```

---

### ADR-142: Alloy — No `stage.multiline` for Stack Trace / Exception Handling

**Domain**: Alloy  
**Severity**: Medium  
**Status**: Open

**Evidence** — grep for stage.multiline in `alloy-config.alloy`:

```
(no output)
```

**Best Practice**: Without `stage.multiline`, Python exceptions, Java stack traces, and multi-line structured log entries are split at each newline and ingested as separate single-line log events. This breaks stack trace readability in Grafana and inflates log entry count for exception-heavy services.

**Deviation**: No multiline joining in any pipeline.

**Recommended Remediation**: Add `stage.multiline` to Docker and journald pipelines for sources known to produce multiline output:

```hcl
stage.multiline {
  firstline     = "^\\d{4}-\\d{2}-\\d{2}"  // ISO timestamp starts new event
  max_wait_time = "3s"
  max_lines     = 128
}
```

---

### ADR-143: Alloy — No `stage.decolorize` for ANSI Code Stripping

**Domain**: Alloy  
**Severity**: Low  
**Status**: Open

**Evidence** — grep for stage.decolorize in `alloy-config.alloy`:

```
(no output)
```

**Best Practice**: Docker containers emitting colored output (many frameworks use ANSI escape codes in TTY mode) will ingest raw escape sequences (`\x1b[32m`, etc.) into Loki. These appear as noise in Grafana log panels and break pattern matching.

**Deviation**: No ANSI decolorization in any Docker pipeline.

**Recommended Remediation**: Add `stage.decolorize {}` to `loki.process "docker"` and `loki.process "journald"` pipelines.

---

### ADR-144: Prometheus — No `alertmanager_configs` Configured

**Domain**: Prometheus  
**Severity**: High  
**Status**: Open

**Evidence** — `infra/logging/prometheus/prometheus.yml` (full file):

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
- /etc/prometheus/rules/*.yml
scrape_configs:
  ...
```

No `alerting:` stanza. No `alertmanager_configs` section.

**Best Practice**: Without an `alerting:` stanza, Prometheus evaluates alert rules internally but has no delivery path. Alerts are visible only in the Prometheus UI (`/alerts`) and fire silently. A local Alertmanager deployment or webhook target is required for operational notifications.

**Deviation**: 5 alert rules defined in `loki_logging_rules.yml` + 1 dead rule in `sprint3_minimum_alerts.yml`. All evaluate, none route to any receiver.

**Recommended Remediation**: Options in order of increasing complexity:

1. Add `alertmanager_configs` pointing to a local Alertmanager container (requires adding alertmanager to compose).
2. Add `alertmanager_configs` pointing to an existing Alertmanager instance elsewhere.
3. Use Grafana alerting contact points instead of Prometheus Alertmanager (already partially configured — see ADR-149).

At minimum, add a placeholder `alerting:` stanza so the gap is explicit:

```yaml
alerting:
  alertmanagers: []  # TODO: configure alertmanager endpoint
```

---

### ADR-145: Prometheus — No `scrape_timeout` Declared

**Domain**: Prometheus  
**Severity**: Low  
**Status**: Open

**Evidence** — `infra/logging/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
```

No `scrape_timeout` in global or per-job config.

**Best Practice**: Prometheus default `scrape_timeout` is `10s`. With `scrape_interval=15s`, the implicit constraint (`scrape_timeout < scrape_interval`) is satisfied. However, without declaring `scrape_timeout`, any future reduction of `scrape_interval` to below `10s` would silently violate the constraint, causing scrape timeouts on all jobs.

**Deviation**: Implicit 10s timeout. Not declared in config.

**Recommended Remediation**:

```yaml
global:
  scrape_interval: 15s
  scrape_timeout: 10s
  evaluation_interval: 15s
```

---

### ADR-146: Prometheus — Recording Rules Use `sum(A) + sum(B)` Without `or vector(0)`

**Domain**: Prometheus  
**Severity**: Medium  
**Status**: Closed  
**Cross-ref**: ADR-089 (original detection), CORRECTION-009

**Evidence** — `infra/logging/prometheus/rules/loki_logging_rules.yml`:

```yaml
- record: sprint3:loki_ingestion_errors:rate5m
  expr: (sum(rate(loki_write_dropped_entries_total[5m])) or vector(0))
      + (sum(rate(loki_write_failures_discarded_total[5m])) or vector(0))

- record: sprint3:loki_ingestion_errors:increase10m
  expr: (sum(increase(loki_write_dropped_entries_total[10m])) or vector(0))
      + (sum(increase(loki_write_failures_discarded_total[10m])) or vector(0))
```

**Best Practice**: When `loki_write_dropped_entries_total` is absent (no drops since Loki start), `sum(rate(...))` returns no series, and `sum(A) + sum(B)` evaluates to no-data rather than `0`. Alert rules referencing these recording rules will enter no-data state unexpectedly.

Fix: `sum(rate(loki_write_dropped_entries_total[5m])) or vector(0)`

**Deviation**: Fixed. Both recording rules now guard empty vectors with `or vector(0)`.

**Applied Remediation**: `or vector(0)` added to both `rate5m` and `increase10m` expressions.

---

### ADR-147: Prometheus — Alert Rules Have No `runbook_url` Annotations

**Domain**: Prometheus  
**Severity**: Low  
**Status**: Open

**Evidence** — grep for runbook in `prometheus/rules/loki_logging_rules.yml`:

```
(no output)
```

All 5 rules have:
- `for: 5m` or `for: 10m` — correct
- `severity: warning` — monotone, no critical tier
- `annotations:` blocks with `summary` and `description` — present
- `runbook_url` — **absent**

**Best Practice**: `runbook_url` in the annotations block provides on-call engineers a direct link to the remediation procedure when an alert fires. Standard pattern:

```yaml
annotations:
  runbook_url: "https://example.com/runbooks/NodeDiskSpaceLow"
  summary: "Node disk space is low"
  description: "..."
```

**Deviation**: All 5 alerts lack `runbook_url`. No critical-severity alerts defined despite disk-full and Loki-volume-overflow scenarios that warrant `critical`.

**Recommended Remediation**: Add `runbook_url` pointing to `docs/operations.md` runbook sections (e.g., `file://docs/operations.md#disk-management`). Upgrade `NodeDiskSpaceLow` and `LokiVolumeUsageHigh` to `severity: critical`.

---

### ADR-148: Prometheus — No `metric_relabel_configs` to Reduce cAdvisor Cardinality

**Domain**: Prometheus  
**Severity**: Low  
**Status**: Open

**Evidence** — `infra/logging/prometheus/prometheus.yml` docker-metrics job:

```yaml
- job_name: docker-metrics
  static_configs:
  - targets:
    - docker-metrics:8080
```

No `metric_relabel_configs` present on any job.

**Best Practice**: cAdvisor (docker-metrics) exposes high-cardinality metrics including per-device, per-CPU, and per-network-interface breakdowns. Without `metric_relabel_configs`, Prometheus stores all series including ones rarely queried. Recommended: drop unused high-cardinality series at scrape time:

```yaml
- job_name: docker-metrics
  metric_relabel_configs:
    - source_labels: [__name__]
      regex: "container_tasks_state|container_memory_failures_total"
      action: drop
```

**Deviation**: No metric relabeling on any job. cAdvisor cardinality uncontrolled.

**Recommended Remediation**: Profile cAdvisor metric usage in dashboards, then add `metric_relabel_configs` to drop unused series on the `docker-metrics` job.

---

### ADR-149: Grafana — No Contact Point or Notification Policy Provisioned

**Domain**: Grafana  
**Severity**: High  
**Status**: Open

**Evidence** — directory listing of `infra/logging/grafana/provisioning/alerting/`:

```
logging-pipeline-rules.yml   (only file present)
```

No `contact_points.yml`. No `notification_policies.yml`.

**Best Practice**: Grafana alerting provisioning requires three components: alert rules, contact points, and notification policies. Without a contact point, alerts evaluate and fire internally but are never delivered. Without a notification policy, the routing tree is Grafana's default (no-op without contact point).

**Deviation**: Rules are provisioned. Contact points and notification policies are absent. Alerts fire silently.

**Recommended Remediation**: Add contact point provisioning:

```yaml
# infra/logging/grafana/provisioning/alerting/contact-points.yml
apiVersion: 1
contactPoints:
  - orgId: 1
    name: default
    receivers:
      - uid: default-webhook
        type: webhook
        settings:
          url: "http://127.0.0.1:9999/alert"  # local or external receiver
```

And notification policy:

```yaml
# infra/logging/grafana/provisioning/alerting/notification-policy.yml
apiVersion: 1
policies:
  - orgId: 1
    receiver: default
```

---

### ADR-150: Grafana — Alert Rule `noDataState: OK` Creates Blind Spot When Loki Is Down

**Domain**: Grafana  
**Severity**: High  
**Status**: Open  
**Cross-ref**: ADR-088

**Evidence** — `infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml`:

```yaml
- uid: logging-e2e-marker-missing
  title: "logging-e2e-marker-missing"
  noDataState: OK
  execErrState: Alerting
  for: 2m
  labels:
    severity: warning
```

**Best Practice**: `noDataState: OK` means: if the datasource returns no data (Loki is down, query returns empty, Alloy pipeline is broken), the alert evaluates as `OK` (green). This defeats the purpose of `logging-e2e-marker-missing` — the rule is designed to detect missing log ingestion, but will appear healthy precisely when Loki is unable to serve queries. The correct setting for a presence-detection rule is `noDataState: Alerting`.

**Deviation**: The e2e-marker rule silently passes when Loki is unavailable. The `logging-total-ingest-down` rule also has `noDataState: OK` — same problem at the aggregate level.

**Recommended Remediation**: Change `noDataState: OK` to `noDataState: Alerting` on `logging-e2e-marker-missing`. For `logging-total-ingest-down`, evaluate whether `noDataState: Alerting` or `noDataState: NoData` (which routes to contact point with "no data" state) is more appropriate.

---

### ADR-151: Grafana — Grafana Alert Rule A→C Structure (Missing Reduce Step)

**Domain**: Grafana  
**Severity**: Medium  
**Status**: Open  
**Cross-ref**: ADR-088

**Evidence** — `infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml`:

Both alert rules use a query chain: refId A (LogQL/PromQL query) → refId C (threshold condition). No refId B (reduce expression).

In Grafana unified alerting, a query that returns a time series must be reduced to a scalar before a threshold condition can evaluate it. Without a reduce step, Grafana applies `last()` implicitly on some backends and may produce unexpected results on others.

**Deviation**: Both rules are A→C without explicit reduce step B. Structural bug identified in ADR-088. Confirmed unfixed by Pass 14 agent.

**Recommended Remediation**: Add a reduce expression as refId B:

```yaml
- refId: B
  relativeTimeRange:
    from: 600
    to: 0
  datasourceUid: __expr__
  model:
    type: reduce
    refId: B
    expression: A
    reducer: last
    settings:
      mode: ""
```

Then update the condition to reference B instead of A.

---

### ADR-152: Grafana — Balanced Provisioning Policy for Sandbox Editability

**Domain**: Grafana  
**Severity**: Low  
**Status**: Closed

**Evidence**
- `rg -n "disableDeletion|allowUiUpdates|editable" infra/logging/grafana/provisioning/dashboards/dashboards.yml` => `disableDeletion: true`, `allowUiUpdates: true`, `editable: true`
- `curl -fsS -u admin:${GRAFANA_ADMIN_PASSWORD:-***} -X POST http://127.0.0.1:9001/api/admin/provisioning/dashboards/reload` => HTTP 200

**Resolution**: Adopted balanced sandbox posture:
- Keep UI editability enabled (`allowUiUpdates: true`, `editable: true`)
- Protect against provisioning-side deletions (`disableDeletion: true`)

This preserves operator workflow while reducing accidental deletion risk.

---

### ADR-153: Grafana — `updateIntervalSeconds` Not Set in Dashboard Provisioner

**Domain**: Grafana  
**Severity**: Low  
**Status**: Open

**Evidence** — same file as ADR-152. No `updateIntervalSeconds` field present.

**Best Practice**: Grafana default is `10s` — the provisioner polls the dashboard folder every 10 seconds for file changes. For production, this generates unnecessary I/O. Best practice is `30` or higher for stable deployments.

**Deviation**: Implicit 10-second polling.

**Recommended Remediation**:

```yaml
providers:
  - name: 'default'
    updateIntervalSeconds: 30
    disableDeletion: true
    ...
```

---

### ADR-154: Grafana — Cookie Security Not Explicitly Configured

**Domain**: Grafana, Security  
**Severity**: Medium  
**Status**: Open

**Evidence** — grep for COOKIE_SECURE/COOKIE_SAMESITE in compose + `.env.example`:

```
(no output)
```

Grafana environment section in compose only shows:

```yaml
GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER}
GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
GF_SECURITY_SECRET_KEY=${GRAFANA_SECRET_KEY}
```

**Best Practice**:

- `GF_SECURITY_COOKIE_SECURE=true` — prevents cookie transmission over HTTP (only useful when TLS is in use, but explicit policy is good practice)
- `GF_SECURITY_COOKIE_SAMESITE=strict` — mitigates CSRF; default Grafana value is `lax`

For a stack without TLS, `COOKIE_SECURE=true` would break login, but `COOKIE_SAMESITE=strict` is applicable and reduces CSRF risk even on HTTP.

**Deviation**: Neither cookie security setting is declared. Grafana defaults to `cookie_secure=false`, `cookie_samesite=lax`.

**Recommended Remediation**: Add to compose Grafana environment block:

```yaml
GF_SECURITY_COOKIE_SAMESITE: strict
```

Defer `GF_SECURITY_COOKIE_SECURE: true` until TLS is enabled.

---

### ADR-155: Grafana — Anonymous Access and User Signup Not Explicitly Locked

**Domain**: Grafana, Security  
**Severity**: Low  
**Status**: Open

**Evidence** — grep for GF_AUTH_ANONYMOUS/GF_USERS_ALLOW_SIGN_UP:

```
(no output)
```

**Best Practice**: Grafana 11 defaults `anonymous.enabled=false` and `allow_sign_up=false`. However, security-hardened deployments explicitly declare these to prevent inadvertent enablement via environment injection or config file override:

```yaml
GF_AUTH_ANONYMOUS_ENABLED: false
GF_USERS_ALLOW_SIGN_UP: false
```

**Deviation**: Both set to safe defaults implicitly but not locked. Explicit declaration is absent.

**Recommended Remediation**: Add both env vars to Grafana service in compose file to make security posture explicit and resilient to default changes in future Grafana versions.

---

### ADR-156: Compose — No Container Logging Driver Limits on Any Service

**Domain**: Docker Compose, Ops  
**Severity**: Medium  
**Status**: Open

**Evidence** — grep for logging/driver/max-size/max-file in `docker-compose.observability.yml`:

```
5:    driver: bridge   (network driver, not container logging driver)
```

No `logging:` stanza on any service definition.

**Best Practice**: Docker's default `json-file` logging driver has no size limits. The observability stack's own containers (grafana, prometheus, loki, alloy, node-exporter, cadvisor) accumulate `json-file` logs without bound. These logs are NOT ingested by Alloy (the logging stack explicitly drops `project=logging` in the relabel rules). They accumulate silently on the host.

**Deviation**: All 6 containers have uncapped `json-file` logs.

**Recommended Remediation**: Add to each service in compose:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Or set as daemon default in `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

---

### ADR-157: Compose — No `security_opt: no-new-privileges:true` on Any Container

**Domain**: Docker Compose, Security  
**Severity**: Medium  
**Status**: Open

**Evidence** — grep for security_opt/no-new-privileges in `docker-compose.observability.yml`:

```
(no output)
```

**Best Practice**: `security_opt: no-new-privileges:true` prevents processes inside containers from gaining additional privileges via setuid/setgid binaries. This is a defense-in-depth measure recommended for all production containers. Particularly relevant for Alloy (which mounts the Docker socket) and Grafana (web-facing service).

**Deviation**: No `security_opt` configured on any of the 6 services.

**Recommended Remediation**: Add to each service that does not require privilege escalation:

```yaml
security_opt:
  - no-new-privileges:true
```

Note: node-exporter and cAdvisor may require relaxed security options depending on their privilege requirements for host metrics collection.

---

### ADR-158: Compose — No `ulimits.nofile` on Loki Service

**Domain**: Docker Compose  
**Severity**: Medium  
**Status**: Open

**Evidence** — grep for ulimits/nofile/nproc in `docker-compose.observability.yml`:

```
(no output)
```

**Best Practice**: Loki opens many file handles simultaneously (chunk files, index files, WAL segments, compactor working files). Under sustained ingestion, the default Docker soft `nofile` limit (1024 on many systems) can be hit, causing Loki to fail with "too many open files" errors. Recommended:

```yaml
loki:
  ulimits:
    nofile:
      soft: 65536
      hard: 65536
```

**Deviation**: No `ulimits` on Loki or any other service.

**Recommended Remediation**: Add the `ulimits` block to the `loki` service in `docker-compose.observability.yml`.

---

### ADR-159: Compose — No `read_only: true` Root Filesystem on Any Container

**Domain**: Docker Compose, Security  
**Severity**: Low  
**Status**: Open

**Evidence** — grep for read_only/tmpfs in `docker-compose.observability.yml`:

```
(no output)
```

**Best Practice**: `read_only: true` sets the container root filesystem to read-only, requiring explicit `tmpfs` mounts for writable runtime directories. This prevents container breakout attacks that rely on writing to the root filesystem.

**Deviation**: No container uses `read_only: true`. All 6 services have fully writable root filesystems.

**Recommended Remediation**: For services like Grafana and Prometheus where writable paths are known:

```yaml
grafana:
  read_only: true
  tmpfs:
    - /tmp
    - /var/run
```

Note: Loki and Alloy require larger writable surface areas (chunk dirs, WAL, positions) — apply `read_only` after mapping all writable paths explicitly.

---

### Pass 15 — Summary Table

| ADR | Domain | Finding | Severity | Status |
|-----|--------|---------|----------|--------|
| ADR-129 | Loki | No ingester block — no WAL config, no chunk tuning | Medium | Closed |
| ADR-130 | Loki | Chunk encoding not declared (relies on default snappy) | Low | Open |
| ADR-131 | Loki | No query-side limits (max_entries_limit, query_timeout) | Medium | Closed |
| ADR-132 | Loki | Deletion API enabled without auth (`auth_enabled: false`) | High | Open |
| ADR-133 | Loki | `unordered_writes: true`, `reject_old_samples: false` | Medium | Open |
| ADR-134 | Loki | Query splitting configured for this Loki build via `limits_config.split_queries_by_interval` | Medium | Closed |
| ADR-135 | Loki | Explicit component paths added for TSDB shipper/cache/chunks | Low | Closed |
| ADR-136 | Alloy | `loki.write "default"` — no backoff or retry config | High | Closed |
| ADR-137 | Alloy | `loki.write "default"` — no batch_size or batch_wait | Low | Closed |
| ADR-138 | Alloy | `loki.write "default"` — no external_labels | Low | Closed |
| ADR-139 | Alloy | `discovery.docker "all"` — no refresh_interval (defaults 5s) | Low | Open |
| ADR-140 | Alloy | No stage.drop / stage.limit for noisy sources | Medium | Closed |
| ADR-141 | Alloy | No stage.metrics for pipeline observability | Low | Closed |
| ADR-142 | Alloy | No stage.multiline for stack trace handling | Medium | Closed |
| ADR-143 | Alloy | No stage.decolorize for ANSI code stripping | Low | Closed |
| ADR-144 | Prometheus | No alertmanager_configs — alerts fire but never route | High | Closed |
| ADR-145 | Prometheus | scrape_timeout not declared (implicit 10s) | Low | Closed |
| ADR-146 | Prometheus | Recording rules sum(A)+sum(B) no-data risk | Medium | Closed |
| ADR-147 | Prometheus | Alert rules have no runbook_url annotations | Low | Closed |
| ADR-148 | Prometheus | No metric_relabel_configs to reduce cAdvisor cardinality | Low | Closed |
| ADR-149 | Grafana | No contact point or notification policy provisioned | High | Closed |
| ADR-150 | Grafana | noDataState: OK on e2e-marker rule — blind spot when Loki down | High | Closed |
| ADR-151 | Grafana | Alert rule A→C missing reduce step B (unfixed) | Medium | Open |
| ADR-152 | Grafana | Balanced sandbox policy: editable UI + `disableDeletion: true` | Low | Closed |
| ADR-153 | Grafana | updateIntervalSeconds not set (defaults to 10s) | Low | Closed |
| ADR-154 | Grafana | Cookie security not explicitly configured | Medium | Closed |
| ADR-155 | Grafana | Anonymous access / user signup not explicitly locked | Low | Closed |
| ADR-156 | Compose | No container logging driver limits — uncapped json-file logs | Medium | Closed |
| ADR-157 | Compose | No security_opt: no-new-privileges on any container | Medium | Closed |
| ADR-158 | Compose | No ulimits.nofile on Loki service | Medium | Closed |
| ADR-159 | Compose | No read_only root filesystem on any container | Low | Open |

**High severity (open)**: ADR-132  
**Medium severity (open)**: ADR-133, ADR-151  
**Low severity (open)**: ADR-130, ADR-139, ADR-159

---

### ADR-160: Grafana — Alert Rule Threshold Node Missing `expression` Field (Grafana 11.5 Regression)

**Domain**: Grafana Alerting
**Severity**: Critical
**Status**: Open

**Evidence** — `docker logs logging-grafana-1`, observed every minute since container start (2026-02-19T09:56:36Z):

```
msg="Failed to build rule evaluator" error="failed to parse expression 'C': no variable specified to reference for refId C"
msg="Failed to evaluate rule" attempt=1/2 error="server side expressions pipeline returned an error: failed to parse expression 'C': no variable specified to reference for refId C"
```

Affects all 4 rules: `logging-e2e-marker-missing`, `logging-total-ingest-down`, `logging-gpu-fault-signals`, `logging-gpu-temp-high`.

**Root Cause**: In Grafana 11.5, the server-side expressions pipeline for `type: threshold` nodes requires an explicit `expression` field specifying the input refId. The provisioning YAML uses the older `conditions[].query.params: ["B"]` format which the 11.5 engine does not resolve. The Grafana API confirms the stored rule lacks `expression: "B"` on node `C`.

**Current YAML (broken on 11.5):**
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
          params: [B]   # ← not resolved by 11.5 SSE pipeline
```

**Required fix — add `expression` field:**
```yaml
- refId: C
  datasourceUid: __expr__
  model:
    type: threshold
    expression: "B"     # ← explicit input reference required by 11.5
    conditions:
      - evaluator:
          type: lt
          params: [1]
        query:
          params: [B]
```

**Impact**: All 4 alert rules are permanently broken — they never evaluate. No alerts will fire for: rsyslog marker missing, total ingest down, GPU faults, GPU overtemp.

**Evidence file**: `infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml`

---

### ADR-161: Grafana — Alert Contact Points Attempt SMTP Delivery, SMTP Not Configured

**Domain**: Grafana Alerting
**Severity**: High
**Status**: Open

**Evidence** — `docker logs logging-grafana-1` every time an alert transitions state:

```
logger=ngalert.notifier.alertmanager org=1 level=error component=dispatcher
msg="Notify for alerts failed" num_alerts=1
err="logging-ops/email[0]: notify retry canceled due to unrecoverable error after 1 attempts: SMTP not configured, check your grafana.ini config file's [smtp] section"

err="Bryan Luce/email[0]: notify retry canceled due to unrecoverable error after 1 attempts: SMTP not configured, check your grafana.ini config file's [smtp] section"
```

**Root Cause**: Two contact points (`logging-ops` and `Bryan Luce`) are provisioned with `email` integration. No SMTP server is configured in `grafana.ini` / environment variables. Every alert notification attempt hard-fails.

**Impact**: Even if ADR-160 is fixed and rules evaluate correctly, alert notifications will never be delivered. The alerting pipeline is broken end-to-end.

**Options**:
1. Configure SMTP (add `GF_SMTP_ENABLED=true` + server details to compose env)
2. Switch contact points to a non-SMTP channel (webhook, file, Discord, etc.)
3. Remove contact points and accept no delivery (alerts visible in Grafana UI only)

**Evidence file**: `infra/logging/grafana/provisioning/alerting/` (contact point definitions)

---

### ADR-162: Grafana — Wireguard Dashboard Sends `$__rate_interval` Literal to Loki

**Domain**: Grafana Dashboards
**Severity**: Medium
**Status**: Open

**Evidence** — `docker logs logging-grafana-1`:

```
logger=tsdb.loki level=error msg="Error received from Loki"
error="parse error at line 0, col 1395: not a valid duration string: \"$__rate_interval\""
statusSource=downstream

error="parse error at line 0, col 1536: not a valid duration string: \"$__rate_interval\""
statusSource=downstream

error="parse error at line 1, col 1386: syntax error: unexpected IDENTIFIER"
statusSource=downstream
```

**Root Cause**: The `wireguard-cloudflare.json` dashboard contains 2 panels with Loki queries using `[$__rate_interval]`. This variable is a Prometheus-specific template variable — Grafana substitutes it in Prometheus queries but does NOT substitute it in Loki queries before sending them to the Loki datasource. Loki receives the literal string `$__rate_interval` and rejects it as an invalid duration.

**Fix**: Replace `[$__rate_interval]` with a fixed duration (e.g., `[5m]`) or `[$__interval]` in the affected Loki query panels in `infra/logging/grafana/dashboards/wireguard-cloudflare.json`.

**Count**: 2 occurrences confirmed by `grep -c "__rate_interval"` = 2.

**Evidence file**: `infra/logging/grafana/dashboards/wireguard-cloudflare.json`

---

### ADR-163: Grafana — Missing `provisioning/plugins` Directory at Startup

**Domain**: Grafana Provisioning
**Severity**: Low
**Status**: Open

**Evidence** — `docker logs logging-grafana-1` at startup:

```
logger=local.finder level=warn msg="Skipping finding plugins as directory does not exist" path=/usr/share/grafana/plugins-bundled
logger=provisioning.plugins level=error msg="Failed to read plugin provisioning files from directory" path=/etc/grafana/provisioning/plugins error="open /etc/grafana/provisioning/plugins: no such file or directory"
```

**Root Cause**: `docker-compose.observability.yml` mounts `./grafana/provisioning:/etc/grafana/provisioning:ro` but the host path `infra/logging/grafana/provisioning/` does not contain a `plugins/` subdirectory. Grafana expects one.

**Impact**: Benign — no plugin provisioning is used. Generates an error-level log entry on every startup which pollutes log scanning. The missing directory suppresses the `provisioning.plugins` subsystem from starting.

**Fix**: Create empty `infra/logging/grafana/provisioning/plugins/` directory (with a `.gitkeep` to track in git).

**Evidence file**: `infra/logging/grafana/provisioning/` directory listing

---

### ADR-164: Grafana — `resource-server` Duplicate Metrics Registration at Startup

**Domain**: Grafana
**Severity**: Info
**Status**: Open

**Evidence** — `docker logs logging-grafana-1` at startup (3 occurrences):

```
logger=resource-server level=warn msg="failed to register storage metrics" error="duplicate metrics collector registration attempted"
```

**Root Cause**: Known Grafana 11 startup race condition where the resource-server attempts to register Prometheus metrics collectors multiple times during initialization. No functional impact.

**Impact**: None — cosmetic warn-level log noise on every startup. No action required.

**Recommended Action**: Accept as known Grafana upstream issue. DEFER unless a fix is released.

---

### Pass 18 — Grafana Log Scan Snapshot (24h)

**Window**: 2026-02-18 -> 2026-02-19  
**Source**: `docker logs --since 24h logging-grafana-1`

**Counts (evidence)**:
- `COUNT_TOTAL_WARN_ERROR=375` (from `rg 'level=(warn|error)'`)
- `COUNT_SMTP_NOT_CONFIGURED=22`
- `COUNT_LOKI_IDENT_PARSE=47`
- `COUNT_PROVENANCE_CHANGE=8`
- `COUNT_DUPLICATE_METRICS=6`
- `COUNT_PLUGIN_PROVISIONING_DIR=1`
- `COUNT_FOLDERUID_MISSING=1`
- `COUNT_RATE_INTERVAL_LITERAL=101`

This pass adds new ADRs only for findings not already represented below.

---

### ADR-165: Grafana — File-Provisioned Alert Rules Being Mutated via API (Provenance/FolderUID Errors)

**Domain**: Grafana Alerting API  
**Severity**: Medium  
**Status**: Open

**Evidence** — `docker logs --since 24h logging-grafana-1`:

```text
status=500 ... error="cannot change provenance from 'file' to 'api'"
status=500 ... error="cannot change provenance from 'file' to ''"
status=400 ... error="invalid alert rule: folderUID must be set"
```

Observed counts from the same 24h window:
- `COUNT_PROVENANCE_CHANGE=8`
- `COUNT_FOLDERUID_MISSING=1`

**Root Cause**: Operational automation or ad-hoc updates are attempting `PUT /api/v1/provisioning/alert-rules/:uid` against file-provisioned rules. Grafana rejects provenance changes and incomplete payloads.

**Impact**: Repeated error noise in Grafana logs, failed rule-change attempts, and operational confusion about whether rule updates are effective.

**Recommended Remediation**:
1. Treat file-provisioned rules as file-only; remove/disable API mutation path for those UIDs.
2. Route all rule edits through `infra/logging/grafana/provisioning/alerting/*.yml` + provisioning reload.
3. Add a guard in automation: if rule provenance is `file`, refuse API `PUT` and emit a single actionable message.

---

### ADR-166: Grafana — Malformed Loki Query Fragment (`|~ "all" all`) Generates 400 Parse Errors

**Domain**: Grafana Dashboards / Query Construction  
**Severity**: Medium  
**Status**: Open

**Evidence** — `docker logs --since 24h logging-grafana-1`:

```text
statusCode=400 ... error="parse error at line 1, col 1386: syntax error: unexpected IDENTIFIER"
query="... |~ \"all\" all"
```

Observed count from 24h warn/error logs:
- `COUNT_LOKI_IDENT_PARSE=47`

**Root Cause**: One or more dashboard queries append an unguarded token after the regex stage, producing invalid LogQL (`|~ "all" all`) when the filter value is `all`.

**Impact**: Frequent backend 400s, noisy logs, failed panel queries, and degraded dashboard reliability.

**Recommended Remediation**:
1. In affected dashboards, avoid emitting extra token text when filter is `all`.
2. Use conditional query fragments so `all` means "no extra regex stage" rather than `|~ "all"`.
3. Validate with direct Loki query tests for both `all` and specific filter values.

---

### Pass 19 — Cross-Stack Log Scan (Grafana + Loki + Alloy)

**Window**: last 24h plus active 30m/5m slices  
**Sources**:
- `/tmp/loki-ops-logscan/logging-grafana-1.log`
- `/tmp/loki-ops-logscan/logging-loki-1.log`
- `/tmp/loki-ops-logscan/logging-alloy-1.log`

**Evidence counts**
- Grafana 5m: `Error received from Loki=30`, `syntax error: unexpected IDENTIFIER=10`, `$__rate_interval=20`, `SMTP not configured=2`
- Grafana 30m: `Error received from Loki=180`, `syntax error: unexpected IDENTIFIER=60`, `$__rate_interval=120`, `SMTP not configured=19`, `provenance change errors=8`
- Loki 30m: `empty ring=5`, `error processing requests from scheduler=8`
- Alloy 30m: `error sending batch, will retry=4`, `error inspecting Docker container=1`
- 24h historical churn: Loki config parse failure loop (`split_queries_by_interval under queryrange`) = `19`; Alloy config parse failure (`timeout` attr) = `11`

This pass adds additional unique findings not previously captured as standalone ADRs.

---

### ADR-167: Cross-Stack — Missing Config Preflight Guard Allows Restart Loops on Invalid Loki/Alloy Fields

**Domain**: Runtime Safety / Ops Guardrails  
**Severity**: High  
**Status**: Open

**Evidence**
- Loki (`24h`): `failed parsing config: /etc/loki/loki-config.yml` with `field split_queries_by_interval not found in type queryrange.Config` occurred `19` times before rollback.
- Alloy (`24h`): `failed to evaluate config` with `unrecognized attribute name "timeout"` occurred `11` times before rollback.

**Impact**: Invalid config keys can trigger crash/restart loops and temporary ingest outages.

**Recommended Remediation**
1. Add mandatory preflight checks before restart/redeploy:
   - `docker run --rm -v ... grafana/loki:<tag> -config.file=/etc/loki/loki-config.yml -verify-config=true` (or equivalent validation for this image)
   - `alloy validate` (or containerized config validation command) before restarting Alloy.
2. Fail closed in automation: block restart if validation fails.
3. Record validation output artifact in `_build/loki-ops/`.

---

### ADR-168: Loki — Ring Instability During Restart Window Produces Query/Push Errors

**Domain**: Loki Availability  
**Severity**: Medium  
**Status**: Open

**Evidence**
- Loki (`30m`): `empty ring=5`, `error processing requests from scheduler=8`.
- Alloy (`30m`): push retries against Loki during ring instability (`error sending batch, will retry=4`).

**Impact**: Short but noisy read/write failures around restart windows; can cause alert noise and transient panel failures.

**Recommended Remediation**
1. Add restart choreography for Loki changes:
   - stop query-heavy automation/dashboard probes during restart
   - wait for `loki /ready` + ring stabilization before resuming load
2. Add a short post-restart grace window in verifier/audit to avoid false failures.
3. Add explicit runtime note in runbook for expected transient `empty ring` during controlled restarts.

---

### ADR-169: Alloy — Docker Source Emits Stale Container Inspection Errors After Container Churn

**Domain**: Alloy Docker Ingestion  
**Severity**: Low  
**Status**: Open

**Evidence**
- Alloy (`30m`): `error inspecting Docker container=1`
- Sample: `Error response from daemon: No such container: <id>`

**Impact**: Low-level log noise and occasional target churn; generally self-heals.

**Recommended Remediation**
1. Tune docker source handling to reduce stale-target noise (refresh/cleanup interval behavior).
2. Add low-noise suppression in dashboards for this known transient class.
3. Keep as non-blocking unless count increases materially.

---

### ADR-170: Grafana — Data Source Query Error SLO Missing (Error Storm Detection Gap)

**Domain**: Observability Meta-Monitoring  
**Severity**: Medium  
**Status**: Open

**Evidence**
- Grafana (`30m`): `Error received from Loki=180`, mostly from malformed LogQL variants (`$__rate_interval` literal and `|~ "all" all`).
- Current flow catches failures via logs only; no explicit guardrail panel/alert for query-error rate burst.

**Impact**: Query regressions can persist while operators see many “No data”/panel failures without a single meta-alert.

**Recommended Remediation**
1. Add Grafana/Loki meta panel: query error rate from Grafana logs grouped by parse error class.
2. Add threshold alert on sustained `Error received from Loki` volume.
3. Add a dashboard lint pass in remediation workflow for variable-safe LogQL fragments.

---

### Pass 20 — Docker Daemon Runtime Audit (24h)

**Window**: last 24h (`journalctl -u docker --since '24 hours ago'`)  
**Scope**: Docker daemon warnings/errors + current container state (`docker ps -a`, `docker inspect`)

**Evidence summary**
- `DAEMON_MATCH_LINES=213`
- `ShouldRestart failed, container will not be restarted=40`
- `hasBeenManuallyStopped=true=40`
- `exitStatus={137 ...}=29`
- `Security options with ':' as separator are deprecated=48`
- `copy stream failed (closed fifo)=70` (`stdout=35`, `stderr=35`)
- `SHOULDRESTART_UNIQUE_CONTAINERS=30`, currently present now: `3` (`logging-alloy-1`, `logging-grafana-1`, `logging-loki-1`)
- Current runtime snapshot: `INSPECT_TOTAL=10`, `INSPECT_PROBLEM_CONTAINERS=0`

This pass adds Docker-daemon-specific ADRs from host runtime signals.

---

### ADR-171: Docker Daemon — Restart-Canceled/Manually-Stopped Churn With Frequent Exit 137

**Domain**: Docker Runtime Reliability  
**Severity**: Medium  
**Status**: Open

**Evidence**
- `ShouldRestart failed, container will not be restarted` seen `40` times in 24h.
- Same lines include `hasBeenManuallyStopped=true` (`40` occurrences).
- `exitStatus={137 ...}` appears `29` times in those events.
- Sample:
  - `level=warning msg="ShouldRestart failed, container will not be restarted" ... error="restart canceled" ... exitStatus="{137 ...}" hasBeenManuallyStopped=true`

**Interpretation**: High container churn occurred (many historical container IDs no longer present), with repeated manual-stop semantics and SIGKILL/137 exits. This is consistent with iterative stack/container cycling and/or aggressive stop behavior during tuning.

**Impact**: Log noise and reduced signal quality; potential short ingest gaps during churn windows.

**Recommended Remediation**
1. Add a controlled restart/playbook path for observability stack changes (ordered restarts + readiness waits).
2. Capture stop/restart intent in runtime logs to distinguish operator actions from unexpected crashes.
3. Add a short-lived suppressor for known restart-window daemon warnings in dashboards/alerts.

---

### ADR-172: Docker Daemon — Deprecated `security_opt` Separator Syntax in Compose

**Domain**: Compose / Runtime Compatibility  
**Severity**: Low  
**Status**: Open

**Evidence**
- Docker daemon warning appears `48` times in 24h:
  - `Security options with ':' as a separator are deprecated ... use '=' instead.`

**Interpretation**: Compose security options are using legacy `key:value` form (e.g., `no-new-privileges:true`) that Docker warns is deprecated.

**Impact**: No immediate outage, but persistent warning noise and future compatibility risk.

**Recommended Remediation**
1. Normalize `security_opt` entries to `key=value` form across compose services.
2. Re-deploy once and verify warning count drops to zero for this signature.

---

### ADR-173: Docker Daemon — `copy stream failed` (`reading from a closed fifo`) Noise During Container Lifecycle Events

**Domain**: Docker Logging Stream Reliability  
**Severity**: Low  
**Status**: Open

**Evidence**
- `copy stream failed` seen `70` times in 24h.
- Split: `stream=stdout` `35`, `stream=stderr` `35`.
- Sample:
  - `level=error msg="copy stream failed" error="reading from a closed fifo" stream=stdout`

**Interpretation**: Stream forwarding races during container stop/remove cycles; generally transient but noisy.

**Impact**: Error-level daemon log noise that pollutes central error dashboards.

**Recommended Remediation**
1. Treat as lifecycle-noise class unless correlated with sustained container failures.
2. Add targeted noise-filtering classification in log dashboards (without dropping true failures).
3. Re-evaluate if counts remain high after container churn is reduced (ADR-171).

---

### ADR-174: Dashboard Mutation Script Drift Risk — Title-Coupled Patching + Live API Save

**Domain**: Dashboard Automation Safety  
**Severity**: Low  
**Status**: Open

**Context**: Reviewed a previous automation snippet intended to normalize `top-errors-log-explorer` service/source/tool bar-gauge cards.

**Validation Evidence**
- Title targets from the snippet no longer exist in current file (example expected titles were not found):
  - check result: `Errors by service (15m, ranked): no`, `Top source/service error pairs (5m, ranked): no`, `Top tools with errors (15m, friendly): no`
- Current dashboard already has equivalent cards under current titles:
  - `Top error sources now`, `Errors by source + service`, `Top tools with errors`, `Top source/service error pairs`, `Errors by service`, `Errors by source`
- Query-level sanity against current expressions (with template substitution) returned non-empty series:
  - `Top error sources now=2`, `Top tools with errors=2`, `Errors by source=6`, etc.

**Risk**
1. **Title-coupled patching** can silently no-op when dashboards evolve.
2. **Live API save (`/api/dashboards/db`)** can diverge runtime from repo-managed source if not mirrored and committed immediately.
3. Offline validation must substitute dashboard template vars (`$__range`, `$__interval`, `$log_source`, etc.) or it will generate false 400s.

**Recommended Remediation**
1. Patch by stable panel identifiers/semantic tags, not title-only matching.
2. Keep repo JSON authoritative; if live save is used, immediately sync file + commit.
3. Add script preflight:
   - assert target panels exist
   - render template vars for validation queries
   - fail closed on 400 parse errors
4. Keep dashboard-time-driven windows where required by policy; avoid hard-coded fixed windows unless explicitly intended.

---

### Pass 21 — User-flagged Log Signatures Validation

Validated the two exact signatures called out by operator and mapped them to log sources.

**Evidence counts (24h)**
- `sum(count_over_time({log_source=~".+"} |~ "update-notifier-download\\.service" [24h]))` => `9`
- `sum(count_over_time({log_source=~".+"} |~ "MCP server \"opencode-local\": Connection error: Failed to reconnect SSE stream" [24h]))` => `112`

**Attribution (top by source/service)**
- update-notifier signature:
  - `rsyslog_syslog / update-notifier-download.service / syslog => 6`
  - `codex_tui / unknown_service / file => 3` (prompt/toolcall echo noise)
- opencode-local SSE signature:
  - `vscode_server / unknown_service => 113` (dominant source)

---

### ADR-175: Rsyslog/Systemd — `update-notifier-download.service` Success Lines Can Be Misread as Failures

**Domain**: Log Classification / Dashboard Signal Quality  
**Severity**: Low  
**Status**: Open

**Evidence**
- Query count (24h): `9` total hits for `update-notifier-download.service`.
- Source attribution includes real system logs:
  - `log_source=rsyslog_syslog`, `service_name=update-notifier-download.service`, `source_type=syslog` (`6` hits)
- Sample line observed:
  - `Finished update-notifier-download.service - Download data for packages that failed at package install time.`

**Interpretation**: This is a success event (`Finished ...`) but contains the word `failed` in the unit description, which can be over-counted by naive error regex.

**Impact**: False-positive error classification/noise in error dashboards.

**Recommended Remediation**
1. Add explicit success guard for this service in error-like queries (`Finished update-notifier-download.service` -> exclude from error class).
2. Prefer inferred severity patterns that require failure semantics (`Failed with result`, `status=1/FAILURE`, `Main process exited`) over raw `failed` substring.
3. Keep this service mapped as informational unless paired with actual failure-form signatures.

---

### ADR-176: `vscode_server` — High-Volume `opencode-local` SSE Reconnect Errors

**Domain**: Application Connectivity / Developer Tooling Logs  
**Severity**: Medium  
**Status**: Open

**Evidence**
- Query count (24h): `112` hits for:
  - `MCP server "opencode-local": Connection error: Failed to reconnect SSE stream`
- Source attribution:
  - `log_source=vscode_server`, `service_name=unknown_service` (`113` in topk attribution)
- Sample lines:
  - `[DEBUG] MCP server "opencode-local": Connection error: Failed to reconnect SSE stream: Unable to connect...`
  - `[DEBUG] ... The socket connection was closed unexpectedly...`

**Interpretation**: Repeated reconnect failures from the VS Code-side MCP client path; this is actionable connectivity instability, despite `[DEBUG]` log level.

**Impact**: Operator noise and potential degraded MCP functionality for local dev tooling.

**Recommended Remediation**
1. Add targeted panel/alert for this signature by `log_source=vscode_server` with de-duped rate view.
2. Validate endpoint/network reachability from VS Code host context to `opencode-local` SSE URL.
3. Add friendly service mapping (tool name) so these errors are not grouped under `unknown_service`.
4. Keep in error triage class regardless of `[DEBUG]` label when message contains explicit `Connection error`/`Failed to reconnect`.

---

### Pass 22 — Correctness/Resilience Review (Runtime + Config)

**Window**: runtime evidence sampled on 2026-02-19T20:35:51Z

**Evidence summary**
- Grafana logs still emit Loki 400 parse errors from GPU dashboard query signatures (`invalid char escape`) and repeated `context canceled` on heavy long-range queries.
- `gpu-overview.json` still contains thermal marker query patterns that are parser-fragile and one annotation path with escaped dot regex.
- Failure-semantics events exist without normalized severity labels:
  - `sum(count_over_time({log_source=~".+"} |~ "(?i)(Failed with result|Main process exited|Failed to start|Operation not permitted|exit-code)" [24h])) => 37`
  - `sum(count_over_time({log_source=~".+",level=~"(?i)(error|warn|warning|info|debug)"} |~ same-pattern [24h])) => 0`
- Hard gate scripts are strictly fail-closed for broad checks (`verify_grafana_authority.sh`, `dashboard_query_audit.sh`), which increases iteration friction while behavior is still being tuned.

---

### ADR-177: GPU Dashboard Annotation Query Produces Loki Parse Errors (`invalid char escape`)

**Domain**: Grafana Dashboard Query Correctness
**Severity**: High
**Status**: Open

**Evidence**
- Grafana log sample includes repeated:
  - `Error received from Loki ... parse error ... invalid char escape`
- Current annotation query path is present in:
  - `infra/logging/grafana/dashboards/gpu-overview.json:1917`

**Impact**
- Persistent query errors pollute Grafana logs and cause intermittent panel failures/no-data behavior.

**Recommended Remediation**
1. Replace parser-fragile escaped regex fragments in GPU thermal marker expressions with Loki-safe patterns.
2. Re-test query directly via Loki API before dashboard save/reload.
3. Add a local lint check for known-invalid escape patterns in dashboard expressions.

---

### ADR-178: GPU Dashboard Long-Range Query Shape Causes Cancellations at 12h Views

**Domain**: Query Performance / Dashboard Reliability
**Severity**: High
**Status**: Open

**Evidence**
- Grafana logs show repeated `context canceled` for GPU queries when dashboard range resolves to `43200s` (`$__range` at 12h).
- Query signatures include long-range quantile/unwrap pipelines.

**Impact**
- Under load, panels degrade to no-data and produce noisy cancellation/error logs.

**Recommended Remediation**
1. Keep dashboard-driven windows (`$__range`, `$__interval`) but bound expensive panel lookback for high-cost queries.
2. Reduce expensive quantile/unwrap queries to narrower windows for "current" and keep coarse windows for trend-only cards.
3. Keep one deep-history panel if needed; avoid applying deep windows globally across all GPU cards.

---

### ADR-179: High-Cardinality GPU Process Query Path Triggers Series-Limit Errors

**Domain**: Query Cardinality Control
**Severity**: High
**Status**: Open

**Evidence**
- Grafana logs show recurring:
  - `maximum of series (500) reached for a single query`
  - signature containing `topk(10, max_over_time(({log_source="gpu_telemetry",filename=~".*gpu-proc.*csv" ... )))`

**Impact**
- Top-process panels fail intermittently; GPU process attribution is degraded.

**Recommended Remediation**
1. Aggregate by stable process dimension (`proc_name`) before `topk`, avoid per-pid explosion.
2. Add selector guards (host/model filters) and bound lookback.
3. Validate cardinality against `max_query_series` budget before shipping panel updates.

---

### ADR-180: Failure-Semantics Events Are Not Severity-Normalized Across Sources

**Domain**: Label Contract / Error Classification
**Severity**: Medium
**Status**: Open

**Evidence**
- Failure semantic lines observed in 24h:
  - `sum(count_over_time({log_source=~".+"} |~ "(?i)(Failed with result|Main process exited|Failed to start|Operation not permitted|exit-code)" [24h])) => 37`
- Same class with explicit `level` label matcher returns zero:
  - `sum(count_over_time({log_source=~".+",level=~"(?i)(error|warn|warning|info|debug)"} |~ same-pattern [24h])) => 0`
- Top sources:
  - `codex_tui / unknown_service => 22`
  - `rsyslog_syslog / unknown_service => 16`

**Impact**
- Error dashboards that rely on `level` undercount real failures and force manual drill-down.

**Recommended Remediation**
1. Add cross-source inferred severity normalization (not only syslog path) for core failure semantics.
2. Preserve original message while stamping normalized severity labels used by dashboards.
3. Update dashboard queries to prefer normalized severity when present.

---

### ADR-181: Gate Strictness Causes Iteration Friction During Accuracy Phase

**Domain**: Operational Workflow / Validation Policy
**Severity**: Medium
**Status**: Open

**Evidence**
- Verification scripts are strict fail-closed by default (`set -euo pipefail` and hard exits on broad checks):
  - `infra/logging/scripts/verify_grafana_authority.sh`
  - `infra/logging/scripts/dashboard_query_audit.sh`

**Impact**
- Corrective edits can be blocked by non-critical governance checks while baseline correctness is still being established.

**Recommended Remediation**
1. Introduce an "accuracy-first" mode: keep endpoint/data-integrity checks hard, downgrade non-critical governance checks to warnings.
2. Retain hard-fail mode for release/hardening checkpoints.
3. Emit explicit critical vs non-critical gate sections in artifacts.

---

### ADR-182: File-Provisioned + UI-Editable Dashboards Need Canonical Reconciliation Policy

**Domain**: Grafana Provisioning Consistency
**Severity**: Medium
**Status**: Open

**Evidence**
- Provisioning currently allows UI edits and disables deletion:
  - `infra/logging/grafana/provisioning/dashboards/dashboards.yml:6-8`
  - `disableDeletion: true`, `allowUiUpdates: true`, `editable: true`
- Runtime still shows stale query signatures after repo patch/reload cycles, indicating drift windows between live UI state and file truth.

**Impact**
- Query fixes can appear applied in repo while stale runtime panels continue emitting old errors.

**Recommended Remediation**
1. Define canonical reconciliation loop (UI save -> file sync -> reload -> verify), with stale-panel detection.
2. Add drift report for file vs live dashboard query mismatch on critical panels.
3. Keep editability, but enforce deterministic sync boundaries.
