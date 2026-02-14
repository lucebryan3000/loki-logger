# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker Compose-based observability stack (Grafana + Loki + Prometheus + Alloy + Node Exporter + cAdvisor) running on a headless Ubuntu host. Centralizes logging from Docker containers, systemd journal, and file-based sources with metrics collection and Grafana dashboards.

Single-node deployment. Not a library or application — it's infrastructure configuration with operational scripts.

## Stack Commands

```bash
# Deploy stack (validates .env, then docker compose up -d)
./scripts/prod/mcp/logging_stack_up.sh

# Stop stack (removes volumes)
./scripts/prod/mcp/logging_stack_down.sh

# Health check (curls Grafana + Prometheus endpoints)
./scripts/prod/mcp/logging_stack_health.sh

# Detailed audit of all services
./scripts/prod/mcp/logging_stack_audit.sh

# Generate cryptographic evidence archive (no secrets)
./scripts/prod/prism/evidence.sh

# Validate .env has required variables
./scripts/prod/mcp/validate_env.sh .env
```

All compose commands require the file flag: `docker compose -f infra/logging/docker-compose.observability.yml ...`

The compose project name is `infra_observability` (set via `COMPOSE_PROJECT_NAME` in `.env` or defaulted in compose file). Container names follow the pattern `infra_observability-<service>-1`.

## Architecture

```
Log Sources → Alloy (ingestion) → Loki (storage) → Grafana (query/visualize)
Metrics Sources → Prometheus (scrape/store) → Grafana (query/visualize)
```

**6 services** on Docker network `obs` (bridge):

| Service | Compose name | External port | Internal port |
|---------|-------------|---------------|---------------|
| Grafana | grafana | 9001 (configurable) | 3000 |
| Prometheus | prometheus | 9004 (configurable) | 9090 |
| Loki | loki | None (internal only) | 3100 |
| Alloy | alloy | None | 12345 |
| Node Exporter | host-monitor | None | 9100 |
| cAdvisor | docker-metrics | None | 8080 |

**Volumes:** `grafana-data`, `prometheus-data`, `loki-data`

**Retention:** Loki 720h (30 days) in `loki-config.yml`. Prometheus 15d via CLI flag `--storage.tsdb.retention.time` in compose file (cannot be set in `prometheus.yml`).

## Key Configuration Files

| File | Format | Purpose |
|------|--------|---------|
| `infra/logging/docker-compose.observability.yml` | YAML with env var substitution | Service definitions |
| `infra/logging/loki-config.yml` | YAML | Loki schema, retention, compaction |
| `infra/logging/alloy-config.alloy` | **HCL** (uses `//` comments, NOT `#`) | Log ingestion pipelines |
| `infra/logging/prometheus/prometheus.yml` | YAML | Scrape targets |
| `infra/logging/prometheus/rules/loki_logging_rules.yml` | YAML | Alert rules |
| `infra/logging/grafana/provisioning/` | YAML | Auto-provisioned data sources + dashboards |
| `.env` | Bash env | Secrets + runtime config (mode 600, gitignored) |

All config files are mounted read-only (`:ro`) in containers. Changes require container restart.

## Environment Variables

Secrets live in `.env` at repo root (symlink to `infra/logging/.env`). Template at `.env.example`.

Required: `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD` (min 8 chars), `GRAFANA_SECRET_KEY` (32+ random chars).

Port bindings default to `127.0.0.1` (loopback). Set `GRAFANA_HOST=0.0.0.0` and `PROM_HOST=0.0.0.0` for LAN access on headless host.

Image versions are pinned via env vars (e.g., `GRAFANA_IMAGE=grafana/grafana:11.1.0`).

## Common Gotchas

1. **Alloy config is HCL, not YAML** — uses `//` for comments, `#` causes parse errors
2. **Loki requires non-empty label selectors** — `{env=~".+"}` works, `{}` is rejected
3. **Prometheus retention is CLI-only** — set via `--storage.tsdb.retention.time` flag in compose, NOT in `prometheus.yml`
4. **Loki is internal-only** — no `http://127.0.0.1:3100` access; query through Grafana or from inside the `obs` network
5. **Log ingestion delay is normal** — 10-15 seconds between file write and Loki availability
6. **Config changes require restart** — `docker compose -f infra/logging/docker-compose.observability.yml restart <service>`

## Log Sources (Alloy Pipelines)

Alloy ingests from these host paths (mounted under `/host/`):
- `/home/luce/_logs/*.log` — general application logs
- `/home/luce/_telemetry/*.jsonl` — structured telemetry
- `/home/luce/apps/vLLM/_data/mcp-logs/*.log` — CodeSwarm MCP logs (labeled `log_source=codeswarm_mcp`)
- Docker socket — container logs (labeled with `container_name`)
- Systemd journal

All logs get `env=sandbox` and `host=codeswarm` labels.

## Label Schema

Every log entry has: `env`, `host`, `job`. Docker logs add `container_name`. File logs add `filename`. MCP logs add `log_source=codeswarm_mcp`.

## Directory Layout

- `infra/logging/` — All stack configuration (compose, configs, provisioning, dashboards)
- `scripts/prod/mcp/` — Stack lifecycle scripts (up, down, health, audit, validate)
- `scripts/prod/prism/` — Evidence/proof generation
- `docs/` — Comprehensive documentation (overview, architecture, operations, troubleshooting, etc.)
- `docs/snippets/` — Canonical config excerpts synced from `infra/logging/`
- `_build/` — Sprint specs and bootstrap system (gitignored except READMEs, excluded from Claude context via `.claudeignore`)
- `temp/` — Runtime artifacts, evidence archives (gitignored)

## _build/Logging-Bootstrap

Config-driven bootstrap system under `_build/Logging-Bootstrap/` with Jinja2 templates, JSON config schemas, and an orchestrator for automated deployment cycles. Entry point: `bootstrap.sh`. This is a parallel system to the manual `scripts/prod/` workflow — it generates configs from templates and runs apply/verify/heal cycles.

Key scripts: `bootstrap.sh`, `orchestrate.sh`, `bin/bootstrap_run.sh`, `bin/bootstrap_apply.sh`, `bin/clean_slate.sh`, `bin/bootstrap_verify.py`, `bin/test_loop.sh`, `bin/verify_idempotency.sh`, `bin/recall.sh`.

Config resolution uses `bin/lib/config_query.py` — all shell scripts resolve paths through this utility rather than inline Python.

## Health Check Endpoints

```bash
# Grafana
curl -sf http://127.0.0.1:9001/api/health

# Prometheus
curl -sf http://127.0.0.1:9004/-/ready

# Loki (from inside obs network only)
docker run --rm --network obs curlimages/curl:8.6.0 -sf http://loki:3100/ready
```

## Documentation

`docs/INDEX.md` is the master table of contents. Key docs:
- `docs/operations.md` — runbooks, LogQL/PromQL query examples, evidence generation
- `docs/troubleshooting.md` — symptom-based diagnostic (symptom → cause → fix)
- `docs/reference.md` — ports, env vars, file paths, API endpoints, label schema
- `docs/maintenance.md` — retention, backups, upgrades, disk management
- `docs/security.md` — exposure posture, secrets handling, firewall
