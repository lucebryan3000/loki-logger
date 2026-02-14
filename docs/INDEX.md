# Documentation Index

Complete navigation for the Loki logging stack documentation.

## Quick Access

- **First-time users:** Start with [README.md](README.md) for quick start
- **Operators:** See [operations.md](operations.md) for runbooks
- **Troubleshooting:** See [troubleshooting.md](troubleshooting.md) for common issues
- **Reference:** See [reference.md](reference.md) for ports, labels, paths

## Core Documentation

### Getting Started

- **[README.md](README.md)** — Quick start, what's inside, common operations
- **[overview.md](overview.md)** — Purpose, stack components, scope, guardrails

### Architecture and Deployment

- **[architecture.md](architecture.md)** — Data flow, components, networks, labels
- **[deployment.md](deployment.md)** — Deploy, redeploy, upgrade procedures

### Operations

- **[operations.md](operations.md)** — Common tasks, runbooks, queries, evidence
- **[validation.md](validation.md)** — Strict validation proofs, health checks
- **[troubleshooting.md](troubleshooting.md)** — Symptoms → causes → fixes

### Security and Maintenance

- **[security.md](security.md)** — Exposure posture, secrets, authentication
- **[maintenance.md](maintenance.md)** — Retention, backups, upgrades, disk management
- **[reference.md](reference.md)** — Ports, env vars, paths, labels, API endpoints

### Quality Assurance

- **[quality-checklist.md](quality-checklist.md)** — Documentation quality gates

## Documentation by Topic

### Deployment and Setup
- [Quick start](README.md#quick-start)
- [Prerequisites](deployment.md#prerequisites)
- [Initial deployment](deployment.md#initial-deployment)
- [Post-deployment validation](deployment.md#post-deployment-validation)
- [Port configuration](deployment.md#port-configuration)

### Architecture
- [Data flow overview](architecture.md#data-flow-overview)
- [Component details](architecture.md#component-details)
- [Network architecture](architecture.md#network-architecture)
- [Persistence](architecture.md#persistence)
- [Label schema](architecture.md#label-schema)

### Operations
- [Health checks](operations.md#health-checks)
- [Viewing logs](operations.md#viewing-logs)
- [Restarting services](operations.md#restarting-services)
- [Log queries (LogQL)](operations.md#log-queries-logql)
- [Metrics queries (PromQL)](operations.md#metrics-queries-promql)
- [Evidence generation](operations.md#evidence-generation)
- [Grafana administration](operations.md#grafana-administration)

### Validation
- [Service health (L1)](validation.md#l1-service-health)
- [Data ingestion (L2)](validation.md#l2-data-ingestion)
- [Query capability (L3)](validation.md#l3-query-capability)
- [Label contract (L4)](validation.md#l4-label-contract-validation)
- [Automated validation](validation.md#automated-validation-script)
- [Evidence generation](validation.md#evidence-generation-proof-archive)

### Troubleshooting
- [No logs in Loki](troubleshooting.md#symptom-no-logs-in-loki)
- [Alloy config parse errors](troubleshooting.md#symptom-alloy-config-parse-errors)
- [Empty Loki query results](troubleshooting.md#symptom-empty-loki-query-results)
- [Prometheus retention not applied](troubleshooting.md#symptom-prometheus-retention-not-applied)
- [Grafana login fails](troubleshooting.md#symptom-grafana-login-fails)
- [High CPU/memory usage](troubleshooting.md#symptom-high-cpumemory-usage)
- [Container restart loops](troubleshooting.md#symptom-container-restart-loops)
- [Common pitfalls](troubleshooting.md#common-pitfalls)

### Security
- [Exposure posture](security.md#exposure-posture)
- [Secrets management](security.md#secrets-management)
- [Authentication](security.md#authentication)
- [Firewall (UFW)](security.md#firewall-ufw)
- [Remote access](security.md#remote-access)
- [Docker socket security](security.md#docker-socket-security)
- [Log data security](security.md#log-data-security)
- [Security checklist](security.md#security-checklist)

### Maintenance
- [Retention policies](maintenance.md#retention-policies)
- [Evidence rotation](maintenance.md#evidence-rotation)
- [Backup and restore](maintenance.md#backup-and-restore)
- [Upgrades](maintenance.md#upgrades)
- [Disk space management](maintenance.md#disk-space-management)
- [Resource tuning](maintenance.md#resource-tuning)
- [Log file management](maintenance.md#log-file-management)
- [Maintenance checklist](maintenance.md#maintenance-checklist-monthly)

### Reference
- [Port assignments](reference.md#port-assignments)
- [Environment variables](reference.md#environment-variables-env)
- [File paths](reference.md#file-paths)
- [Docker resources](reference.md#docker-resources)
- [Label schema](reference.md#label-schema)
- [API endpoints](reference.md#api-endpoints)
- [Configuration parameters](reference.md#configuration-parameters)
- [Image versions](reference.md#image-versions)
- [Query examples](reference.md#query-examples)
- [Health check commands](reference.md#health-check-commands)

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
- Reference doc (reference.md) links to all primary docs
- Troubleshooting doc links to relevant operational sections

## Quick Reference Cards

### Essential Commands
```bash
# Deploy
./scripts/prod/mcp/logging_stack_up.sh

# Health
./scripts/prod/mcp/logging_stack_health.sh

# Evidence
./scripts/prod/prism/evidence.sh

# Stop
./scripts/prod/mcp/logging_stack_down.sh
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
- Grafana: http://192.168.1.150:9001
- Prometheus: http://192.168.1.150:9004

### Essential Files
- Compose: `infra/logging/docker-compose.observability.yml`
- Secrets: `.env` (mode 600)
- Loki config: `infra/logging/loki-config.yml`
- Alloy config: `infra/logging/alloy-config.alloy`

## Navigation Tips

1. **First time?** Start with [README.md](README.md) → [overview.md](overview.md) → [deployment.md](deployment.md)
2. **Something broken?** Go directly to [troubleshooting.md](troubleshooting.md)
3. **Need a command?** Check [reference.md](reference.md) or use search (Ctrl+F)
4. **Validating deployment?** Follow [validation.md](validation.md) checklist
5. **Planning maintenance?** Review [maintenance.md](maintenance.md)

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
