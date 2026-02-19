# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker Compose-based observability stack (Grafana + Loki + Prometheus + Alloy + Node Exporter + cAdvisor) running on a headless Ubuntu host. Centralizes logging from Docker containers, systemd journal, and file-based sources with metrics collection and Grafana dashboards.

Single-node deployment. Not a library or application — it's infrastructure configuration with operational scripts.

## Stack Commands

```bash
# Deploy stack (validates .env, then docker compose up -d)
./scripts/prod/mcp/logging_stack_up.sh

# Stop stack (volumes preserved; use --purge to destroy data)
./scripts/prod/mcp/logging_stack_down.sh

# Health check (curls Grafana + Prometheus endpoints)
./scripts/prod/mcp/logging_stack_health.sh

# Detailed audit of all services
./scripts/prod/mcp/logging_stack_audit.sh

# Generate cryptographic evidence archive (no secrets)
./scripts/prod/prism/evidence.sh

# Validate .env has required variables
./scripts/prod/mcp/validate_env.sh .env

# Backup Grafana, Loki, Prometheus volumes to tar archives
./scripts/prod/mcp/backup_volumes.sh

# Restore volumes from tar archives (stack must be stopped)
./scripts/prod/mcp/restore_volumes.sh
```

All compose commands require the file flag: `docker compose -p logging -f infra/logging/docker compose.observability.yml ...`

The compose project name is `logging` (set via `COMPOSE_PROJECT_NAME` in `.env`). Container names follow the pattern `logging-<service>-1`.

## Log Rotation

Managed by [src/log-truncation/](src/log-truncation/) module (replaced codeswarm-tidyup 2026-02-14).

**Quick Commands:**
```bash
# Check disk usage and rotation status
./src/log-truncation/scripts/status.sh

# Rebuild configs after editing retention.conf
./src/log-truncation/scripts/build-configs.sh
sudo ./src/log-truncation/scripts/install.sh

# Validate configuration
./src/log-truncation/scripts/validate.sh

# Test rotation (force rotate)
sudo ./src/log-truncation/scripts/test-rotation.sh
```

**Config:** [src/log-truncation/config/retention.conf](src/log-truncation/config/retention.conf)
**Docs:** [src/log-truncation/docs/design.md](src/log-truncation/docs/design.md), [src/log-truncation/docs/troubleshooting.md](src/log-truncation/docs/troubleshooting.md)

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
| Loki | loki | 127.0.0.1:3200 | 3100 |
| Alloy | alloy | None | 12345 |
| Node Exporter | host-monitor | None | 9100 |
| cAdvisor | docker-metrics | None | 8080 |

### Resource limits (compose)

| Service | `mem_limit` | `cpus` |
|---------|-------------|--------|
| grafana | `1g` | `0.50` |
| loki | `2g` | `1.00` |
| prometheus | `2g` | `1.00` |
| alloy | `1g` | `0.75` |
| host-monitor | `1g` | `1.00` |
| docker-metrics | `2g` | `2.00` |

**Volumes:** `grafana-data`, `prometheus-data`, `loki-data`

**Additional scrape target:** Prometheus also scrapes a `wireguard` exporter at `172.20.0.1:9586` (Docker bridge gateway — host-side exporter, not a stack service).

**Retention:** Loki 720h (30 days) in `loki-config.yml`. Prometheus 15d via CLI flag `--storage.tsdb.retention.time` in compose file (cannot be set in `prometheus.yml`).

## Key Configuration Files

| File | Format | Purpose |
|------|--------|---------|
| `infra/logging/docker compose -p logging.observability.yml` | YAML with env var substitution | Service definitions |
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

Port bindings are set to `0.0.0.0` (all interfaces) for LAN access on headless host. Set `GRAFANA_HOST=127.0.0.1` and `PROM_HOST=127.0.0.1` for loopback-only access. UFW provides access control.

Image versions are pinned via env vars (e.g., `GRAFANA_IMAGE=grafana/grafana:11.5.2`).

## Common Gotchas

1. **Alloy config is HCL, not YAML** — uses `//` for comments, `#` causes parse errors
2. **Loki requires non-empty label selectors** — `{env=~".+"}` works, `{}` is rejected
3. **Prometheus retention is CLI-only** — set via `--storage.tsdb.retention.time` flag in compose, NOT in `prometheus.yml`
4. **Loki port exposure** — Loki is not exposed externally; access from the host loopback is at 127.0.0.1:3200 (mapped from internal port 3100).
5. **Log ingestion delay is normal** — 10-15 seconds between file write and Loki availability
6. **Config changes require restart** — `docker compose -p logging -f infra/logging/docker compose.observability.yml restart <service>`

## Log Sources (Alloy Pipelines)

13 active log sources. Alloy mounts `/home/luce` at `/host/home` and `/var/log` at `/host/var/log`.

- `rsyslog_syslog` — TCP syslog relay from rsyslog on port 1514; adds `syslog_channel` and `security_domain` labels
- `docker` — Docker socket container logs; filtered to vllm and hex compose projects
- `journald` — systemd journal via `loki.source.journal`
- `tool_sink` — `/home/luce/_logs/*.log`
- `telemetry` — `/home/luce/_telemetry/*.jsonl`
- `gpu_telemetry` — `/home/luce/_telemetry/gpu/gpu-live.csv` and `gpu-proc.csv`; `source_type=gpu_csv`
- `nvidia_telem` — `/home/luce/apps/vLLM/logs/telemetry/nvidia/*.jsonl`; `source_type=file`, `telemetry_tier=raw30`
- `codeswarm_mcp` — `/home/luce/apps/vLLM/_data/mcp-logs/*.log`; adds `mcp_level`, `service_name`
- `vscode_server` — `/home/luce/.vscode-server/**/*.log`
- `codex_tui` — `/home/luce/.codex/log/codex-tui.log`
- `host_wireguard` — `/var/log/wireguard-client-manager.log`; `source_type=file`
- `host_codeswarm` — `/var/log/codeswarm.log`; `source_type=file`
- `host_apt` — `/var/log/apt/history.log`; `source_type=file`

All logs get `env=sandbox`. Source-specific pipelines add `log_source`/`source_type` and further labels where applicable.

## Label Schema

Every log entry has: `env`. Docker logs add `stack`, `service`, `source_type`, and `log_source`. File/syslog pipelines add `log_source` plus `filename`/`source_type` depending on source. MCP logs also carry `mcp_level` and `service_name`. rsyslog_syslog logs add `syslog_channel` (general|ufw|auth|kernel|cron|other) and `security_domain` (firewall|auth) on matching lines. NVIDIA telemetry adds `telemetry_tier=raw30`. GPU telemetry uses `source_type=gpu_csv`.

## Directory Layout

- `infra/logging/` — All stack configuration (compose, configs, provisioning, dashboards)
- `scripts/prod/mcp/` — Stack lifecycle scripts (up, down, health, audit, validate)
- `scripts/prod/prism/` — Evidence/proof generation
- `docs/` — Comprehensive documentation (overview, architecture, operations, troubleshooting, etc.)
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

# Loki (host loopback at 3200, or from inside obs network)
curl -sf http://127.0.0.1:3200/ready
```

## Documentation

`docs/INDEX.md` is the master table of contents. Key docs:
- `docs/operations.md` — runbooks, LogQL/PromQL query examples, evidence generation
- `docs/troubleshooting.md` — symptom-based diagnostic (symptom → cause → fix)
- `docs/reference.md` — ports, env vars, file paths, API endpoints, label schema
- `docs/maintenance.md` — retention, backups, upgrades, disk management
- `docs/security.md` — exposure posture, secrets handling, firewall
