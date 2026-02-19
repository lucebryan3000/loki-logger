# Documentation Quality Checklist

This checklist ensures documentation correctness, operational validity, and style consistency.

## Correctness Checks

### Ports and Bindings
- [ ] Grafana port is bound to loopback by default (`127.0.0.1:9001`) unless intentionally overridden
- [ ] Prometheus port is bound to loopback by default (`127.0.0.1:9004`) unless intentionally overridden
- [ ] Loki is internal-only (no external binding)
- [ ] All port references in docs match `docker-compose.observability.yml` + `.env`

### File Paths
- [ ] Config paths point to `infra/logging/` directory
- [ ] Script paths point to `scripts/prod/mcp/` and `scripts/prod/prism/`
- [ ] Evidence output path is `temp/evidence/`
- [ ] All file paths are absolute or clearly relative to repo root

### Container Names
- [ ] Container names use `logging-` prefix
- [ ] Service names match compose file (grafana, loki, prometheus, alloy, etc.)
- [ ] Volume names include `logging_` prefix

### Labels
- [ ] Label contract matches runtime truth (`log_source` required; `env` present where configured)
- [ ] Docker logs have `container_name` label
- [ ] CodeSwarm MCP logs have `log_source=codeswarm_mcp` label
- [ ] No queries use empty selector `{}`

### Retention
- [ ] Loki retention is 720h (30 days)
- [ ] Prometheus retention is 15 days (CLI flag, not prometheus.yml)
- [ ] Compaction interval is 10m for Loki

### Image Versions
- [ ] All image versions match the pinned values in `.env.example` (authoritative source)
- [ ] No service is running a different version than what `.env` specifies
- [ ] `docker compose -p logging -f infra/logging/docker-compose.observability.yml images` output matches `.env` pins

## Operational Checks

### Health Validation
- [ ] Grafana health: `curl -sf http://127.0.0.1:9001/api/health`
- [ ] Prometheus ready: `curl -sf http://127.0.0.1:9004/-/ready`
- [ ] All containers show `Up` status in `docker compose -p logging -f infra/logging/docker-compose.observability.yml ps`

### Query Examples
- [ ] All LogQL queries have non-empty selectors (not `{}`)
- [ ] LogQL queries use dynamic time ranges or relative windows
- [ ] PromQL queries target valid metric names
- [ ] Example queries are syntactically valid

### Command Validity
- [ ] All docker compose commands in active docs use `-p logging -f infra/logging/docker-compose.observability.yml` (or `$COMPOSE_PROJECT_NAME` + `$OBS` pattern)
- [ ] All script paths are executable: `scripts/prod/mcp/*.sh`, `scripts/prod/prism/*.sh`
- [ ] curl commands use `-sf` for silent failures where appropriate
- [ ] No commands contain placeholders like `<service>` without context

### Ingestion Validation
- [ ] Log files monitored at `/home/luce/_logs/*.log`
- [ ] Telemetry monitored at `/home/luce/_telemetry/*.jsonl`
- [ ] CodeSwarm MCP monitored at `/home/luce/apps/vLLM/_data/mcp-logs/*.log`
- [ ] Alloy mounts are read-only (`:ro`) for configs
- [ ] Docker socket mount is read-only

## Security Checks

### Secrets
- [ ] No secret values (passwords, keys) in docs
- [ ] `.env` file referenced as mode 600
- [ ] `.env` is gitignored
- [ ] Secrets are never logged in evidence files

### Exposure
- [ ] External services bound to expected interface (0.0.0.0 or 127.0.0.1 per .env)
- [ ] Docker-published ports are intentionally scoped (loopback preferred) and not assumed protected by UFW alone
- [ ] Loki has no exposed ports (internal-only)
- [ ] No authentication bypasses documented

### Authentication
- [ ] Grafana requires username/password
- [x] Prometheus exposure is either loopback-only or protected with explicit auth controls
- [ ] Admin password reset instructions are correct

## Style Checks

### Consistency
- [ ] Service names are lowercase: grafana, loki, prometheus, alloy
- [ ] File names use kebab-case: `quality-checklist.md`, not `QualityChecklist.md`
- [ ] Commands use full paths: `scripts/prod/mcp/logging_stack_up.sh` not `logging_stack_up.sh`
- [ ] Code blocks specify language: \```bash, \```logql, \```promql, \```yaml

### Cross-Links
- [ ] All internal doc links use markdown: `[text](file.md)`
- [ ] All cross-references point to existing files
- [ ] No broken links (404s)
- [ ] Anchors (#headings) are valid

### Terminology
- [ ] "Stack" not "cluster" (single-node deployment)
- [ ] Interface terminology matches deployed bind addresses (`127.0.0.1` vs `0.0.0.0`)
- [ ] "Internal-only" for services without exposed ports
- [ ] "Evidence" for proof archives, not "logs" or "reports"

### Code Examples
- [ ] All bash commands are executable (no syntax errors)
- [ ] All LogQL queries are syntactically valid
- [ ] All PromQL queries are syntactically valid
- [ ] All YAML/JSON snippets are well-formed

## Common Gotchas (Must Be Documented)

- [ ] Alloy uses `//` comments, not `#`
- [ ] Empty Loki selectors `{}` are rejected
- [ ] Prometheus retention is CLI-only (not in prometheus.yml)
- [ ] Frozen query window issue (Grafana time picker)
- [ ] Ingestion delay (10-15 seconds expected)
- [ ] Loki is internal-only (no http://127.0.0.1:3100)
- [ ] Config changes require container restart

## Validation Against Live Stack

### Config Files Match
- [ ] `docs/snippets/loki-config.yml` matches `infra/logging/loki-config.yml`
- [ ] `docs/snippets/alloy-config.alloy` matches `infra/logging/alloy-config.alloy`
- [ ] `docs/snippets/prometheus.yml` matches `infra/logging/prometheus/prometheus.yml`

### Runtime Verification
- [ ] Deploy stack: `./scripts/prod/mcp/logging_stack_up.sh`
- [ ] Health check passes: `./scripts/prod/mcp/logging_stack_health.sh`
- [ ] Audit check passes: `./scripts/prod/mcp/logging_stack_audit.sh _build/Sprint-3/reference/native_audit.json`
- [ ] Generate test log: `echo "test_$(date +%s)" >> /home/luce/_logs/test.log`
- [ ] Wait 15 seconds: `sleep 15`
- [ ] Query returns results: `{env="sandbox", filename=~".*test.log"} |= "test_"`
- [ ] Evidence generation succeeds: `./scripts/prod/prism/evidence.sh`

## Documentation Structure Checks

### File Organization
- [ ] All primary docs in `docs/` root
- [ ] Historical archive docs in `docs/archive/` are clearly marked non-authoritative
- [ ] Config snippets in `docs/snippets/`
- [ ] Evidence in `temp/evidence/` (gitignored)

### Navigation
- [ ] `README.md` exists and provides quickstart
- [ ] `INDEX.md` exists and links to all docs
- [ ] Each doc links to related docs ("Next Steps" or "See Also")
- [ ] Cross-references are bidirectional (A links to B, B links back)

### Completeness
- [ ] overview.md covers purpose, scope, guardrails
- [ ] architecture.md covers data flow, components, networks
- [ ] deployment.md covers deploy, redeploy, upgrades
- [ ] operations.md covers runbooks, queries, admin tasks
- [ ] validation.md covers strict proofs and evidence
- [ ] troubleshooting.md covers symptoms → fixes
- [ ] security.md covers exposure, secrets, compliance
- [ ] maintenance.md covers retention, backups, upgrades
- [ ] reference.md covers ports, labels, paths, env vars

## Accessibility Checks

### Readability
- [ ] Sentences are concise (< 25 words preferred)
- [ ] Technical jargon is explained or linked
- [ ] Commands have clear expected outputs
- [ ] Code blocks have syntax highlighting

### Actionability
- [ ] All runbooks have clear steps (1, 2, 3...)
- [ ] All commands are copy-pasteable (no placeholders unless explained)
- [ ] All symptoms have diagnosis + fix
- [ ] All errors have troubleshooting guidance

## Regression Test (After Changes)

After updating docs, run this test sequence:

```bash
# 1. Deploy stack
./scripts/prod/mcp/logging_stack_up.sh

# 2. Verify health
./scripts/prod/mcp/logging_stack_health.sh

# 3. Generate test logs
echo "validation_$(date +%s)" >> /home/luce/_logs/test.log

# 4. Wait for ingestion
sleep 15

# 5. Query in Grafana (manual)
# {env="sandbox", filename=~".*test.log"} |= "validation_"

# 6. Generate evidence
./scripts/prod/prism/evidence.sh

# 7. Verify no errors in logs
docker compose -p logging -f infra/logging/docker-compose.observability.yml logs --tail 100 | grep -i error

# 8. Tear down
./scripts/prod/mcp/logging_stack_down.sh
```

**Pass criteria:** All steps succeed without manual intervention.

## Maintenance

**Review frequency:** After every doc change (before commit)

**Full audit frequency:** Monthly or before major releases

**Owner:** Documentation maintainer

**Last reviewed:** 2026-02-14 (Sprint-3 native contract alignment)
