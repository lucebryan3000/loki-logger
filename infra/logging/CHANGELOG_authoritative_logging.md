# Changelog — Grafana as Authoritative Logging

## Scope
- Investigate current Grafana-as-authority state and blockers
- Validate verifier + machine PASS artifact
- Record operational proof pointers

## Current evidence snapshot
- Grafana health: `GET /api/health` => database ok
- Ruler API contains `logging-e2e-marker-missing` and `logging-total-ingest-down` with `provenance=file`
- Loki ready and Prom healthy are reachable
- Verifier artifact `_build/logging/verify_grafana_authority_latest.json` has `.pass=true`
- One direct E2E run flaked on journald marker visibility; verifier/timer path still PASS

## Recent commits (last 15)
41f4f0f (HEAD -> logging-configuration, origin/logging-configuration) ops: harden Grafana authority (alert posture + verifier v2 + docs consolidation)
fd9f734 ops: make Grafana authoritative for logging (alerts + runbook + verification)
f87ae91 docs: add logging visibility release notes and alert checklist
f0c0570 grafana: add host + container overview dashboard
3e6292e grafana: enhance pipeline health dashboard
0c55887 grafana: add pipeline health dashboard
bf4f744 chore: ignore local archives
8039db8 logging: add rsyslog syslog ingest in alloy
456ce74 wip
32ea1ce Update Alloy and Docker Compose configurations
4d293cc Sprint-4: Log rotation system + WireGuard monitoring + playbook enhancement
7c23c10 prompt-exec: prompt-01-ok 20260215T012638Z
e6bf76f prompt-exec: prompt-audit 20260215T005744Z
43fb666 Loki-prompt-UAT-Datasource-Remediation
b0e59c9 Loki-prompt-15 — Sprint-3 Phase 5b: Alert Proof Harness (deterministic test + clean revert)

## Recent stats (last 10)
commit 41f4f0f959f29fe7199e606d18c00b2020b843ff
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 05:19:17 2026 -0600

    ops: harden Grafana authority (alert posture + verifier v2 + docs consolidation)
    
    Harden alert posture, upgrade verifier to v2 with JSON artifact, and consolidate alert docs canonically.

 infra/logging/ALERTS_CHECKLIST.md                 |  3 +
 infra/logging/RUNBOOK.md                          |  9 ++-
 infra/logging/scripts/verify_grafana_authority.sh | 79 +++++++++++++++++++----
 3 files changed, 77 insertions(+), 14 deletions(-)

commit fd9f734fe536edd50851cb2ea45462cf6d0e5a38
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 04:58:11 2026 -0600

    ops: make Grafana authoritative for logging (alerts + runbook + verification)
    
    Provision best-effort Grafana alert rules, add operator runbook, and add a one-shot verification script.

 infra/logging/RUNBOOK.md                           | 41 ++++++++++++
 .../alerting/logging-pipeline-rules.yml            | 73 ++++++++++++++++++++++
 infra/logging/scripts/verify_grafana_authority.sh  | 30 +++++++++
 3 files changed, 144 insertions(+)

commit f87ae9196c3b4a904b18e60f48558fc39d04022b
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 04:45:59 2026 -0600

    docs: add logging visibility release notes and alert checklist
    
    Document shipped dashboards, verification steps, and minimal alert queries.

 infra/logging/ALERTS_CHECKLIST.md                 | 23 +++++++++++++++++++++++
 infra/logging/PR_BUNDLE_logging_visibility.md     | 21 +++++++++++++++++++++
 infra/logging/RELEASE_NOTES_logging_visibility.md | 22 ++++++++++++++++++++++
 3 files changed, 66 insertions(+)

commit f0c05704fc859b7465e234e810a92488309d150d
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 04:38:52 2026 -0600

    grafana: add host + container overview dashboard
    
    Baseline node-exporter + cadvisor visibility: CPU, memory, disk, top containers, key restarts.

 .../dashboards/host-container-overview.json        | 147 +++++++++++++++++++++
 1 file changed, 147 insertions(+)

commit 3e6292e74d5eed278426a474f533798abf85ead5
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 04:38:47 2026 -0600

    grafana: enhance pipeline health dashboard
    
    Add log_source drilldown and E2E marker signal (MARKER=) for faster triage.

 .../grafana/dashboards/pipeline-health.json        | 75 ++++++++++++++++++----
 1 file changed, 64 insertions(+), 11 deletions(-)

commit 0c55887ead340f62040d25dec8f7b0d2ed7e0594
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 03:38:03 2026 -0600

    grafana: add pipeline health dashboard
    
    Baseline dashboard for Loki queryability, rsyslog syslog ingest trends, forwarding error signal, and Alloy restart visibility via Prometheus.

 .../grafana/dashboards/pipeline-health.json        | 358 +++++++++++++++++++++
 1 file changed, 358 insertions(+)

commit bf4f7449a814281b31b097534abd8ea2936da8b6
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 03:32:50 2026 -0600

    chore: ignore local archives
    
    Keep local backup artifacts out of git status.

 .gitignore | 2 ++
 1 file changed, 2 insertions(+)

commit 8039db8245ebdf1e5b98127786c7d6e2d6521320
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 03:31:37 2026 -0600

    logging: add rsyslog syslog ingest in alloy
    
    Enable loki.source.syslog on TCP 1514 for localhost rsyslog forwarding; label streams for reliable Loki queries.

 infra/logging/alloy-config.alloy | 14 ++++++++++++++
 1 file changed, 14 insertions(+)

commit 456ce74a77265f601038e8fb5faf2e9eba63a14b
Author: Bryan Luce <luce@appmelia.com>
Date:   Sat Feb 14 23:44:14 2026 -0600

    wip

 .claude/commands/logging-add-source.md             | 184 +++++++++++
 .claude/commands/py-basher.md                      | 210 ++++++++++++
 docs/cloudflared-queries.md                        | 181 +++++++++++
 infra/logging/alloy-config.alloy                   | 108 +++++++
 .../alloy-config.alloy.backup-20260214-222214      | 335 +++++++++++++++++++
 ...config.alloy.backup-cloudflared-20260214-223706 | 355 +++++++++++++++++++++
 scripts/add-log-source.sh                          | 183 +++++++++++
 7 files changed, 1556 insertions(+)

commit 32ea1ced44df7ce0536e8d100dc8c719882b45b5
Author: Claude (Auto) <auto@localhost>
Date:   Sat Feb 14 23:43:14 2026 -0600

    Update Alloy and Docker Compose configurations
    
    - Alloy config: clarify scrape intervals and target configuration
    - Docker Compose: adjust environment variable handling and service startup order
    
    Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>

 infra/logging/alloy-config.alloy               | 8 ++++----
 infra/logging/docker-compose.observability.yml | 9 ++++++---
 2 files changed, 10 insertions(+), 7 deletions(-)

## Proof pointers
- Grafana: `curl -u admin:*** http://127.0.0.1:9001/api/health`
- Ruler: `curl -u admin:*** http://127.0.0.1:9001/api/ruler/grafana/api/v1/rules`
- Loki ready: `curl -fsS http://127.0.0.1:3200/ready`
- Prom ready: `curl -fsS http://127.0.0.1:9004/-/healthy`
- Verifier: `bash infra/logging/scripts/verify_grafana_authority.sh`

## Milestone: auditability-by-source (80e8ee3)
- Commit anchor: 80e8ee3
- Delivered: Source Index + per-log_source dashboards + verifier source coverage + audit pass
- Follow-up delivered: second-dimension dashboards (service_name) + verifier/runbook deterministic semantics

### Proof pointers
- Source index provisioned: GET /api/dashboards/uid/codeswarm-source-index
- Source coverage artifact: _build/logging/log_source_values.json
- Audit artifact: _build/logging/dashboard_audit_latest.json
- Verifier artifact: _build/logging/verify_grafana_authority_latest.json
- Dimension evidence: _build/logging/chosen_dimension.txt and _build/logging/dimension_values.txt

### Recent commits (latest 10)
80e8ee3 (HEAD -> logging-configuration, origin/logging-configuration) grafana: add source index and per-source auditability coverage
a781ef8 grafana: clear empty panels and add top errors explorer
2e4ff65 ops: normalize dashboard datasource UIDs and add query audit
ec03325 grafana: fix empty dashboard queries against live Prom/Loki labels
e9ac40c ops: harden E2E check and add deterministic state report
619ccf7 docs: add authoritative logging state changelog
41f4f0f ops: harden Grafana authority (alert posture + verifier v2 + docs consolidation)
fd9f734 ops: make Grafana authoritative for logging (alerts + runbook + verification)
f87ae91 docs: add logging visibility release notes and alert checklist
f0c0570 grafana: add host + container overview dashboard

## Milestone: adopted non-editable/plugin dashboards (cfabc78)
- Commit anchor: cfabc78
- Delivered: inventory of non-editable dashboards and repo-managed adopted copies under `infra/logging/grafana/dashboards/adopted/`
- Policy: edit adopted dashboards via Git only (file-provisioned), do not edit plugin-owned originals

### Proof pointers
- Offenders inventory: `_build/logging/offending_dashboards.json`
- Adoption manifest: `_build/logging/adopted_dashboards_manifest.json`
- Verifier artifact: `_build/logging/verify_grafana_authority_latest.json`
- Grafana API proof: `/api/dashboards/uid/codeswarm-adopted-*` with `meta.provisioned=true` and `meta.provisionedExternalId=adopted/<file>.json`

### Recent commits (last 15)
cfabc78 (HEAD -> logging-configuration, origin/logging-configuration) grafana: adopt non-managed dashboards into repo provisioning
306d0e2 ops: extend auditability with dimension coverage and deterministic gates
80e8ee3 grafana: add source index and per-source auditability coverage
a781ef8 grafana: clear empty panels and add top errors explorer
2e4ff65 ops: normalize dashboard datasource UIDs and add query audit
ec03325 grafana: fix empty dashboard queries against live Prom/Loki labels
e9ac40c ops: harden E2E check and add deterministic state report
619ccf7 docs: add authoritative logging state changelog
41f4f0f ops: harden Grafana authority (alert posture + verifier v2 + docs consolidation)
fd9f734 ops: make Grafana authoritative for logging (alerts + runbook + verification)
f87ae91 docs: add logging visibility release notes and alert checklist
f0c0570 grafana: add host + container overview dashboard
3e6292e grafana: enhance pipeline health dashboard
0c55887 grafana: add pipeline health dashboard
bf4f744 chore: ignore local archives

### Recent stats (last 10)
commit cfabc7803c645136be881d01ae59502b42858a7f
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 06:52:04 2026 -0600

    grafana: adopt non-managed dashboards into repo provisioning
    
    Adopt blocked/non-managed dashboards into dashboards/adopted, add adoption manifest workflow script, and enforce adoption coverage in verifier artifact.

 .../adopted/codeswarm-adopted-dfdgpdf22b9q8c.json  |  401 +++++
 .../adopted/codeswarm-adopted-dfdgqba65adj4b.json  |  129 ++
 .../adopted/codeswarm-adopted-uddpyzz7z.json       | 1555 ++++++++++++++++++++
 infra/logging/scripts/adopt_dashboards.sh          |   93 ++
 infra/logging/scripts/verify_grafana_authority.sh  |   41 +-
 5 files changed, 2216 insertions(+), 3 deletions(-)

commit 306d0e2c47a10344980215e7bb375058bdf96b0b
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 06:39:15 2026 -0600

    ops: extend auditability with dimension coverage and deterministic gates
    
    Add service_name dimension dashboards, harden verifier/audit expected-empty handling, update runbook/changelog, and remove legacy sprint-3 dashboard tags.

 infra/logging/CHANGELOG_authoritative_logging.md   |  24 ++++
 infra/logging/RUNBOOK.md                           |  15 +++
 infra/logging/grafana/dashboards/alloy-health.json |   3 +-
 .../codeswarm-dim-index-service_name.json          | 122 +++++++++++++++++++
 .../codeswarm-dim-service-name-atlas-sql.json      | 130 +++++++++++++++++++++
 ...codeswarm-dim-service-name-atlas-typesense.json | 130 +++++++++++++++++++++
 .../codeswarm-dim-service-name-codeswarm-mcp.json  | 130 +++++++++++++++++++++
 ...codeswarm-dim-service-name-unknown-service.json | 130 +++++++++++++++++++++
 infra/logging/grafana/dashboards/gpu-overview.json |   1 -
 infra/logging/grafana/dashboards/loki-health.json  |   3 +-
 .../grafana/dashboards/prometheus-health.json      |   3 +-
 infra/logging/scripts/dashboard_query_audit.sh     |   4 +
 infra/logging/scripts/verify_grafana_authority.sh  |  66 ++++++++++-
 13 files changed, 753 insertions(+), 8 deletions(-)

commit 80e8ee3fcd13dd08486b68211b85e4d2199e41c8
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 06:29:49 2026 -0600

    grafana: add source index and per-source auditability coverage
    
    Provision CodeSwarm Source Index and per-log_source dashboards; upgrade verifier and audit script for source-completeness evidence with machine-readable outputs.

 .../grafana/dashboards/codeswarm-source-index.json | 122 +++++++++++++++++++
 .../sources/codeswarm-src-codeswarm_mcp.json       | 129 ++++++++++++++++++++
 .../dashboards/sources/codeswarm-src-docker.json   | 129 ++++++++++++++++++++
 .../sources/codeswarm-src-rsyslog_syslog.json      | 129 ++++++++++++++++++++
 .../sources/codeswarm-src-telemetry.json           | 129 ++++++++++++++++++++
 .../sources/codeswarm-src-vscode_server.json       | 129 ++++++++++++++++++++
 infra/logging/scripts/dashboard_query_audit.sh     |  13 +-
 infra/logging/scripts/verify_grafana_authority.sh  | 135 +++++++++++----------
 8 files changed, 846 insertions(+), 69 deletions(-)

commit a781ef845c25f8964d18516a8ec6e0ee3915110d
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 06:19:07 2026 -0600

    grafana: clear empty panels and add top errors explorer
    
    Fix audit-reported empty panels, add provisioned Top Errors / Log Explorer dashboard, and harden dashboard query audit with provisioned-only scope, var substitution, and retries.

 infra/logging/grafana/dashboards/gpu-overview.json |   6 +-
 .../dashboards/top-errors-log-explorer.json        | 132 +++++++++++++
 infra/logging/scripts/dashboard_query_audit.sh     | 207 ++++++++++++++++-----
 3 files changed, 294 insertions(+), 51 deletions(-)

commit 2e4ff65023438c612677a6269303d863afd71377
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 06:10:46 2026 -0600

    ops: normalize dashboard datasource UIDs and add query audit
    
    Set explicit datasource UIDs across provisioned dashboards, keep Grafana metrics in Prom-health mode, and add dashboard query audit script with md/json outputs.

 infra/logging/grafana/dashboards/alloy-health.json |  10 +-
 .../grafana/dashboards/containers_overview.json    |  14 ++-
 infra/logging/grafana/dashboards/gpu-overview.json |  18 ++-
 .../grafana/dashboards/grafana-metrics.json        |  25 ++++-
 .../dashboards/host-container-overview.json        |  38 +++++--
 .../logging/grafana/dashboards/host_overview.json  |  20 +++-
 infra/logging/grafana/dashboards/loki-health.json  |  10 +-
 .../grafana/dashboards/pipeline-health.json        |  38 +++++--
 .../grafana/dashboards/prometheus-health.json      |  26 +++--
 .../grafana/dashboards/zprometheus-stats.json      |  26 ++++-
 infra/logging/scripts/dashboard_query_audit.sh     | 125 +++++++++++++++++++++
 11 files changed, 300 insertions(+), 50 deletions(-)

commit ec0332584be2215ccf54b096ef11f98466305baf
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 06:02:12 2026 -0600

    grafana: fix empty dashboard queries against live Prom/Loki labels
    
    Patch provisioned dashboards to use metrics/labels that exist in this stack and add provisioned JSON for legacy Grafana metrics and zPrometheus Stats UIDs.

 infra/logging/grafana/dashboards/alloy-health.json |   4 +-
 .../grafana/dashboards/containers_overview.json    |   4 +-
 .../grafana/dashboards/grafana-metrics.json        |  84 +++++++++++++++++
 .../grafana/dashboards/prometheus-health.json      |   4 +-
 .../grafana/dashboards/zprometheus-stats.json      | 105 +++++++++++++++++++++
 5 files changed, 195 insertions(+), 6 deletions(-)

commit e9ac40c9dd3593dfaf0eea6d88ded25e42ce3ee3
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 05:50:05 2026 -0600

    ops: harden E2E check and add deterministic state report
    
    Add retry-based e2e_check_hardened.sh and state_report.sh (md+json) with fail-closed unknown handling.

 infra/logging/scripts/e2e_check_hardened.sh |  47 +++++++++++++
 infra/logging/scripts/state_report.sh       | 102 ++++++++++++++++++++++++++++
 2 files changed, 149 insertions(+)

commit 619ccf796049888612766f7038fc9290fe128efb
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 05:43:13 2026 -0600

    docs: add authoritative logging state changelog
    
    Capture Grafana-as-authority investigation evidence, verifier artifact pointer, and current blockers.

 infra/logging/CHANGELOG_authoritative_logging.md | 162 +++++++++++++++++++++++
 1 file changed, 162 insertions(+)

commit 41f4f0f959f29fe7199e606d18c00b2020b843ff
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 05:19:17 2026 -0600

    ops: harden Grafana authority (alert posture + verifier v2 + docs consolidation)
    
    Harden alert posture, upgrade verifier to v2 with JSON artifact, and consolidate alert docs canonically.

 infra/logging/ALERTS_CHECKLIST.md                 |  3 +
 infra/logging/RUNBOOK.md                          |  9 ++-
 infra/logging/scripts/verify_grafana_authority.sh | 79 +++++++++++++++++++----
 3 files changed, 77 insertions(+), 14 deletions(-)

commit fd9f734fe536edd50851cb2ea45462cf6d0e5a38
Author: Bryan Luce <luce@appmelia.com>
Date:   Tue Feb 17 04:58:11 2026 -0600

    ops: make Grafana authoritative for logging (alerts + runbook + verification)
    
    Provision best-effort Grafana alert rules, add operator runbook, and add a one-shot verification script.

 infra/logging/RUNBOOK.md                           | 41 ++++++++++++
 .../alerting/logging-pipeline-rules.yml            | 73 ++++++++++++++++++++++
 infra/logging/scripts/verify_grafana_authority.sh  | 30 +++++++++
 3 files changed, 144 insertions(+)

