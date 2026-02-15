# Overview

## Purpose

This repository provides a **production-grade Loki logging stack** for local development and observability. It ingests logs from Docker containers, file-based sources, and custom telemetry streams, making them queryable through Grafana with full label-based filtering.

**Core capabilities:**
- Centralized log aggregation from multiple sources
- Metrics collection and alerting via Prometheus
- Unified dashboards and query interface via Grafana
- Retention management (30 days default for logs, 15 days for metrics)
- Evidence capture for audit and compliance workflows

## Authoritative Source Of Truth

Use these files/scripts as the authoritative contract for current behavior:

- `infra/logging/docker-compose.observability.yml`
- `infra/logging/alloy-config.alloy`
- `infra/logging/prometheus/rules/loki_logging_rules.yml`
- `infra/logging/prometheus/rules/sprint3_minimum_alerts.yml`
- `infra/logging/grafana/dashboards/*.json`
- `scripts/prod/mcp/logging_stack_health.sh`
- `scripts/prod/mcp/logging_stack_audit.sh`
- `docs/query-contract.md`
- `_build/Sprint-3/reference/uat_outcome_report.json`

## Stack Components

| Service | Image | Purpose | Exposure |
|---------|-------|---------|----------|
| **Grafana** | grafana/grafana:11.1.0 | Visualization, dashboards, query interface | 0.0.0.0:9001 |
| **Loki** | grafana/loki:3.0.0 | Log aggregation and storage | Internal only (http://loki:3100) |
| **Prometheus** | prom/prometheus:v2.52.0 | Metrics collection and alerting | 0.0.0.0:9004 |
| **Alloy** | grafana/alloy:v1.2.1 | Log ingestion agent (replaces Promtail) | Internal only |
| **Node Exporter** | prom/node-exporter:v1.8.1 | Host metrics | Internal only |
| **cAdvisor** | gcr.io/cadvisor/cadvisor:v0.49.1 | Container metrics | Internal only |

## Log Sources

Alloy ingests logs from:
- **Docker containers** (via `/var/run/docker.sock`)
- **Systemd journal** (`/run/log/journal`, `/var/log/journal`)
- **File-based logs:**
  - `/home/luce/_logs/*.log` (general application logs)
  - `/home/luce/_telemetry/*.jsonl` (structured telemetry)
  - `/home/luce/apps/vLLM/_data/mcp-logs/*.log` (CodeSwarm MCP logs)

## Label Contract

All logs ingested into Loki carry standardized labels for filtering:

- `env` — Environment identifier (e.g., `dev`, `staging`, `prod`)
- `host` — Source hostname
- `log_source` — Source type (e.g., `docker`, `codeswarm_mcp`, `journal`)
- `container_name` — Docker container name (when applicable)
- `job` — Prometheus scrape job name
- `filename` — Source file path (for file-based logs)

**Critical:** Loki queries require **non-empty label selectors**. Avoid `{}` or queries will fail. Use `{env=~".+"}` for broad queries.

## Network Topology

All services run on a dedicated Docker bridge network: **`obs`**

**External access (all interfaces, UFW-protected):**
- Grafana: http://127.0.0.1:9001 (login required)
- Prometheus: http://127.0.0.1:9004 (no auth)
- Bound to `0.0.0.0` for LAN access on headless host

**Internal-only services:**
- Loki: http://loki:3100 (accessible only from `obs` network)
- Alloy, Node Exporter, cAdvisor: no exposed ports

## Compose Project

- **Name:** `logging`
- **Location:** `infra/logging/docker-compose.observability.yml`
- **Secrets:** `.env` (mode 600, never committed)
- **Control scripts:** `scripts/prod/mcp/logging_stack_{up,down,health,audit}.sh`
- **Query contract:** `docs/query-contract.md`

## Scope and Guardrails

**In scope:**
- Log aggregation and querying
- Metrics collection and alerting
- Evidence generation for audit trails
- Local development observability

**Out of scope:**
- Production-scale high availability (single-node deployment)
- External authentication beyond Grafana login (UFW + LAN access by design)
- Long-term archival (30-day retention limit)
- Distributed tracing (use Jaeger/Tempo separately if needed)

**Design constraints:**
- Prometheus/Loki config changes require container restart; Alloy supports `SIGHUP` reload
- Loki is **internal-only** for security (no direct external access)
- Secrets are **never logged or printed** in evidence/docs
- Prometheus retention is **enforced at runtime** via CLI flags (cannot be changed in prometheus.yml)

## Evidence and Proof System

The stack includes scripts to generate **cryptographically verifiable evidence** of operation:

- **Location:** `scripts/prod/prism/evidence.sh`
- **Output:** `temp/evidence/` (timestamped directories)
- **Purpose:** Prove ingestion, query capability, and label compliance for audit

See [operations.md](operations.md#evidence-generation) for usage.

## Quick Start

```bash
# Deploy stack
scripts/prod/mcp/logging_stack_up.sh

# Verify health
scripts/prod/mcp/logging_stack_health.sh

# Run deep audit
scripts/prod/mcp/logging_stack_audit.sh _build/Sprint-3/reference/native_audit.json

# Access Grafana
open http://127.0.0.1:9001
# Login with credentials from .env

# Access Prometheus
open http://127.0.0.1:9004

# Query logs in Grafana Explore
# Example: {env=~".+"} |= "error"
```

For detailed deployment procedures, see [deployment.md](deployment.md).

## Documentation Structure

- [architecture.md](architecture.md) — Component diagram, data flow, networks
- [deployment.md](deployment.md) — Deploy, redeploy, upgrade procedures
- [operations.md](operations.md) — Common tasks, runbooks, health checks
- [validation.md](validation.md) — Strict validation proofs
- [troubleshooting.md](troubleshooting.md) — Symptom → cause → fix
- [security.md](security.md) — Exposure posture, secrets handling
- [maintenance.md](maintenance.md) — Retention, upgrades, backups
- [reference.md](reference.md) — Ports, labels, paths, env vars

## Common Gotchas

1. **Empty Loki selectors fail:** Always include at least one label (e.g., `{env=~".+"}`)
2. **Alloy config uses `//` comments, not `#`:** Incorrect comment syntax causes parse errors
3. **Prometheus retention is CLI-only:** Changes to `prometheus.yml` retention are ignored
4. **Loki ingestion delay:** Allow 10-15 seconds for logs to appear after generation
5. **Container restarts clear state:** Alloy positions reset; expect duplicate ingestion after restart

See [troubleshooting.md](troubleshooting.md) for full catalog.
