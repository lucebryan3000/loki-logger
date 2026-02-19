# API Usage Docs

This directory contains app-to-app API guidance for querying Loki and Grafana.

## Documents

- **[authoritative-loki-grafana-api.md](authoritative-loki-grafana-api.md)** — Comprehensive API contract summary from official Grafana/Loki docs.
- **[server-specific-api-usage.md](server-specific-api-usage.md)** — API usage mapped to this repository's actual runtime configuration.

## Scope

- Intended for automation and service integrations (CLI jobs, scripts, backend services).
- Focused on log querying workflows (Loki API first, Grafana API when needed).
- Includes copy/paste-ready examples and troubleshooting patterns.

## Cross-References

- [../reference.md](../reference.md) — Ports, labels, and core stack reference.
- [../operations.md](../operations.md) — Operational workflows and validation commands.
- [../query-contract.md](../query-contract.md) — Canonical query IDs used by dashboards/alerts/checks.
