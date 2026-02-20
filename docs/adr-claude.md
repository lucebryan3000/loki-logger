# ADR — Claude Accountability Checklist

**Owner**: Claude (orchestrator + executor)
**Date**: 2026-02-19 (updated 2026-02-19 Pass 16)
**Scope**: Documentation accuracy, dependency/version health, environment/secrets hygiene, quality/test coverage, operational script correctness, resilience validation (Cat 13), correction audit (Cat 17), testing suite (Cat 16).
**Codex handles**: Container orchestration, Loki config, Alloy pipelines, Prometheus, Grafana, Compose hardening.

New ADR numbers start at ADR-160. Do not reuse existing numbers.

---

## How to Read This File

- `[ ]` = not started
- `[~]` = in progress
- `[x]` = done — change applied and verified
- `[!]` = blocked or needs decision
- Each item shows: ADR reference → exact file/line → exact action → verification command

---

## Category 12 — Documentation Accuracy

| Status | ADR | File | Action |
|--------|-----|------|--------|
| `[x]` | ADR-012 | `CLAUDE.md` | Remove `host=codeswarm` label claim; remove `job` label claim — fixed label schema |
| `[x]` | ADR-019 | `docs/snippets/` | Deleted `alloy-config.alloy`, `loki-config.yml`, `prometheus.yml` + directory |
| `[x]` | ADR-063 | `CLAUDE.md:111` | Fixed Loki "internal only" claim — updated to reflect 127.0.0.1:3200 access |
| `[x]` | ADR-063 | `docs/troubleshooting.md:494` | Fixed section 6: Loki accessible at 127.0.0.1:3200 from host; obs network uses loki:3100 |
| `[x]` | ADR-099 | `docs/reference.md:125` | Changed alloy-positions container path from `/tmp` → `/var/lib/alloy` |
| `[x]` | ADR-100 | `docs/reference.md:162` | Removed `container_name` label row; replaced with `service`; fixed LogQL examples |
| `[x]` | ADR-101 | `docs/reference.md:80` | Changed "8 active" → "8 configured (5 delivering, 3 not delivering)" |
| `[x]` | ADR-103 | `docs/manifest.json` | Regenerated from actual `docs/` file list (no 10-/20- prefix files) |
| `[x]` | ADR-104 | `docs/quality-checklist.md:85` | Marked Prometheus loopback-only box as `[x]` |
| `[x]` | ADR-110 | `CLAUDE.md` | Added wireguard scrape job note |
| `[x]` | ADR-121 | `docs/quality-checklist.md:85` | Same as ADR-104 — Prometheus box checked |
| `[x]` | ADR-125 | `CLAUDE.md` | Fixed label schema: removed `host`, `job`; added `mcp_level`, `service_name`, `source_type`, `stack` |
| `[x]` | ADR-128 | `CLAUDE.md:17` | Fixed comment: `# Stop stack (removes volumes)` → `# Stop stack (volumes preserved; use --purge to destroy data)` |

---

## Category 10 — Dependency & Version Health

| Status | ADR | File | Action |
|--------|-----|------|--------|
| `[x]` | ADR-010 | `.env.example` | Grafana 11.1.0 → 11.5.x flagged and upgraded |
| `[x]` | ADR-113 | `.env.example`, `.env` | Upgraded Grafana image: `grafana/grafana:11.1.0` → `grafana/grafana:11.5.2` |

### Version Upgrade Decision Table

| Component | Current | Target | Method |
|-----------|---------|--------|--------|
| Grafana | 11.1.0 | 11.5.2 | Update `GRAFANA_IMAGE` in `.env` + `.env.example`; `docker compose up -d grafana` ✅ |
| Loki | 3.0.0 | 3.3.x | Defer — requires schema migration validation |
| Alloy | v1.2.1 | v1.6.x | Defer — verify HCL API compatibility |
| Prometheus | v2.52.0 | v2.53.x | Defer — v3.x has breaking changes |
| Node Exporter | v1.8.1 | v1.8.2 | Low risk, update `.env.example` |
| cAdvisor | v0.49.1 | v0.49.2 | Low risk; note registry change to `ghcr.io` at v0.53+ |

**Scope for this checklist**: Only Grafana update (highest severity, lowest risk). Others deferred.

---

## Category 15 — Environment & Secrets

| Status | ADR | File | Action |
|--------|-----|------|--------|
| `[x]` | ADR-040 | `.env.example` | Added dual GF_*/GRAFANA_* var semantics explanation in comment block |
| `[!]` | ADR-072 | `docker-compose.observability.yml` | Switch from `env_file: .env` (all vars) to explicit `environment:` block for Grafana — deferred (high blast radius) |
| `[x]` | ADR-072 | `.env.example` | Removed orphaned `TELEMETRY_INTERVAL_SEC` — not referenced anywhere |
| `[!]` | ADR-109 | `.env.example` | PASS — no action needed (key parity confirmed) |

### ADR-072 Compose env_file scope note

Current: `env_file: .env` injects all 34 vars into Grafana including `HOST_DOCKER_SOCK`, `HOST_ROOTFS`, etc.
Fix: Replace with an explicit `environment:` block listing only the vars Grafana needs.
**Deferred**: High blast radius — requires reading current compose to enumerate which `GF_*`/`GRAFANA_*` vars are actually consumed. Risk of breaking Grafana provisioning if any vars are missed.

---

## Category 16 — Quality & Test Coverage

| Status | ADR | File | Action |
|--------|-----|------|--------|
| `[x]` | ADR-022 | `docs/quality-checklist.md` | Replaced hardcoded version pins (lines 35-38) with dynamic `.env.example` references |
| `[x]` | ADR-023 | `QUICK-ACCESS.md` | Removed all `192.168.1.150` instances; replaced with `<HOST_IP>` + subnet generalized |
| `[x]` | ADR-024 | repo root | Added `Makefile` with `make lint` target running shellcheck on 34 scripts |
| `[x]` | ADR-031 | `src/log-truncation/scripts/status.sh:40` | Fixed SC2168: removed `local` keyword outside function |
| `[x]` | ADR-044 | `scripts/prod/mcp/logging_stack_audit.sh` | Added `set -o noclobber` (BB098) + `shopt -s inherit_errexit` (BB100); changed 7 mktemp redirects from `>` to `>|` |

---

## Category 8 — Operational Scripts & Lifecycle

| Status | ADR | File | Action |
|--------|-----|------|--------|
| `[x]` | ADR-007 §4 | `scripts/prod/mcp/logging_stack_health.sh` | Already uses `grep` — pre-fixed, no action needed |
| `[x]` | ADR-007 §5 | `scripts/prod/mcp/logging_stack_health.sh` | Already uses `${GRAFANA_PORT:-9001}`/`${PROM_PORT:-9004}` — pre-fixed |
| `[x]` | ADR-007 §6 | `scripts/prod/mcp/logging_stack_audit.sh` | Expanded `trap` to include all 7 leaked temp file variables |
| `[x]` | ADR-090 | `infra/logging/scripts/` | Copied `backup_volumes.sh` + `restore_volumes.sh` → `scripts/prod/mcp/`; added to CLAUDE.md |
| `[x]` | ADR-117 | `infra/logging/scripts/backup_volumes.sh` | Fixed volume names: `logging-` → `logging_` prefix |
| `[x]` | ADR-117 | `infra/logging/scripts/restore_volumes.sh` | Same volume name fix |
| `[x]` | ADR-119 | `infra/logging/RUNBOOK.md` | Expanded WAL section: Loki recovery steps, Prometheus WAL corruption recovery, disk exhaustion |
| `[!]` | ADR-021 | `scripts/prod/mcp/` | `add-log-source.sh` does not exist at `scripts/prod/mcp/` or anywhere in repo — ADR-021 is N/A |

---

## Work Log

| Timestamp | Agent | Action | Result |
|-----------|-------|--------|--------|
| 2026-02-19 | claude | Created this checklist | — |
| 2026-02-19 | agent-af898ff | CLAUDE.md fixes: ADR-128, ADR-125, ADR-110, label schema | ✅ done (killed after completion) |
| 2026-02-19 | agent-ab945dc | Script fixes: ADR-007§6, ADR-090, ADR-117×2, ADR-031 | ✅ done (killed after completion) |
| 2026-02-19 | agent-aade2d3 | .env.example Grafana version upgrade | ✅ partial (.env.example done; claude completed .env) |
| 2026-02-19 | claude | Deleted docs/snippets/ dir (ADR-019) | ✅ done |
| 2026-02-19 | claude | Regenerated docs/manifest.json (ADR-103) | ✅ done |
| 2026-02-19 | claude | Fixed docs/reference.md: ADR-099, ADR-100, ADR-101 | ✅ done |
| 2026-02-19 | claude | Fixed docs/quality-checklist.md: ADR-104/ADR-121 | ✅ done |
| 2026-02-19 | claude | Removed orphaned TELEMETRY_INTERVAL_SEC from .env.example | ✅ done |
| 2026-02-19 | claude | Updated .env Grafana to 11.5.2 (ADR-113) | ✅ done |
| 2026-02-19 | claude | Fixed CLAUDE.md ADR-063 (Loki port claim), ADR-019 (snippets ref) | ✅ done |
| 2026-02-19 | claude | Fixed QUICK-ACCESS.md: removed all 192.168.1.150 IPs (ADR-023) | ✅ done |
| 2026-02-19 | claude | Fixed docs/quality-checklist.md: version pins → .env.example refs (ADR-022) | ✅ done |
| 2026-02-19 | claude | Fixed docs/troubleshooting.md: Loki port 3100 claim (ADR-063) | ✅ done |
| 2026-02-19 | claude | Expanded RUNBOOK.md WAL section (ADR-119) | ✅ done |
| 2026-02-19 | claude | Added .env.example GF_*/GRAFANA_* semantics comment (ADR-040) | ✅ done |
| 2026-02-19 | claude | Added CLAUDE.md backup/restore scripts (ADR-090) | ✅ done |
| 2026-02-19 | claude | Added logging_stack_audit.sh noclobber + inherit_errexit (ADR-044) | ✅ done |
| 2026-02-19 | claude | Created Makefile with make lint (ADR-024); found pre-existing SC warnings (see ADR-160) | ✅ done |
| 2026-02-19 | agent-afba06f | Cat 13 Resilience validation: ADR-013, ADR-048, ADR-059, ADR-073, ADR-107 | ✅ done |
| 2026-02-19 | agent-ae0fc96 | Cat 17 Corrections audit: CORRECTION-001–013 verified against file state | ✅ done |
| 2026-02-19 | agent-a4aceb8 | Cat 16 Testing suite: scripts/prod/mcp/test_suite.sh created; 42 tests | ✅ done |
| 2026-02-19 | claude | Fixed 13 shellcheck warnings across 8 scripts; make lint clean (35 scripts) | ✅ done |
| 2026-02-19 | claude | Appended Cat 13/16/17 verdicts to adr-completed.md | ✅ done |

---

## Category 13 — Resilience & Failure Modes

| Status | ADR | Finding | Verdict |
|--------|-----|---------|---------|
| `[x]` | ADR-013 | No backup strategy, disk-full undefined, WAL undefined, no graceful shutdown | COMPLETED — backup scripts exist with correct volume names; RUNBOOK.md has all 3 sections |
| `[x]` | ADR-048 | Container restart history | PASS — already in adr-completed.md; RestartCount=0 all containers |
| `[x]` | ADR-059 | Loki WAL & ingester state | PASS — already in adr-completed.md; WAL healthy, 208 duplicates negligible |
| `[x]` | ADR-073 | Alloy → Loki transient DNS errors | PASS — already in adr-completed.md; self-resolved |
| `[x]` | ADR-107 | Docker volume disk usage | COMPLETED — NodeDiskSpaceLow + LokiVolumeUsageHigh alerts confirmed; informational findings |

---

## Category 17 — Accuracy Corrections (Pass 14)

| Status | # | Verdict |
|--------|---|---------|
| `[x]` | CORRECTION-001 | STILL_OPEN — ports remain `0.0.0.0`; correction's "RESOLVED" claim was wrong; retained in adr.md |
| `[x]` | CORRECTION-002 | CONFIRMED_FIXED — moved to adr-completed.md |
| `[x]` | CORRECTION-003 | CONFIRMED_FIXED — moved to adr-completed.md |
| `[x]` | CORRECTION-004 | CONFIRMED_FIXED — moved to adr-completed.md |
| `[x]` | CORRECTION-005 | CONFIRMED_FIXED — moved to adr-completed.md |
| `[x]` | CORRECTION-006 | CONFIRMED_FIXED — moved to adr-completed.md |
| `[x]` | CORRECTION-007 | CONFIRMED_FIXED — moved to adr-completed.md |
| `[x]` | CORRECTION-008 | CONFIRMED_FIXED — moved to adr-completed.md |
| `[x]` | CORRECTION-009 | STILL_OPEN — `or vector(0)` fix not applied; retained in adr.md |
| `[x]` | CORRECTION-010 | CONFIRMED_FIXED — moved to adr-completed.md |
| `[x]` | CORRECTION-011 | STILL_OPEN — reference.md resource limits text unchanged; retained in adr.md |
| `[x]` | CORRECTION-012 | WAS_DOCUMENTATION_ONLY — DC-1 "RESOLVED" claim disputed; retained |
| `[x]` | CORRECTION-013 | WAS_DOCUMENTATION_ONLY — internal housekeeping; moved to adr-completed.md |

All 13 corrections audited. 8 confirmed fixed and moved to adr-completed.md. 3 remain open in adr.md.

---

## Category 16 — Quality & Test Coverage (Pass 16 additions)

| Status | ADR | File | Action |
|--------|-----|------|--------|
| `[x]` | ADR-022 | `docs/quality-checklist.md` | Replaced hardcoded version pins with dynamic `.env.example` references |
| `[x]` | ADR-023 | `QUICK-ACCESS.md` | Removed all `192.168.1.150` instances |
| `[x]` | ADR-024 | repo root | `Makefile` with `make lint` — 35 scripts, all clean |
| `[x]` | ADR-031 | `src/log-truncation/scripts/status.sh:40` | Fixed SC2168 |
| `[x]` | ADR-044 | `scripts/prod/mcp/logging_stack_audit.sh` | noclobber + inherit_errexit + >| redirects |
| `[x]` | ADR-160 | 8 scripts across repo | Fixed all SC warnings (SC1090, SC2034, SC2024, SC2155) — `make lint` clean |
| `[x]` | NEW | `scripts/prod/mcp/test_suite.sh` | Created 42-test suite: static config, shellcheck lint, runtime health |

---

## New ADR Records Found During This Work

> New items discovered during implementation are appended here.

### ADR-160 — Pre-existing shellcheck warnings across repo scripts

**Found during**: ADR-024 Makefile (`make lint` first run)
**Status**: `[x]` FIXED this session — all 13 warnings resolved across 8 scripts. `make lint` now passes clean (35 scripts).
