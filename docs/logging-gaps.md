# Logging Implementation Gap Analysis

**Generated:** 2026-02-13
**Compared:** Current implementation vs Sprint-1 specification (_build/Sprint-1/)

## Executive Summary

Current logging implementation is **~35% complete** relative to Sprint-1 plan. Core ingestion pipelines are functional, but critical features missing:
- No source filtering (Docker/journald allowlists)
- Minimal custom labeling (2/7+ planned labels)
- No redaction pipeline (security risk)
- Missing log sources (MCP state snapshots, repo artifacts)
- No safe JSON parsing for structured logs

---

## 1. Log Sources: Current vs Planned

### ✅ Implemented

| Source | Path/Target | Status |
|--------|-------------|--------|
| Docker containers | All via `/var/run/docker.sock` | **Functional but unfiltered** |
| Systemd journal | All units | **Functional but unfiltered** |
| Tool sink logs | `/home/luce/_logs/*.log` | **Functional** |
| Telemetry JSONL | `/home/luce/_telemetry/*.jsonl` | **Functional** |
| CodeSwarm MCP logs | `/home/luce/apps/vLLM/_data/mcp-logs/*.log` | **Functional with custom label** |

### ❌ Missing

| Source | Planned Path | Labels | Priority |
|--------|--------------|--------|----------|
| MCP state snapshots | `/home/luce/apps/vLLM/_data/mcp-state/*.json` | source="file", stack="vllm", component="mcp_state" | **HIGH** |
| Repo artifacts | `/home/luce/apps/vLLM/_data/vllm-repo/**/*.log` | source="file", stack="vllm", component="repo" | **MEDIUM** |
| Repo JSONL | `/home/luce/apps/vLLM/_data/vllm-repo/**/*.jsonl` | source="file", stack="vllm", component="repo" | **MEDIUM** |

---

## 2. Docker Ingestion Gaps

### Current Implementation
```alloy
discovery.docker "all" {
  host = "unix:///var/run/docker.sock"
}

loki.source.docker "dockerlogs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.all.targets  // ❌ NO FILTERING
  forward_to = [loki.process.main.receiver]
}
```

**Issues:**
- Captures ALL containers (unbounded stream)
- No compose project filtering
- Observability stack logs itself (recursion risk)
- Uses auto-labels only (container_name, image, compose_project)

### Planned Implementation (Sprint-1 Phase 9)

```alloy
discovery.docker "all" {
  host = "unix:///var/run/docker.sock"
  filter {
    name  = "label"
    values = ["com.docker.compose.project=~vllm|hex"]  // ✅ ALLOWLIST
  }
  filter {
    name  = "label"
    values = ["com.docker.compose.project!=infra_observability"]  // ✅ EXCLUDE SELF
  }
}

loki.source.docker "dockerlogs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.all.targets
  forward_to = [loki.process.docker.receiver]  // ✅ CUSTOM PIPELINE
}

loki.process "docker" {
  stage.static_labels {
    values = {
      source  = "docker",
      stack   = "",  // Extracted from compose_project metadata
      service = "",  // Extracted from compose_service metadata
    }
  }
  forward_to = [loki.write.default.receiver]
}
```

**Missing features:**
- Docker allowlist (vllm + hex compose projects)
- Self-exclusion (infra_observability)
- Custom labels (source, stack, service)

---

## 3. Systemd Journal Gaps

### Current Implementation
```alloy
loki.source.journal "journald" {
  forward_to = [loki.process.main.receiver]  // ❌ ALL UNITS
}
```

**Issues:**
- Ingests ALL systemd units (unbounded cardinality)
- No filtering = noise (cron jobs, network events, etc.)
- No custom labels

### Planned Implementation (Sprint-1 Phase 9)

```alloy
loki.source.journal "journald" {
  matches     = "_SYSTEMD_UNIT=(cloudflared|docker|containerd|ssh|ufw|nvidia-persistenced|thermald|smartmontools|vnstat|smbd|nmbd|cron|systemd-networkd|systemd-resolved|systemd-timesyncd).service"
  forward_to  = [loki.process.journal.receiver]
}

loki.process "journal" {
  stage.static_labels {
    values = {
      source  = "journal",
      stack   = "host",
      service = "",  // Extracted from _SYSTEMD_UNIT
    }
  }
  stage.labels {
    values = {
      level = "PRIORITY",  // Optional: map syslog priority
    }
  }
  forward_to = [loki.write.default.receiver]
}
```

**Missing features:**
- Unit allowlist (14 specific services)
- Custom labels (source="journal", stack="host", service)
- Optional priority-to-level mapping

---

## 4. Label Schema Gaps

### Current Labels

| Source | Current Labels | Completeness |
|--------|----------------|--------------|
| Docker | `env=sandbox` (static) + auto (container_name, image, compose_project) | **20%** |
| Journald | `env=sandbox` (static) + auto (job) | **15%** |
| Tool sink | `env=sandbox` (static) | **15%** |
| Telemetry | `env=sandbox` (static) | **15%** |
| CodeSwarm MCP | `env=sandbox`, `log_source=codeswarm_mcp` | **30%** |

**Total custom labels applied:** 2 (env, log_source)

### Planned Labels (Sprint-1)

**Low-cardinality identity labels (required for all sources):**

| Label | Values | Purpose |
|-------|--------|---------|
| `source` | docker, journal, file, telemetry | Distinguish ingestion path |
| `stack` | vllm, hex, host | Compose project or "host" |
| `service` | Container/unit/file name | Specific service identity |
| `component` | mcp, mcp_state, repo, tools, telemetry, security, edge, system | Functional grouping |
| `env` | sandbox, dev, prod | Environment tier |
| `level` | debug, info, warn, error | Log severity (optional, bounded) |

**Example queries enabled by planned labels:**

```logql
# All Docker logs from vllm stack
{source="docker", stack="vllm"}

# All file-based logs (MCP + tools + telemetry)
{source="file"}

# All MCP state snapshots (JSON files)
{source="file", component="mcp_state"}

# All host infrastructure logs (journald)
{source="journal", stack="host"}

# Errors from CodeSwarm MCP service
{source="file", stack="vllm", service="codeswarm-mcp", level="error"}
```

**Current limitation:** Cannot distinguish sources without parsing log content.

---

## 5. File Source Path Structure

### Current Paths (Ad-hoc)
```
/host/home/luce/_logs/*.log           → Tool sink
/host/home/luce/_telemetry/*.jsonl    → Telemetry JSONL
/host/home/luce/apps/vLLM/_data/mcp-logs/*.log → CodeSwarm MCP
```

### Planned Paths (Structured Hierarchy - Sprint-1)
```
/host-logs/mcp/*.log                  → MCP structured logs
/host-logs/mcp-state/*.json           → MCP state snapshots (MISSING)
/host-logs/vllm-repo/**/*.log         → Repo artifacts logs (MISSING)
/host-logs/vllm-repo/**/*.jsonl       → Repo artifacts JSONL (MISSING)
/host-logs/tools/*/*.log              → Tool sink
/host-logs/telemetry/*.jsonl          → Telemetry JSONL
```

**Gap:** Current uses flat `/home/luce/_*` structure. Planned uses organized `/host-logs/` hierarchy with component-based subdirs.

**Recommendation:** Migrate to planned structure OR update Alloy config to match current paths with proper labels.

---

## 6. Processing Pipeline Gaps

### Current Pipelines

**Pipeline 1: `loki.process.main`** (generic)
- Static labels: `env=sandbox`
- No redaction
- No JSON parsing
- Used by: Docker, journald, tool_sink, telemetry

**Pipeline 2: `loki.process.codeswarm`** (CodeSwarm-specific)
- Static labels: `env=sandbox`, `log_source=codeswarm_mcp`
- No redaction
- No JSON parsing
- Used by: CodeSwarm MCP logs

### Planned Pipeline (Sprint-1 Phase 9)

**Single shared pipeline with:**

1. **Redaction stage** (MISSING)
```alloy
stage.replace {
  expression = "Authorization: Bearer [A-Za-z0-9._-]+"
  replace    = "Authorization: Bearer [REDACTED]"
}
stage.replace {
  expression = "Cookie: [^\\n]+"
  replace    = "Cookie: [REDACTED]"
}
stage.replace {
  expression = "api[_-]?key[\"']?\\s*[:=]\\s*[\"']?[A-Za-z0-9._-]+"
  replace    = "api_key=[REDACTED]"
}
```

2. **Safe JSON extraction** (MISSING)
```alloy
stage.json {
  expressions = {
    level     = "level",      // Safe: bounded values
    message   = "message",    // Safe: log body
    category  = "category",   // Safe: bounded
  }
}
```

3. **Per-source static labels** (PARTIALLY IMPLEMENTED)
```alloy
stage.static_labels {
  values = {
    source    = "",  // docker | journal | file | telemetry
    stack     = "",  // vllm | hex | host
    service   = "",  // Derived from metadata
    component = "",  // mcp | repo | tools | telemetry | etc
  }
}
```

**Security risk:** Current config ships logs plain-text with no redaction. If logs contain:
- Bearer tokens
- API keys
- Cookies
- Database credentials

These will be stored in Loki unredacted.

---

## 7. Missing Log Sources (High Priority)

### MCP State Snapshots

**Planned:** `/host-logs/mcp-state/*.json`
**Labels:** `source=file, stack=vllm, service=codeswarm-mcp, component=mcp_state`

**Files expected:**
- `llm_health.json` — Health check state
- `autoheal_state.json` — Autoheal circuit breaker state
- `escalation_report.json` — Security escalation events

**Current status:** NOT CAPTURED

**Impact:** No visibility into MCP state transitions, autoheal triggers, or security escalations.

### Repo Artifacts (Logs/JSONL)

**Planned:** `/host-logs/vllm-repo/**/*.{log,jsonl}`
**Labels:** `source=file, stack=vllm, service=repo-artifacts, component=repo`

**Purpose:** Capture logs/telemetry from repo execution (build logs, test output, CI artifacts)

**Current status:** NOT CAPTURED

**Impact:** No centralized access to repo-generated logs for debugging build/test failures.

---

## 8. Telemetry-as-Logs Gap

### Current State
- Telemetry JSONL files tailed from `/home/luce/_telemetry/*.jsonl`
- Static label: `env=sandbox`
- No service-level differentiation

### Planned State (Sprint-1)

**Systemd timers writing JSONL to `/home/luce/_telemetry/`:**

| Timer | File | Cadence | Fields |
|-------|------|---------|--------|
| gpu-telemetry.timer | gpu.jsonl | 30s | ts, service, host, temperature, utilization, memory, power_draw |
| sensors-telemetry.timer | sensors.jsonl | 60s | ts, service, host, cpu_temp, gpu_temp, nvme_temp |
| host-telemetry.timer | host.jsonl | 60s | ts, service, host, disk_usage, memory, swap |
| vnstat-telemetry.timer | vnstat.jsonl | 5m | ts, service, host, network_stats |
| docker-stats-telemetry.timer | docker-stats.jsonl | 60s | ts, service, host, container_stats |
| docker-disk-telemetry.timer | docker-disk.jsonl | 10m | ts, service, host, docker_df |
| docker-events.service | docker-events.jsonl | continuous | ts, service, host, event_type, container, action |

**Current gap:** Telemetry files may exist, but Alloy config doesn't differentiate by service. All telemetry JSONL treated as one blob.

**Missing:** Extract `service` field from JSONL and apply as label for per-service filtering.

---

## 9. Label Cardinality Risk

### Current Risk: HIGH

**Unbounded streams:**
- All Docker containers (could scale to 100+ if CI/dev containers spawn)
- All journald units (50+ systemd services on typical Ubuntu host)

**Potential cardinality explosion:**
- If container names include UUIDs/timestamps → unbounded `container_name` label
- If journald includes verbose units (cron, networkd) → high event volume

### Planned Risk: LOW (with allowlists)

**Docker:**
- Allowlist: vllm + hex compose projects (~5-10 containers max)
- Exclude: infra_observability (6 containers)
- Total: ~10 containers max

**Journald:**
- Allowlist: 14 specific units (cloudflared, docker, containerd, ssh, ufw, nvidia-persistenced, thermald, smartmontools, vnstat, smbd, nmbd, cron, systemd-networkd, systemd-resolved, systemd-timesyncd)
- Total: 14 units max

**Mitigation needed:** Implement allowlists before production-scale usage to prevent cardinality explosion.

---

## 10. Implementation Roadmap

### Phase 1: Security & Filtering (HIGH PRIORITY)

1. **Add redaction pipeline** (1-2 hours)
   - Redact Bearer tokens, cookies, API keys
   - Apply to all processing pipelines
   - Test with sample logs containing secrets

2. **Implement Docker allowlist** (1 hour)
   - Filter by compose project (vllm + hex)
   - Exclude infra_observability
   - Verify with `docker compose ps`

3. **Implement journald allowlist** (1 hour)
   - Filter by 14-unit allowlist
   - Test with `journalctl -u <unit>`

**Estimated effort:** 3-4 hours
**Risk reduction:** Eliminates secret leakage + cardinality explosion

### Phase 2: Label Standardization (MEDIUM PRIORITY)

4. **Add source labels to all pipelines** (2-3 hours)
   - Docker: source="docker", stack=<project>, service=<service>
   - Journald: source="journal", stack="host", service=<unit>
   - Files: source="file", stack, service, component

5. **Add safe JSON extraction for MCP logs** (1 hour)
   - Extract: level, message, category
   - Test with actual MCP log samples

**Estimated effort:** 3-4 hours
**Query improvement:** Enable source-specific filtering

### Phase 3: Missing Log Sources (LOW PRIORITY)

6. **Add MCP state snapshots pipeline** (1 hour)
   - Path: `/home/luce/apps/vLLM/_data/mcp-state/*.json`
   - Labels: source="file", component="mcp_state"

7. **Add repo artifacts pipeline** (1 hour)
   - Path: `/home/luce/apps/vLLM/_data/vllm-repo/**/*.{log,jsonl}`
   - Labels: source="file", component="repo"

8. **Add per-service telemetry labels** (1 hour)
   - Extract `service` field from JSONL
   - Apply as label for filtering

**Estimated effort:** 3 hours
**Coverage improvement:** Capture all planned log sources

### Phase 4: Path Restructuring (OPTIONAL)

9. **Migrate to `/host-logs/` hierarchy** (2-3 hours)
   - Update host paths
   - Update Alloy file match targets
   - Update docker-compose mounts
   - Test all pipelines

**Estimated effort:** 2-3 hours
**Benefit:** Cleaner organization, aligns with Sprint-1 spec

**Total estimated effort:** 11-14 hours (Phases 1-3)

---

## 11. Configuration Diff Examples

### Docker Allowlist (Missing)

**Add to alloy-config.alloy:**
```alloy
discovery.docker "allowed" {
  host = "unix:///var/run/docker.sock"
  filter {
    name   = "label"
    values = ["com.docker.compose.project=~vllm|hex"]
  }
}

discovery.docker "excluded" {
  host = "unix:///var/run/docker.sock"
  filter {
    name   = "label"
    values = ["com.docker.compose.project=infra_observability"]
  }
}

loki.source.docker "dockerlogs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.allowed.targets
  forward_to = [loki.process.docker.receiver]
}
```

### Journald Allowlist (Missing)

**Update in alloy-config.alloy:**
```alloy
loki.source.journal "journald" {
  matches = "_SYSTEMD_UNIT=(cloudflared|docker|containerd|ssh|ufw|nvidia-persistenced|thermald|smartmontools|vnstat|smbd|nmbd|cron|systemd-networkd|systemd-resolved|systemd-timesyncd).service"
  forward_to = [loki.process.journal.receiver]
}
```

### Redaction Pipeline (Missing)

**Add to alloy-config.alloy:**
```alloy
loki.process "redact" {
  // Redact Bearer tokens
  stage.replace {
    expression = "Authorization: Bearer [A-Za-z0-9._-]+"
    replace    = "Authorization: Bearer [REDACTED]"
  }

  // Redact cookies
  stage.replace {
    expression = "Cookie: [^\\n]+"
    replace    = "Cookie: [REDACTED]"
  }

  // Redact API keys
  stage.replace {
    expression = "api[_-]?key[\"']?\\s*[:=]\\s*[\"']?[A-Za-z0-9._-]+"
    replace    = "api_key=[REDACTED]"
  }

  forward_to = [loki.process.main.receiver]
}
```

---

## 12. Testing & Validation

### After Implementing Gaps

**Test Docker allowlist:**
```bash
# Should capture vllm and hex containers only
{source="docker", stack="vllm"}
{source="docker", stack="hex"}

# Should NOT capture infra_observability containers
{source="docker", stack="infra_observability"}  # Should return no results
```

**Test journald allowlist:**
```bash
# Should capture allowed units
{source="journal", service="cloudflared.service"}
{source="journal", service="docker.service"}

# Should NOT capture non-allowed units
{source="journal", service="systemd-udevd.service"}  # Should return no results
```

**Test redaction:**
```bash
# Generate test log with secret
echo "Authorization: Bearer sk_live_abc123xyz" >> /home/luce/_logs/test.log

# Wait 15 seconds
sleep 15

# Query - should show [REDACTED]
{env="sandbox", filename=~".*test.log"} |= "Authorization"
```

**Test MCP state snapshots:**
```bash
# Should capture JSON state files
{source="file", component="mcp_state"}
```

---

## 13. Summary Table

| Category | Planned | Implemented | Missing | Priority |
|----------|---------|-------------|---------|----------|
| **Docker filtering** | Allowlist vllm+hex, exclude infra | None | 100% | **HIGH** |
| **Journald filtering** | 14-unit allowlist | None | 100% | **HIGH** |
| **Redaction** | Tokens, cookies, API keys | None | 100% | **HIGH** |
| **Docker labels** | source, stack, service | Auto-labels only | 70% | **MEDIUM** |
| **Journald labels** | source, stack, service | Auto-labels only | 85% | **MEDIUM** |
| **File labels** | source, stack, service, component | Partial (CodeSwarm) | 60% | **MEDIUM** |
| **JSON parsing** | Safe field extraction | None | 100% | **MEDIUM** |
| **MCP state logs** | /mcp-state/*.json | Not captured | 100% | **LOW** |
| **Repo artifacts** | /vllm-repo/**/*.log | Not captured | 100% | **LOW** |
| **Telemetry labels** | Per-service differentiation | Static only | 75% | **LOW** |

**Overall completion: ~35%**

---

## 14. Recommended Next Steps

1. **Immediate (Security):**
   - Implement redaction pipeline (prevent secret leakage)
   - Add Docker allowlist (prevent cardinality explosion)
   - Add journald allowlist (reduce noise)

2. **Short-term (Usability):**
   - Standardize labels across all sources
   - Add safe JSON extraction for MCP logs
   - Test query patterns with new labels

3. **Long-term (Completeness):**
   - Add MCP state snapshots pipeline
   - Add repo artifacts pipeline
   - Add per-service telemetry labels
   - Consider migrating to `/host-logs/` path structure

4. **Documentation:**
   - Update [operations.md](operations.md) with new label schema
   - Update [reference.md](reference.md) with complete label list
   - Add query examples using source-specific labels

---

**Last updated:** 2026-02-13
**Reference:** _build/Sprint-1/Loki-logging-1.md (Phase 9 specification)
