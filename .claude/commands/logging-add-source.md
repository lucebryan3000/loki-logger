# logging-add-source

Add a new log source to the Loki logging stack.

**Type**: Command wrapper for playbook execution  
**Playbook**: `/home/luce/apps/loki-logging/.claude/prompts/loki-logging-setup-playbook.md`  
**Reference**: `/home/luce/apps/loki-logging/.claude/prompts/loki-logging-setup-reference.md`

---

## Usage

```bash
/logging-add-source <application> <path>
```

**Or just describe it naturally:**

```
Ingest logs from <application> at <path>
```

---

## Examples

```bash
# Web server logs
/logging-add-source nginx /var/log/nginx/

# Application logs
/logging-add-source myapp /home/luce/apps/myapp/logs/

# Database logs
/logging-add-source postgres /var/lib/postgresql/logs/

# Natural language (recommended)
Ingest logs from my Flask API at /home/luce/apps/flask-api/logs/
```

---

## What This Does

Executes the **loki-logging-setup-playbook** (8 phases):

1. **Discovery** — Analyzes log path, format, volume, sensitivity
2. **Mount Check** — Verifies Alloy container can access the path
3. **Label Design** — Designs bounded label schema (env, log_source)
4. **Processor** — Chooses dedicated vs shared processor
5. **Config** — Generates HCL blocks (file_match, source, process)
6. **Verify** — Applies config, restarts Alloy, verifies ingestion
7. **Audit** — Runs 18+ validation checks
8. **Remediate** — Auto-fixes any audit failures

**End result:** Logs appear in Grafana queryable via `{log_source="<application>"}`

---

## Execution

When you invoke this command, Claude will:

1. **Read the playbook** at `.claude/prompts/loki-logging-setup-playbook.md`
2. **Execute all 8 phases** automatically
3. **Reference the guide** at `.claude/prompts/loki-logging-setup-reference.md` for details
4. **Ask for confirmation** before applying config changes
5. **Verify end-to-end** that logs appear in Loki
6. **Auto-remediate** any audit failures

---

## Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `<application>` | Application or service name (becomes `log_source` label) | Yes |
| `<path>` | Absolute path to log files on host (supports globs) | Yes |

**Path examples:**
- `/var/log/nginx/` — directory with log files
- `/home/luce/apps/myapp/logs/*.log` — glob pattern
- `/var/lib/postgresql/logs/postgresql-*.log` — specific pattern

---

## Current Sources (7 active)

Before adding a new source, verify it doesn't already exist:

| Source | Type | Path | Processor | log_source |
|--------|------|------|-----------|------------|
| journald | rsyslog→syslog | systemd journal | journald | `journald` |
| docker | Docker socket | /var/run/docker.sock | docker | `docker` |
| vscode_server | File tail | ~/.vscode-server/**/*.log | vscode | `vscode_server` |
| codeswarm_mcp | File tail | apps/vLLM/_data/mcp-logs/*.log | codeswarm | `codeswarm_mcp` |
| nvidia_telem | File tail | apps/vLLM/logs/telemetry/nvidia/*.jsonl | nvidia_telem | (none) |
| telemetry | File tail | ~/_telemetry/*.jsonl | main | (none) |
| tool_sink | File tail | ~/_logs/*.log | main | (none) |

---

## Requirements

✓ **Path accessible** — Must be under `/home/` or have volume mount in docker-compose  
✓ **Bounded labels** — No UUIDs, timestamps, or unbounded cardinality  
✓ **Unique log_source** — Don't duplicate existing source names  
✓ **File permissions** — Alloy container must have read access  

---

## Outputs

**Files modified:**
- `infra/logging/alloy-config.alloy` — Adds file_match, source, process blocks
- `infra/logging/docker-compose.observability.yml` — (if new volume mount needed)

**Verification:**
- Alloy restarts successfully (no parse errors)
- Logs appear in Loki: `{log_source="<application>"}`
- Full audit passes (18+ checks)

---

## Troubleshooting

**"Path not accessible"**
→ Check if path is under `/home/` or add volume mount to docker-compose

**"No logs appearing in Loki"**
→ Check Alloy logs: `docker compose -p logging logs alloy --tail=50`
→ Verify file has new content (tail_from_end = true, only ingests new lines)

**"Audit failures"**
→ Phase 7b will auto-remediate most failures
→ Review remediation report for details

**"Parse errors after restart"**
→ Check HCL syntax (use `//` comments, not `#`)
→ Verify regex escaping (double backslashes: `"\\b"`)

---

## Rollback

If something goes wrong:

```bash
# Revert config
git checkout infra/logging/alloy-config.alloy

# Restart Alloy
docker compose -p logging -f infra/logging/docker-compose.observability.yml restart alloy
```

Or use **Phase 8: Rollback** from the playbook.

---

## Reference

**Playbook**: `/home/luce/apps/loki-logging/.claude/prompts/loki-logging-setup-playbook.md`  
**Guide**: `/home/luce/apps/loki-logging/.claude/prompts/loki-logging-setup-reference.md`  
**Docs**: `/home/luce/apps/loki-logging/docs/operations.md` (LogQL examples)

---

## Implementation

```yaml
# This command wrapper automatically invokes the playbook

execution:
  1. Read playbook at .claude/prompts/loki-logging-setup-playbook.md
  2. Execute phases 1-8 with user input
  3. Reference .claude/prompts/loki-logging-setup-reference.md for details
  4. Apply config changes with user approval
  5. Verify end-to-end ingestion
  6. Auto-remediate audit failures
  7. Report final status

autonomous: false  # Requires user confirmation before applying changes
playbook_driven: true  # All logic in the playbook, this is just the entry point
```
