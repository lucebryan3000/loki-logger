# Log Rotation Design

## Goals

1. Prevent disk exhaustion from unbounded log growth
2. Maintain 7-day local history for debugging (Loki has 30d retention)
3. Minimize write amplification (copytruncate vs create)
4. Avoid breaking open file handles
5. Single source of truth for retention config

## Architecture Decisions

### Config-Driven Approach

**Why:** User can adjust thresholds per service without editing templates or scripts.

**Implementation:** KV config file (`retention.conf`) → templates → generated configs

**Trade-off:** Slight complexity (build step) vs flexibility

**Rejected:** Hardcoded values in scripts (not maintainable at scale)

---

### Handler Selection

#### logrotate for file-based logs
- **Why:** Battle-tested (28 years), declarative, already installed
- **Config:** `/etc/logrotate.d/loki-sources`
- **Run frequency:** Daily via systemd timer

**Trade-offs:**
- ✅ Zero new dependencies
- ✅ Handles any file format
- ❌ Only runs daily (not real-time)

#### journalctl --vacuum for systemd services
- **Why:** Native systemd solution, continuous enforcement
- **Config:** `/etc/systemd/journald.conf.d/99-loki-retention.conf`

**Trade-offs:**
- ✅ No cron dependency
- ✅ Uniform handling across all services
- ❌ Less granular (all services share same limits)

#### Docker log driver for containers
- **Why:** Per-container isolation, immediate enforcement
- **Config:** Inline in `docker-compose.yml`

**Trade-offs:**
- ✅ Immediate rotation on size
- ✅ Container-specific limits
- ❌ Already configured (no work needed, but less flexible)

---

### Copytruncate vs Create

**Using `copytruncate` for all file logs because:**
- Apps may not respond to SIGHUP (Node.js, Python scripts)
- Avoids breaking open file handles
- Safer default for mixed app environments

**Trade-off:**
- Brief window during copy where writes may be lost (acceptable for sandbox)
- Higher disk I/O (copy + truncate) vs create (rename + create)

**Alternative:** `create` + `postrotate` with `systemctl reload` signals
- **Why not:** Requires knowing which service to reload per log file
- **When to use:** Production environments where every log line matters

---

## Rejected Alternatives

### Application-Level Rotation (Python `RotatingFileHandler`)
- ❌ Requires code changes in every app
- ❌ No centralized management
- ❌ Won't work for third-party apps

### Fluent Bit with DB.Sync
- ❌ Requires replacing Alloy (major architecture change)
- ❌ Overkill for simple rotation
- ❌ No guaranteed "confirmed in Loki" signal anyway

### Custom Position-Tracking Script
- ❌ Fragile (depends on Alloy position file format)
- ❌ No safety guarantees (network failures = data loss)
- ❌ Maintenance burden vs standard tools

### Ingestion-Aware Cleanup
**Concept:** Only delete logs after Loki confirms ingestion

**Why rejected:**
- Loki doesn't expose "confirmed up to byte X" API
- Alloy position file tracks reads, not writes
- Network partition = Alloy reads but Loki doesn't receive
- Over-engineering for 7-day local retention (23+ hour buffer before rotation)

---

## Template System

**Why templates + config vs hardcoded:**
- Single source of truth (`retention.conf`)
- User can change thresholds without editing scripts
- Easier to add new log sources (add to config + template block)

**Implementation:** Bash envsubst-style `{{VAR}}` substitution

**Templates:**
- `templates/logrotate.conf.tmpl` → `.build/loki-sources.conf` → `/etc/logrotate.d/loki-sources`
- `templates/journald.conf.tmpl` → `.build/99-loki-retention.conf` → `/etc/systemd/journald.conf.d/99-loki-retention.conf`
- `templates/samba.conf.tmpl` → `.build/samba.conf` → `/etc/logrotate.d/samba` (conditional, if enabled)

**Trade-offs:**
- ✅ Simple (no external dependencies)
- ✅ Config file is bash-sourceable (easy validation)
- ❌ Less powerful than Jinja2 (no conditionals in templates)

**Mitigation:** Conditionals handled in `build-configs.sh` (e.g., skip samba if disabled)

---

## Security Considerations

### File Permissions
- Generated configs deployed with 644 (world-readable)
- No secrets in configs (paths and thresholds only)
- logrotate runs as file owner via `su` directive

### Sudo Requirements
- `install.sh`, `test-rotation.sh`, `uninstall.sh` require sudo
- `validate.sh`, `status.sh` use sudo only for specific checks
- Never run `build-configs.sh` as sudo (generates files in user-space)

### Backup Strategy
- `install.sh` creates timestamped backups before overwriting
- Backups in `/etc/logrotate.d.backup-YYYYMMDD-HHMMSS/`
- `uninstall.sh` does NOT delete backups (manual cleanup)

---

## Operational Workflows

### Install Workflow

```
User edits retention.conf
         ↓
build-configs.sh renders templates
         ↓
Generated configs in .build/
         ↓
install.sh deploys to /etc/
         ↓
logrotate.timer runs daily
journald enforces limits continuously
```

### Configuration Change Workflow

1. **Edit** `config/retention.conf` with new thresholds
2. **Rebuild** with `./scripts/build-configs.sh`
3. **Review** generated configs in `.build/`
4. **Install** with `sudo ./scripts/install.sh`
5. **Validate** with `./scripts/validate.sh`
6. **Verify** installation with `./scripts/status.sh`

### Uninstall Workflow

1. Run `sudo ./scripts/uninstall.sh`
2. Restores system defaults
3. Preserves timestamped backups
4. Manual cleanup of backups if needed

### Decommission Workflow (codeswarm-tidyup)

**Status:** Completed 2026-02-14

1. Ran `sudo ./scripts/decommission-codeswarm.sh --yes`
2. Created backup archive (deleted after verification)
3. Removed all codeswarm-tidyup files (service, timer, config, script, logs)
4. Updated project docs (CLAUDE.md, docs/maintenance.md)

**Note:** This was a one-time migration script. codeswarm-tidyup is fully removed.

---

## Retention Policies

| Handler | Sources | Retention | Max Size | Rotation |
|---------|---------|-----------|----------|----------|
| **Alloy file sources** | `_logs/*.log`, `_telemetry/*.jsonl`, `mcp-logs/*.log`, `nvidia/*.jsonl` | 7 days | 25MB/file | Daily or size |
| **VSCode/Code-Server** | `.vscode-server/**/*.log` | 4 weeks | 50MB/file | Weekly |
| **systemd journal** | All services | 7 days | 1GB total | Continuous |
| **Docker containers** | 10 containers | 30MB total | 10MB/file | On size |

---

## Future Enhancements (Out of Scope)

- **Metrics export:** Expose rotation metrics to Prometheus
- **Centralized config:** Auto-generate from Alloy config (single source)
- **Automated testing:** CI pipeline to validate template rendering
- **Multi-tenant:** Per-stack retention policies
