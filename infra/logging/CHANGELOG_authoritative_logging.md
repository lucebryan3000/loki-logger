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
