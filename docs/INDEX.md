# Documentation Index

Complete navigation for the Loki logging stack documentation.

## Quick Access

- **First-time users:** Start with [README.md](README.md) for quick start
- **Operators:** See [30-operations.md](30-operations.md) for runbooks
- **Troubleshooting:** See [50-troubleshooting.md](50-troubleshooting.md) for common issues
- **Reference:** See [80-reference.md](80-reference.md) for ports, labels, paths

## Core Documentation

### Getting Started

- **[README.md](README.md)** — Quick start, what's inside, common operations
- **[00-overview.md](00-overview.md)** — Purpose, stack components, scope, guardrails

### Architecture and Deployment

- **[10-architecture.md](10-architecture.md)** — Data flow, components, networks, labels
- **[20-deployment.md](20-deployment.md)** — Deploy, redeploy, upgrade procedures

### Operations

- **[30-operations.md](30-operations.md)** — Common tasks, runbooks, queries, evidence
- **[40-validation.md](40-validation.md)** — Strict validation proofs, health checks
- **[50-troubleshooting.md](50-troubleshooting.md)** — Symptoms → causes → fixes

### Security and Maintenance

- **[60-security.md](60-security.md)** — Exposure posture, secrets, authentication
- **[70-maintenance.md](70-maintenance.md)** — Retention, backups, upgrades, disk management
- **[80-reference.md](80-reference.md)** — Ports, env vars, paths, labels, API endpoints

### Quality Assurance

- **[quality-checklist.md](quality-checklist.md)** — Documentation quality gates

## Documentation by Topic

### Deployment and Setup
- [Quick start](README.md#quick-start)
- [Prerequisites](20-deployment.md#prerequisites)
- [Initial deployment](20-deployment.md#initial-deployment)
- [Post-deployment validation](20-deployment.md#post-deployment-validation)
- [Port configuration](20-deployment.md#port-configuration)

### Architecture
- [Data flow overview](10-architecture.md#data-flow-overview)
- [Component details](10-architecture.md#component-details)
- [Network architecture](10-architecture.md#network-architecture)
- [Persistence](10-architecture.md#persistence)
- [Label schema](10-architecture.md#label-schema)

### Operations
- [Health checks](30-operations.md#health-checks)
- [Viewing logs](30-operations.md#viewing-logs)
- [Restarting services](30-operations.md#restarting-services)
- [Log queries (LogQL)](30-operations.md#log-queries-logql)
- [Metrics queries (PromQL)](30-operations.md#metrics-queries-promql)
- [Evidence generation](30-operations.md#evidence-generation)
- [Grafana administration](30-operations.md#grafana-administration)

### Validation
- [Service health (L1)](40-validation.md#l1-service-health)
- [Data ingestion (L2)](40-validation.md#l2-data-ingestion)
- [Query capability (L3)](40-validation.md#l3-query-capability)
- [Label contract (L4)](40-validation.md#l4-label-contract-validation)
- [Automated validation](40-validation.md#automated-validation-script)
- [Evidence generation](40-validation.md#evidence-generation-proof-archive)

### Troubleshooting
- [No logs in Loki](50-troubleshooting.md#symptom-no-logs-in-loki)
- [Alloy config parse errors](50-troubleshooting.md#symptom-alloy-config-parse-errors)
- [Empty Loki query results](50-troubleshooting.md#symptom-empty-loki-query-results)
- [Prometheus retention not applied](50-troubleshooting.md#symptom-prometheus-retention-not-applied)
- [Grafana login fails](50-troubleshooting.md#symptom-grafana-login-fails)
- [High CPU/memory usage](50-troubleshooting.md#symptom-high-cpumemory-usage)
- [Container restart loops](50-troubleshooting.md#symptom-container-restart-loops)
- [Common pitfalls](50-troubleshooting.md#common-pitfalls)

### Security
- [Exposure posture](60-security.md#exposure-posture)
- [Secrets management](60-security.md#secrets-management)
- [Authentication](60-security.md#authentication)
- [Firewall (UFW)](60-security.md#firewall-ufw)
- [Remote access](60-security.md#remote-access)
- [Docker socket security](60-security.md#docker-socket-security)
- [Log data security](60-security.md#log-data-security)
- [Security checklist](60-security.md#security-checklist)

### Maintenance
- [Retention policies](70-maintenance.md#retention-policies)
- [Evidence rotation](70-maintenance.md#evidence-rotation)
- [Backup and restore](70-maintenance.md#backup-and-restore)
- [Upgrades](70-maintenance.md#upgrades)
- [Disk space management](70-maintenance.md#disk-space-management)
- [Resource tuning](70-maintenance.md#resource-tuning)
- [Log file management](70-maintenance.md#log-file-management)
- [Maintenance checklist](70-maintenance.md#maintenance-checklist-monthly)

### Reference
- [Port assignments](80-reference.md#port-assignments)
- [Environment variables](80-reference.md#environment-variables-env)
- [File paths](80-reference.md#file-paths)
- [Docker resources](80-reference.md#docker-resources)
- [Label schema](80-reference.md#label-schema)
- [API endpoints](80-reference.md#api-endpoints)
- [Configuration parameters](80-reference.md#configuration-parameters)
- [Image versions](80-reference.md#image-versions)
- [Query examples](80-reference.md#query-examples)
- [Health check commands](80-reference.md#health-check-commands)

## Config Snippets

Canonical config excerpts (synced from `infra/logging/` configs):

- **[snippets/loki-config.yml](snippets/loki-config.yml)** — Loki retention, schema, compaction
- **[snippets/alloy-config.alloy](snippets/alloy-config.alloy)** — Alloy log ingestion pipelines
- **[snippets/prometheus.yml](snippets/prometheus.yml)** — Prometheus scrape targets

**Note:** These snippets are copied from canonical config files. Do not edit directly; update source configs and regenerate.

## Archive

Historical/snapshot documentation (not part of primary navigation):

- **[archive/10-as-installed.md](archive/10-as-installed.md)** — Installation snapshot
- **[archive/20-as-configured.md](archive/20-as-configured.md)** — Configuration snapshot
- **[archive/monitoring.md](archive/monitoring.md)** — Old monitoring notes

**Purpose:** Audit trail and historical reference. Not maintained for operational use.

## External Resources

### Official Documentation
- **Grafana Loki:** https://grafana.com/docs/loki/latest/
- **Grafana:** https://grafana.com/docs/grafana/latest/
- **Prometheus:** https://prometheus.io/docs/
- **Grafana Alloy:** https://grafana.com/docs/alloy/latest/
- **LogQL (Loki query language):** https://grafana.com/docs/loki/latest/query/
- **PromQL (Prometheus query language):** https://prometheus.io/docs/prometheus/latest/querying/basics/

### GitHub Repositories
- **Grafana Loki:** https://github.com/grafana/loki
- **Grafana:** https://github.com/grafana/grafana
- **Prometheus:** https://github.com/prometheus/prometheus
- **Grafana Alloy:** https://github.com/grafana/alloy

## Documentation Maintenance

- **Last updated:** 2026-02-12 (full docs reconstruction)
- **Quality checklist:** [quality-checklist.md](quality-checklist.md)
- **Review frequency:** After every doc change (before commit)
- **Full audit:** Monthly or before major releases

## Document Conventions

### File Naming
- Core docs: `NN-topic.md` (00-99 prefixes for ordering)
- Supporting docs: `kebab-case.md` (lowercase with hyphens)
- Archive docs: Original names preserved

### Link Format
- Internal docs: `[Text](file.md)` or `[Text](file.md#anchor)`
- External links: `[Text](https://...)`
- Code references: `[filename.ext:line](../path/to/file)`

### Code Blocks
- Always specify language: \```bash, \```logql, \```yaml, etc.
- Include expected output where helpful
- Use comments to explain complex commands

### Cross-References
- Each doc links to related docs ("Next Steps" or "See Also")
- Reference doc (80-reference.md) links to all primary docs
- Troubleshooting doc links to relevant operational sections

## Quick Reference Cards

### Essential Commands
```bash
# Deploy
./scripts/mcp/logging_stack_up.sh

# Health
./scripts/mcp/logging_stack_health.sh

# Evidence
./scripts/prism/evidence.sh

# Stop
./scripts/mcp/logging_stack_down.sh
```

### Essential Queries
```logql
# All logs
{env="sandbox"}

# Docker logs
{env="sandbox", container_name=~".+"}

# Errors
{env="sandbox"} |= "error"

# CodeSwarm MCP
{env="sandbox", log_source="codeswarm_mcp"}
```

### Essential URLs
- Grafana: http://127.0.0.1:9001
- Prometheus: http://127.0.0.1:9004

### Essential Files
- Compose: `infra/logging/docker-compose.observability.yml`
- Secrets: `infra/logging/.env` (mode 600)
- Loki config: `infra/logging/loki-config.yml`
- Alloy config: `infra/logging/alloy-config.alloy`

## Navigation Tips

1. **First time?** Start with [README.md](README.md) → [00-overview.md](00-overview.md) → [20-deployment.md](20-deployment.md)
2. **Something broken?** Go directly to [50-troubleshooting.md](50-troubleshooting.md)
3. **Need a command?** Check [80-reference.md](80-reference.md) or use search (Ctrl+F)
4. **Validating deployment?** Follow [40-validation.md](40-validation.md) checklist
5. **Planning maintenance?** Review [70-maintenance.md](70-maintenance.md)

## Contributing to Docs

When updating documentation:
1. Read existing style (match tone, format, structure)
2. Update [quality-checklist.md](quality-checklist.md) if adding new requirements
3. Regenerate snippets if configs changed: `cp infra/logging/*.{yml,alloy} docs/snippets/`
4. Validate all cross-links work
5. Test all commands in a clean environment
6. Update this INDEX.md if adding new sections

**Never commit:**
- Secret values (passwords, keys)
- Evidence files (use `temp/` which is gitignored)
- Stale config snippets (always sync from canonical configs)
