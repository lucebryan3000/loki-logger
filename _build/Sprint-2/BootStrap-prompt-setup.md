# Bootstrap Prompt Generator Setup

**Created:** 2026-02-13
**Purpose:** Generate sequential, executable prompts to create a generic logging bootstrap system
**Source Material:** Sprint-1 deployment + BootStrap-logging-plan.md
**Output:** Sequential prompts in `_build/Sprint-2/` as `Sprint-2-bootstrap-01.md`, `Sprint-2-bootstrap-02.md`, etc.

---

## Context

You are creating a **generic, reusable logging bootstrap system** based on the successfully deployed Loki logging stack at `/home/luce/apps/loki-logging`.

**Current deployment (your baseline):**
- Grafana + Loki + Alloy + Prometheus + Node Exporter + cAdvisor
- LAN-accessible (0.0.0.0 binding) on headless Ubuntu host
- 30-day log retention, 15-day metrics retention
- Docker Compose project: `infra_observability`
- UFW firewall rules for ports 9001 (Grafana), 9004 (Prometheus)
- Comprehensive documentation in `/docs`

**Source files to study:**
- `_build/Sprint-1/Loki-logging-1.md` — Original deployment specification
- `_build/Sprint-2/BootStrap-logging-plan.md` — Bootstrap requirements
- Current canonical configs:
  - `infra/logging/docker-compose.observability.yml`
  - `infra/logging/alloy-config.alloy`
  - `infra/logging/loki-config.yml`
  - `infra/logging/prometheus/prometheus.yml`
  - `infra/logging/.env.example`
- Current scripts:
  - `scripts/mcp/logging_stack_up.sh`
  - `scripts/mcp/logging_stack_down.sh`
  - `scripts/mcp/logging_stack_health.sh`
  - `scripts/prism/evidence.sh`
- Documentation: `docs/**`

---

## Your Task

Generate **5-7 sequential prompts** (Sprint-2-bootstrap-01.md through Sprint-2-bootstrap-07.md) that:

1. **Are independently executable** — Each prompt can be run in isolation by Claude/Codex
2. **Build incrementally** — Each prompt depends only on previous prompts' outputs
3. **Are project-agnostic** — Use config-driven approach, not hardcoded paths
4. **Include validation loops** — Test → validate → fix → redeploy until error-free
5. **Include reference documentation** — Pull authoritative deployment guides

---

## Output Structure

Each prompt file should follow this structure:

```markdown
---
chatgpt_scoping_kind: task
chatgpt_scoping_scope: multi-file
chatgpt_scoping_targets_root: _build/Logging-Bootstrap/
chatgpt_scoping_targets:
  - [specific output files this prompt creates]
---

# Sprint-2-bootstrap-XX: [Clear Title]

## Context
[What has been done so far, what this prompt builds on]

## Inputs
[Files/configs this prompt reads]

## Outputs
[Files this prompt creates under _build/Logging-Bootstrap/]

## Task
[Specific, executable instructions]

## Validation
[How to verify this step succeeded]

## Next Step
[What the next prompt will do]
```

---

## Suggested Prompt Sequence

### Sprint-2-bootstrap-01.md: Foundation & Reference Collection
**Purpose:** Create directory structure, collect authoritative deployment guides, establish config schema

**Outputs:**
- `_build/Logging-Bootstrap/README.md` (overview)
- `_build/Logging-Bootstrap/references/` directory
  - `grafana-docker-install.md` (from https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/)
  - `loki-docker-install.md` (from https://grafana.com/docs/loki/latest/setup/install/docker/)
  - `alloy-install.md` (from https://grafana.com/docs/alloy/latest/set-up/install/)
  - `prometheus-install.md` (from https://prometheus.io/docs/prometheus/latest/installation/)
  - `node-exporter-guide.md` (from https://prometheus.io/docs/guides/node-exporter/)
  - `cadvisor-guide.md` (from https://github.com/google/cadvisor)
- `_build/Logging-Bootstrap/config/bootstrap.schema.json`
- `_build/Logging-Bootstrap/config/bootstrap.example.json`
- `_build/Logging-Bootstrap/config/bootstrap.test.json` (TEST values, not production)
- `.gitignore` updates for `bootstrap.local.json`, `bootstrap.test.json`

**Key points:**
- Fetch actual documentation from upstream sources (use WebFetch or provide URLs for manual collection)
- Create generic config schema based on current `.env` + compose file
- Use TEST values (different ports, different project name) to avoid conflicting with production deployment

---

### Sprint-2-bootstrap-02.md: Preflight Validator
**Purpose:** Create preflight validation script that checks environment readiness

**Outputs:**
- `_build/Logging-Bootstrap/bin/bootstrap_preflight.py`
- `_build/Logging-Bootstrap/tests/test_preflight.sh` (self-test)
- `_build/Logging-Bootstrap/out/preflight.report.json` (example output)

**Validation checks:**
- Docker daemon reachable
- Required tools present (jq, curl, docker compose)
- Config file validates against schema
- Required directories exist or can be created
- No port conflicts for configured ports
- UFW status (if applicable)
- journald persistence posture

**Key points:**
- Use JSON schema validation
- Exit codes: 0=success, 2=blocker
- Produce structured JSON report
- No secrets printed

---

### Sprint-2-bootstrap-03.md: Template Generator
**Purpose:** Generate canonical config files from config schema + upstream templates

**Outputs:**
- `_build/Logging-Bootstrap/bin/generate_configs.py`
- `_build/Logging-Bootstrap/templates/docker-compose.observability.yml.j2` (Jinja2 template)
- `_build/Logging-Bootstrap/templates/loki-config.yml.j2`
- `_build/Logging-Bootstrap/templates/alloy-config.alloy.j2`
- `_build/Logging-Bootstrap/templates/prometheus.yml.j2`
- `_build/Logging-Bootstrap/templates/.env.j2`
- Test run: generate to `_build/Logging-Bootstrap/test-output/`

**Key points:**
- Based on current working configs in `infra/logging/`
- Use Jinja2 for templating (portable, well-documented)
- Generate from `bootstrap.test.json` for validation
- Never hardcode paths/ports

---

### Sprint-2-bootstrap-04.md: Apply Script
**Purpose:** Idempotent deployment script that applies generated configs

**Outputs:**
- `_build/Logging-Bootstrap/bin/bootstrap_apply.sh`
- `_build/Logging-Bootstrap/out/apply.report.json` (example)

**Actions:**
- Create required directories (logs, telemetry, etc.)
- Generate configs from templates
- Create `.env` with generated secrets (never print)
- `docker compose up -d`
- Wait for containers to start
- Produce apply report

**Key points:**
- Idempotent (safe to re-run)
- Uses TEST config initially
- No secrets in stdout/logs
- Handles both fresh deploy and redeploy

---

### Sprint-2-bootstrap-05.md: Verification & Proofs
**Purpose:** Semantic validation that deployment actually works

**Outputs:**
- `_build/Logging-Bootstrap/bin/bootstrap_verify.py`
- `_build/Logging-Bootstrap/out/verify.report.json` (example)

**Validation proofs:**
- L1: Service health (Grafana /api/health, Prometheus /-/ready)
- L2: Loki queryable from Docker network
- L3: Log ingestion proof (write test log, query after delay)
- L4: Label contract validation (required labels present)
- L5: Dashboards provisioned
- L6: Prometheus rules loaded

**Key points:**
- Use disposable curl container for Loki queries
- Write unique markers with timestamps
- Wait for ingestion (10-15s delay)
- Exit non-zero if required proofs fail

---

### Sprint-2-bootstrap-06.md: Orchestrator & Auto-Heal
**Purpose:** LLM-assisted failure remediation system

**Outputs:**
- `_build/Logging-Bootstrap/orchestrator/LLM_ORCHESTRATOR.md` (prompt template)
- `_build/Logging-Bootstrap/orchestrator/autoheal_scan.py` (failure classifier)
- `_build/Logging-Bootstrap/out/autoheal.suggestions.json` (example)

**Approach:**
- Scripts classify failures (config/env/runtime/proof buckets)
- LLM orchestrator proposes fixes (one phase at a time)
- Operator reviews and applies
- Re-run bootstrap_run.sh

**Key points:**
- LLM does planning/decisions, scripts do mechanics
- Bounded remediation (not "fix everything")
- Structured failure buckets
- Clear next-step guidance

---

### Sprint-2-bootstrap-07.md: Test Loop & Final Integration
**Purpose:** Iterative deploy-test-fix loop until error-free

**Outputs:**
- `_build/Logging-Bootstrap/bin/bootstrap_run.sh` (all-in-one runner)
- `_build/Logging-Bootstrap/bin/test_loop.sh` (deploy-verify-cleanup cycle)
- `_build/Logging-Bootstrap/DEPLOYMENT.md` (complete guide)
- `_build/Logging-Bootstrap/out/bootstrap.summary.json`
- `_build/Logging-Bootstrap/out/bootstrap.summary.md`

**Test loop:**
```bash
# 1. Deploy with TEST config
./bin/bootstrap_run.sh --config config/bootstrap.test.json

# 2. If verify fails, classify and suggest
./orchestrator/autoheal_scan.py

# 3. Fix issue (manual or LLM-assisted)

# 4. Clean up test deployment
./bin/bootstrap_cleanup.sh --config config/bootstrap.test.json

# 5. Re-run from step 1
# Repeat until verify.report.json shows all proofs green
```

**Key points:**
- Complete end-to-end workflow
- Cleanup script for test deployments
- Summary reports (JSON + Markdown)
- Ready for production use after test loop passes

---

## Execution Instructions

For each prompt you generate:

1. **Read the relevant sections** of Sprint-1 and current configs
2. **Create a standalone prompt** following the structure above
3. **Include specific file paths and outputs**
4. **Add validation criteria**
5. **Link to next prompt**

**Save each prompt as:**
- `_build/Sprint-2/Sprint-2-bootstrap-01.md`
- `_build/Sprint-2/Sprint-2-bootstrap-02.md`
- ... and so on

**Test config values to use** (avoid conflicts with production):
```json
{
  "compose_project_name": "logging_test",
  "ports": {
    "grafana": 9101,
    "prometheus": 9104
  },
  "paths": {
    "logs_root": "/home/luce/_logs_test",
    "telemetry_root": "/home/luce/_telemetry_test"
  }
}
```

---

## Quality Gates

Each generated prompt must:

- [ ] Be executable without human intervention (except config editing)
- [ ] Produce deterministic outputs
- [ ] Include validation criteria
- [ ] Reference authoritative upstream docs
- [ ] Use config-driven approach (no hardcoded values)
- [ ] Handle both fresh install and redeploy
- [ ] Never print secrets
- [ ] Exit with meaningful codes (0=success, 1=soft fail, 2=blocker)

---

## Constraints

**MUST NOT:**
- Modify current production deployment
- Use production ports/paths in test config
- Print secrets to stdout/logs
- Embed heredocs in prompts
- Create brittle path dependencies

**MUST:**
- Use TEST config values initially
- Be idempotent (safe to re-run)
- Produce structured JSON reports
- Include cleanup scripts
- Provide clear error messages

---

## Success Criteria

After running all 7 prompts sequentially:

1. `_build/Logging-Bootstrap/` contains complete bootstrap system
2. Test deployment succeeds with `bootstrap.test.json`
3. All verification proofs pass
4. Deployment can be cleaned up and re-run
5. Documentation is complete and accurate
6. System is ready for production use with `bootstrap.local.json`

---

## Next Steps

1. Generate `Sprint-2-bootstrap-01.md` through `Sprint-2-bootstrap-07.md`
2. Each prompt should be ~200-400 lines
3. Include bash/python code snippets inline
4. Reference current working configs as examples
5. Ensure generic applicability (not Luce-specific)

---

**Execute:** Generate the 7 sequential bootstrap prompts now.
