# Bootstrap Prompt Generator Setup

**Created:** 2026-02-13
**Purpose:** Generate sequential, executable prompts to create a generic logging bootstrap system
**Source Material:** Sprint-1 deployment + BootStrap-logging-plan.md
**Output:** Sequential prompts in `_build/Sprint-2/` as `Sprint-2-bootstrap-01.md` through `Sprint-2-bootstrap-09.md`

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

## Engineering Principles

These 20 concerns are **mandatory requirements** woven through every prompt. Each prompt must identify which concerns it addresses.

### P1. Desired-State Snapshot
Every bootstrap run begins by computing SHA-256 checksums of canonical repo config files and recording them in `desired_state.json`. Apply verifies no drift from this snapshot before mutating. Verify compares host file SHAs against in-container mounted file SHAs for critical configs.

### P2. Versioned Bootstrap Contract
`bootstrap.version` and `schema_version` fields in config. A `bin/migrate.py` script upgrades config from older schema versions. Breaking changes increment major version and refuse to run without migration.

### P3. Deterministic Health Model
One `contracts/health_contract.json` describes every health endpoint: URL pattern, expected HTTP status, timeout, retries, backoff, and "green" criteria. All health checks in preflight/verify read from this contract — no ad-hoc curl calls.

### P4. Error Taxonomy & Bucketed Auto-Heal
Six error buckets: `env`, `config`, `runtime`, `network`, `proof`, `deps`. Every error emitted by any script carries a `bucket` field and a standardized error code (e.g., `E_CONFIG_MISSING_KEY`, `E_RUNTIME_PORT_CONFLICT`). Autoheal emits one recommended next-action per bucket.

### P5. Atomic Apply with Rollback
Apply operates in stages: (1) snapshot current state, (2) generate configs, (3) write configs to staging dir, (4) swap into place, (5) `docker compose up`. If any stage fails, `rollback.sh` restores last-known-good snapshot. State checkpoints saved to `out/checkpoints/`.

### P6. Idempotency Verification
After the test loop passes, run apply a second time. The second run must be a no-op (or only benign container restarts). Verify must produce identical outcomes both times. Differences are reported as idempotency violations.

### P7. Drift Detection (Host ↔ Container)
For every config file mounted into a container, compare the host-side SHA with the in-container SHA (via `docker exec sha256sum`). Mismatches indicate stale container mounts. Report in verify output.

### P8. Secrets Lifecycle & Storage Standard
One `secrets.local.env` file (mode 600, gitignored). A `secrets.example.env` with placeholder values. `bin/generate_secrets.sh` creates random secrets. Evidence output includes only redacted values (`***REDACTED***`). Permission checks verify mode 600. Never print, log, or embed secrets in reports.

### P9. Portability Layer
Config contains a `path_map` section with named paths. All scripts resolve paths through config — zero hardcoded paths in any script. `--dry-run` mode prints resolved path map without executing. Preflight validates all mapped paths exist (or flags which are missing and whether they're required vs optional).

### P10. Dependency Pinning & Provenance
All container images pinned to exact tags in config (no `latest`). After pull, record `image:tag -> sha256:digest` in `out/provenance.json`. Preflight warns if any image uses `:latest`. Verify confirms running container digests match provenance.

### P11. Offline-Friendly Mode
Config toggle `offline_mode: true`. In this mode, preflight checks that all images exist locally (`docker image inspect`). Apply skips `docker compose pull`. A `bin/export_images.sh` saves images to tarballs; `bin/import_images.sh` loads them. Preflight in offline mode checks tarballs exist if images are missing.

### P12. Structured Evidence Output
One run bundle directory per execution: `out/runs/<timestamp>/`. Each bundle contains all reports for that run. An append-only `out/runs.jsonl` indexes every run with timestamp, status, and report paths. A `bin/recall.sh` CLI queries past runs by status, date range, or error bucket.

### P13. Semantic API Validation (No Grep)
All API responses parsed as JSON. Check `status` fields, HTTP codes, array lengths, and explicit marker presence in structured data. No `grep`, `rg`, or string matching on API responses. Helper functions: `assert_json_field(response, path, expected)`, `assert_http_status(url, expected_code)`.

### P14. Time-Window Correctness
Proof helpers recompute `end` timestamp on each retry (never frozen). Enforce max wall-clock timeout (configurable, default 120s). On timeout, emit partial diagnostics showing what was found vs expected. Log each retry attempt with timestamps.

### P15. Self-Ingestion & Cardinality Controls
Verify checks that Alloy config includes Docker container allowlists and journald unit allowlists. Verify checks label cardinality (no labels with >100 unique values). Verify checks that a redaction stage exists in the Alloy pipeline (or documents its absence as an acknowledged risk).

### P16. Policy-Driven Execution Modes
Three modes: `diagnose` (read-only, no mutations), `apply` (full deployment), `repair` (targeted fixes only). Each mode has an allowed command set. Running `apply` commands in `diagnose` mode is a hard error. Mode is set via `--mode` flag and recorded in every report.

### P17. Interactive-Step Elimination
All commands must be non-interactive. Preflight scans all scripts for interactive patterns (`read -p`, `select`, stdin prompts) and flags them. Any command that would prompt must hard-fail unless `--interactive yes` is explicitly passed. Default is non-interactive.

### P18. Concurrency Lock
`flock`-based lockfile at `out/.bootstrap.lock` around apply and verify. If a second instance tries to run, it gets a clear error: "Another bootstrap run is active (PID XXXX)". Lock is released on exit (including abnormal exit via trap).

### P19. Config Lint & Semantic Validation Gate
JSON Schema validation is necessary but not sufficient. A semantic validator checks: port ranges valid (1024-65535), paths are absolute, project name is DNS-safe, image tags don't use `:latest`, required toggles are boolean, secrets policy is set. On failure, emit targeted messages with example patches showing the fix.

### P20. LLM Orchestration Boundaries
The orchestrator MUST NOT execute commands. Its job is: (a) read reports from `out/`, (b) classify failures using error taxonomy, (c) propose a patch plan as structured JSON, (d) generate a single next prompt for the operator to execute. Scripts execute deterministic mechanics; LLM decides what to change next. The orchestrator template explicitly lists what it MAY and MUST NOT do.

---

## Your Task

Generate **9 sequential prompts** (Sprint-2-bootstrap-01.md through Sprint-2-bootstrap-09.md) that:

1. **Are independently executable** — Each prompt can be run in isolation by Claude/Codex
2. **Build incrementally** — Each prompt depends only on previous prompts' outputs
3. **Are project-agnostic** — Use config-driven approach, not hardcoded paths
4. **Include validation loops** — Test → validate → fix → redeploy until error-free
5. **Include reference documentation** — Pull authoritative deployment guides
6. **Address all 20 engineering principles** — Tag each prompt with which Pxx it covers

---

## Output Structure

Each prompt file MUST follow this structure:

```markdown
---
chatgpt_scoping_kind: task
chatgpt_scoping_scope: multi-file
chatgpt_scoping_targets_root: _build/Logging-Bootstrap/
chatgpt_scoping_targets:
  - [specific output files this prompt creates]
principles_addressed:
  - [P1, P2, ... which of the 20 principles this prompt implements]
---

# Sprint-2-bootstrap-XX: [Clear Title]

## Principles Addressed
[Table mapping Pxx → what this prompt does for it]

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

## Prompt Sequence

### Sprint-2-bootstrap-01.md: Foundation, Contracts & Reference Collection

**Principles:** P1, P2, P3, P4, P8, P9, P10, P19

**Purpose:** Create directory structure, define all contracts, collect reference docs, establish config schema with full semantic validation.

**Outputs:**
- `_build/Logging-Bootstrap/README.md` (overview, architecture, principles)
- `_build/Logging-Bootstrap/references/` directory with authoritative deployment guides:
  - `grafana-docker-install.md` (from https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/)
  - `loki-docker-install.md` (from https://grafana.com/docs/loki/latest/setup/install/docker/)
  - `alloy-install.md` (from https://grafana.com/docs/alloy/latest/set-up/install/)
  - `prometheus-install.md` (from https://prometheus.io/docs/prometheus/latest/installation/)
  - `node-exporter-guide.md` (from https://prometheus.io/docs/guides/node-exporter/)
  - `cadvisor-guide.md` (from https://github.com/google/cadvisor)
- **Contracts:**
  - `_build/Logging-Bootstrap/contracts/health_contract.json` — Every health endpoint, expected codes, timeouts, retries, green criteria (P3)
  - `_build/Logging-Bootstrap/contracts/error_taxonomy.json` — Six buckets (env/config/runtime/network/proof/deps), standardized error codes, descriptions, suggested actions (P4)
  - `_build/Logging-Bootstrap/contracts/secrets_policy.json` — Where secrets live, mode requirements, redaction rules, generation method (P8)
- **Config:**
  - `_build/Logging-Bootstrap/config/bootstrap.schema.json` — JSON Schema with semantic constraints (P19)
  - `_build/Logging-Bootstrap/config/bootstrap.example.json` — Full example with all fields
  - `_build/Logging-Bootstrap/config/bootstrap.test.json` — TEST values (different ports/paths/project name)
  - Config must include: `bootstrap_version`, `schema_version`, `path_map` (P9), `image_pins` with exact tags (P10), `offline_mode` toggle, `execution_mode` field, `secrets_policy` reference
- **Utilities:**
  - `_build/Logging-Bootstrap/bin/migrate.py` — Config migration between schema versions (P2)
  - `_build/Logging-Bootstrap/bin/config_lint.py` — Semantic validation beyond JSON Schema (P19): port ranges, absolute paths, DNS-safe names, no `:latest` tags, boolean toggles. Emits targeted error messages with example patches.
- `.gitignore` updates for `bootstrap.local.json`, `secrets.local.env`, `out/`

**Key design decisions:**
- `path_map` in config replaces all hardcoded paths. Every script resolves paths via `path_map`. (P9)
- `image_pins` section lists every image with exact tag. No `:latest` anywhere. (P10)
- `desired_state.json` format defined (generated at runtime, not committed). Records SHA-256 of each canonical config file. (P1)
- Error taxonomy is the single source of truth for all error codes across all scripts. (P4)
- Health contract is the single source of truth for all health checks. (P3)

---

### Sprint-2-bootstrap-02.md: Preflight Validator

**Principles:** P1, P7, P9, P10, P11, P17, P18, P19

**Purpose:** Create comprehensive preflight validation that checks environment readiness, config correctness, and detects drift.

**Outputs:**
- `_build/Logging-Bootstrap/bin/bootstrap_preflight.py`
- `_build/Logging-Bootstrap/bin/lib/config_loader.py` — Shared config loading + schema validation + semantic lint (P19)
- `_build/Logging-Bootstrap/bin/lib/desired_state.py` — Compute and compare SHA-256 checksums of canonical files (P1)
- `_build/Logging-Bootstrap/bin/lib/error_emitter.py` — Emit errors using taxonomy codes and buckets (P4)
- `_build/Logging-Bootstrap/bin/lib/lockfile.py` — flock-based concurrency guard (P18)
- `_build/Logging-Bootstrap/tests/test_preflight.sh` (self-test)

**Preflight checks (in order):**
1. **Concurrency lock** — Acquire `out/.bootstrap.lock` via flock; refuse if locked (P18)
2. **Config load + schema validate + semantic lint** — Full validation pipeline (P19)
3. **Schema version check** — If config `schema_version` < current, prompt to run `migrate.py` (P2)
4. **Path map resolution** — Resolve all `path_map` entries; report missing required vs optional paths (P9)
5. **Docker daemon reachable** — `docker info`
6. **Required tools present** — `jq`, `curl`, `docker compose`, `python3`, `flock`
7. **Port conflict check** — `ss -tln` for configured ports; flag conflicts with running services
8. **Image availability** — If `offline_mode: true`, verify images exist locally; else verify pullable (P11)
9. **Image tag check** — Warn on `:latest` tags (P10)
10. **Desired state snapshot** — Compute SHA-256 of all canonical config files; save to `out/desired_state.json` (P1)
11. **Drift detection** — If previous `desired_state.json` exists, compare; report changed files (P1, P7)
12. **Secrets file check** — Verify `secrets.local.env` exists with mode 600, or flag as needed (P8)
13. **UFW status** — Check firewall posture
14. **journald persistence** — Check `/var/log/journal` exists
15. **Interactive command scan** — Scan all bin/ scripts for interactive patterns (P17)
16. **Execution mode validation** — Verify `--mode` flag is valid (`diagnose`/`apply`/`repair`) (P16)

**Report output:** `out/runs/<timestamp>/preflight.report.json`
- All checks with pass/fail/warn status
- Error codes from taxonomy (P4)
- Resolved path map for operator review (P9)
- Desired state checksums (P1)
- Exit codes: 0=green, 1=warnings only, 2=blocker

**Key points:**
- `--dry-run` prints resolved path map without executing checks (P9)
- `--mode diagnose` is the default for preflight (P16)
- Every error carries a bucket + code from `error_taxonomy.json` (P4)
- No secrets printed in any output (P8)

---

### Sprint-2-bootstrap-03.md: Template Generator & Dependency Pinning

**Principles:** P1, P9, P10, P11

**Purpose:** Generate canonical config files from templates using config values. Pin dependencies and record provenance.

**Outputs:**
- `_build/Logging-Bootstrap/bin/generate_configs.py`
- `_build/Logging-Bootstrap/bin/export_images.sh` — Save pinned images to tarballs for offline use (P11)
- `_build/Logging-Bootstrap/bin/import_images.sh` — Load images from tarballs (P11)
- `_build/Logging-Bootstrap/templates/` — Jinja2 templates:
  - `docker-compose.observability.yml.j2`
  - `loki-config.yml.j2`
  - `alloy-config.alloy.j2`
  - `prometheus.yml.j2`
  - `.env.j2`
  - `secrets.local.env.j2`
- `_build/Logging-Bootstrap/bin/generate_secrets.sh` — Create random secrets (P8)

**Template design:**
- Based on current working configs in `infra/logging/`
- All paths resolved from `path_map` (P9)
- All image tags from `image_pins` (P10)
- All ports from `ports` config section
- Never hardcode any value that exists in config

**Dependency pinning workflow (P10):**
1. `generate_configs.py` reads `image_pins` from config
2. Pulls each image (unless `offline_mode`)
3. Records `image:tag -> sha256:digest` in `out/runs/<timestamp>/provenance.json`
4. Template generates compose file with pinned tags

**Offline mode (P11):**
- `export_images.sh` saves all pinned images to `_build/Logging-Bootstrap/images/` as `.tar.gz`
- `import_images.sh` loads from tarballs
- Preflight in offline mode checks tarballs exist

**Desired state update (P1):**
- After generating configs to staging dir, compute SHA-256 of generated files
- Record in `out/runs/<timestamp>/generated_state.json`

**Key points:**
- Generate to `_build/Logging-Bootstrap/staging/` first, not directly to target
- Use Jinja2 (portable, well-documented, pip installable)
- Test run: generate from `bootstrap.test.json` and validate output

---

### Sprint-2-bootstrap-04.md: Atomic Apply with Rollback

**Principles:** P1, P5, P6, P7, P8, P16, P18

**Purpose:** Idempotent, atomic deployment with staged checkpoints and rollback capability.

**Outputs:**
- `_build/Logging-Bootstrap/bin/bootstrap_apply.sh`
- `_build/Logging-Bootstrap/bin/rollback.sh` — Restore last-known-good state (P5)
- `_build/Logging-Bootstrap/bin/lib/checkpoint.sh` — Stage/commit/rollback helpers (P5)

**Apply stages (P5):**
```
Stage 0: Acquire lock (P18)
Stage 1: Snapshot current state
         - Capture running container list, config SHAs, compose state
         - Save to out/checkpoints/<timestamp>/snapshot.json
Stage 2: Generate configs (calls generate_configs.py)
         - Output to staging/ directory
Stage 3: Validate staging
         - Diff staging vs current configs
         - SHA comparison for drift detection (P7)
         - If --mode diagnose: stop here, print diff, exit 0 (P16)
Stage 4: Write configs
         - Atomic swap: staging/ → target location
         - Generate secrets.local.env if missing (P8)
         - Verify mode 600 on secrets file (P8)
Stage 5: Docker compose up
         - docker compose -f <generated_compose> up -d
         - Wait for containers (configurable timeout from health_contract)
Stage 6: Post-apply drift check
         - Compare host file SHA ↔ in-container mounted file SHA (P7)
         - Report mismatches
Stage 7: Checkpoint commit
         - Record successful state to out/checkpoints/<timestamp>/committed.json
         - Release lock (P18)
```

**Rollback (P5):**
- `rollback.sh` reads latest checkpoint from `out/checkpoints/`
- Restores config files from snapshot
- Runs `docker compose down` + `docker compose up -d` with restored configs
- Produces `out/runs/<timestamp>/rollback.report.json`

**Idempotency contract (P6):**
- Second run of apply with unchanged config MUST produce no meaningful changes
- "Benign restarts" are allowed (container recreation with same config)
- Verify outcomes must be identical between first and second run

**Execution modes (P16):**
- `--mode diagnose`: Stages 0-3 only (read-only, shows what would change)
- `--mode apply`: All stages (full deployment)
- `--mode repair`: Stages 0, 2-6 (skip snapshot, assume fixing a known issue)

**Key points:**
- Every stage produces a checkpoint; failure at any stage triggers rollback
- Secrets never appear in reports, logs, or diffs (P8)
- `--dry-run` is equivalent to `--mode diagnose`
- Lock prevents concurrent apply (P18)

---

### Sprint-2-bootstrap-05.md: Verification & Proofs

**Principles:** P3, P7, P10, P13, P14, P15

**Purpose:** Semantic validation that deployment actually works. JSON-parsed API responses, correct time windows, cardinality controls.

**Outputs:**
- `_build/Logging-Bootstrap/bin/bootstrap_verify.py`
- `_build/Logging-Bootstrap/bin/lib/health_checker.py` — Reads health_contract.json, executes checks (P3)
- `_build/Logging-Bootstrap/bin/lib/api_validator.py` — Semantic JSON response validation (P13)
- `_build/Logging-Bootstrap/bin/lib/proof_helper.py` — Time-window-correct ingestion proofs (P14)
- `_build/Logging-Bootstrap/bin/lib/cardinality_checker.py` — Label cardinality + allowlist checks (P15)

**Verification levels:**

**L1: Service Health (P3)**
- Read endpoints from `contracts/health_contract.json`
- For each endpoint: HTTP request → parse JSON response → check status field → check expected code
- Use contract-defined timeout, retries, backoff
- No ad-hoc curl: use `health_checker.py` which reads the contract

**L2: Loki Reachability (P13)**
- Disposable curl container on Docker network
- Parse JSON response from Loki `/ready` endpoint
- Assert `ready` field, not grep for string

**L3: Log Ingestion Proof (P13, P14)**
- Write unique timestamped marker to test log file
- Query Loki via API: parse JSON response, check `data.result` array length > 0
- Check marker appears in `values` array of stream results
- **Time window (P14):** Recompute `end` timestamp on each retry. Never frozen. Max wall-clock timeout from config (default 120s). On timeout, emit partial diagnostics: what query was run, what was returned, timestamps of each retry.

**L4: Label Contract (P13, P15)**
- Query Loki `/loki/api/v1/labels` — parse JSON, assert required labels exist
- Query Loki `/loki/api/v1/label/<name>/values` for high-cardinality labels
- Flag labels with >100 unique values (P15)
- Check Alloy config includes Docker container allowlist (P15)
- Check Alloy config includes journald unit allowlist (P15)
- Check for redaction stage in Alloy pipeline (P15) — report absence as acknowledged risk

**L5: Dashboard Provisioning**
- Check dashboard files exist on disk
- Query Grafana API `/api/search?type=dash-db` — parse JSON, count dashboards

**L6: Prometheus Rules**
- Query Prometheus `/api/v1/rules` — parse JSON, check `data.groups` array
- Assert expected rule group names present

**L7: Provenance Verification (P10)**
- For each running container, get image digest via `docker inspect`
- Compare against `out/runs/<timestamp>/provenance.json`
- Report mismatches (image was updated outside bootstrap)

**L8: Config Drift Detection (P7)**
- For each config file mounted into a container:
  - Compute host-side SHA: `sha256sum <host_path>`
  - Compute container-side SHA: `docker exec <container> sha256sum <mount_path>`
  - Compare; report mismatches

**Report output:** `out/runs/<timestamp>/verify.report.json`
- Every check with pass/fail/warn + evidence
- Error codes from taxonomy (P4)
- Partial diagnostics on timeout (P14)
- Exit codes: 0=all green, 1=warnings, 2=critical failure

---

### Sprint-2-bootstrap-06.md: Orchestrator, Auto-Heal & Execution Modes

**Principles:** P4, P16, P20

**Purpose:** LLM-assisted failure remediation with strict boundaries. Error taxonomy classification. Policy-driven execution modes.

**Outputs:**
- `_build/Logging-Bootstrap/orchestrator/LLM_ORCHESTRATOR.md` — Prompt template with explicit MAY/MUST NOT boundaries (P20)
- `_build/Logging-Bootstrap/orchestrator/autoheal_scan.py` — Reads reports, classifies into taxonomy buckets, emits one next-action per bucket (P4)
- `_build/Logging-Bootstrap/bin/lib/mode_guard.py` — Enforces execution mode policies (P16)

**Error taxonomy integration (P4):**
- `autoheal_scan.py` reads all reports from latest run bundle
- Maps every error to its taxonomy bucket (env/config/runtime/network/proof/deps)
- For each active bucket, emits exactly one recommended next-action
- Output: `out/runs/<timestamp>/autoheal.suggestions.json`
- Structure:
  ```json
  {
    "run_id": "<timestamp>",
    "active_buckets": [
      {
        "bucket": "config",
        "error_codes": ["E_CONFIG_MISSING_KEY", "E_CONFIG_INVALID_PORT"],
        "count": 2,
        "recommended_action": "Edit bootstrap config: set paths.logs_root to an absolute path",
        "example_patch": {"paths": {"logs_root": "/var/log/myapp"}}
      }
    ],
    "resolved_buckets": ["env", "runtime", "network", "proof", "deps"]
  }
  ```

**LLM Orchestrator boundaries (P20):**
The orchestrator template MUST include:

```
## What the Orchestrator MAY Do
- Read report files from out/runs/<latest>/
- Classify failures using error_taxonomy.json
- Propose a patch plan as structured JSON
- Generate a single next prompt for the operator to execute
- Suggest config changes with example values
- Recommend which mode (diagnose/apply/repair) to use next

## What the Orchestrator MUST NOT Do
- Execute any commands (no bash, no docker, no file writes)
- Modify any files directly
- Make decisions that bypass the operator
- Propose changes to multiple buckets in one step
- Generate unbounded fix-all plans
- Access secrets or .env files

## Output Contract
The orchestrator produces exactly:
1. A root-cause classification (one primary bucket)
2. A proposed patch (JSON diff or config edit)
3. A single next command to run
4. Expected outcome of that command
```

**Execution modes (P16):**
- `mode_guard.py` enforces allowed commands per mode:
  - `diagnose`: read-only commands only (ls, cat, docker inspect, curl, sha256sum)
  - `apply`: all commands allowed
  - `repair`: targeted commands (docker restart, config write, compose up — but not compose down + destroy)
- Any command not in the mode's allow-list raises a hard error with the taxonomy code `E_ENV_MODE_VIOLATION`

---

### Sprint-2-bootstrap-07.md: Evidence System & Recall

**Principles:** P12, P14

**Purpose:** Structured evidence output with run bundles, append-only indexes, and a recall CLI.

**Outputs:**
- `_build/Logging-Bootstrap/bin/lib/evidence.py` — Run bundle manager
- `_build/Logging-Bootstrap/bin/recall.sh` — Query past runs (P12)
- `_build/Logging-Bootstrap/out/runs.jsonl` — Append-only run index

**Run bundle structure (P12):**
```
out/
├── runs.jsonl                          # Append-only index of all runs
├── .bootstrap.lock                     # Concurrency lockfile
└── runs/
    └── 2026-02-13T14-30-00/           # One directory per run
        ├── meta.json                   # Run metadata (mode, config, duration, status)
        ├── preflight.report.json
        ├── desired_state.json
        ├── generated_state.json
        ├── provenance.json
        ├── apply.report.json
        ├── verify.report.json
        ├── autoheal.suggestions.json
        ├── summary.json
        └── summary.md
```

**runs.jsonl format (P12):**
Each line is a JSON object:
```json
{"run_id": "2026-02-13T14-30-00", "mode": "apply", "status": "green", "errors": 0, "warnings": 2, "duration_s": 45, "config": "bootstrap.test.json"}
```

**recall.sh CLI (P12):**
```bash
# List all runs
./bin/recall.sh list

# Show last run
./bin/recall.sh latest

# Filter by status
./bin/recall.sh list --status red

# Filter by date range
./bin/recall.sh list --since 2026-02-10 --until 2026-02-14

# Filter by error bucket
./bin/recall.sh list --bucket config

# Show specific run detail
./bin/recall.sh show 2026-02-13T14-30-00

# Export run as tar.gz
./bin/recall.sh export 2026-02-13T14-30-00
```

**Time-window diagnostics (P14):**
- Every retry in proof_helper.py logs: `{"attempt": N, "query": "...", "start_ns": X, "end_ns": Y, "result_count": Z, "wall_clock_s": W}`
- On timeout, the verify report includes the full retry log so operators can see exactly what happened
- `end_ns` is recomputed on each attempt (never frozen)

---

### Sprint-2-bootstrap-08.md: Versioning, Migration & Secrets Lifecycle

**Principles:** P2, P8, P11

**Purpose:** Version management, config migration between schema versions, complete secrets lifecycle, offline mode.

**Outputs:**
- `_build/Logging-Bootstrap/bin/migrate.py` — Config migration engine (P2)
- `_build/Logging-Bootstrap/bin/generate_secrets.sh` — Create cryptographically random secrets (P8)
- `_build/Logging-Bootstrap/bin/verify_secrets.sh` — Check permissions, existence, completeness (P8)
- `_build/Logging-Bootstrap/config/secrets.example.env` — Template with placeholder values (P8)
- `_build/Logging-Bootstrap/bin/export_images.sh` — Save images to tarballs (P11)
- `_build/Logging-Bootstrap/bin/import_images.sh` — Load images from tarballs (P11)
- `_build/Logging-Bootstrap/migrations/` — Migration scripts per version

**Version contract (P2):**
```json
{
  "bootstrap_version": "1.0.0",
  "schema_version": "1",
  "minimum_schema_version": "1"
}
```
- `bootstrap_version`: Semver of the bootstrap system itself
- `schema_version`: Integer version of the config schema
- `migrate.py` reads config, checks `schema_version`, applies migrations in order
- Breaking changes increment `schema_version` and refuse to run without migration
- Migrations are idempotent (safe to re-run)

**Migration structure:**
```
migrations/
├── v1_to_v2.py   # Adds path_map section
├── v2_to_v3.py   # Adds image_pins section
└── registry.json  # Maps version → migration script
```

**Secrets lifecycle (P8):**
1. `generate_secrets.sh` creates `secrets.local.env` with:
   - `GRAFANA_ADMIN_PASSWORD` (random 24-char alphanumeric)
   - `GRAFANA_SECRET_KEY` (random 32-char)
   - Additional secrets as defined in `contracts/secrets_policy.json`
2. Sets mode 600 on the file
3. `verify_secrets.sh` checks:
   - File exists
   - Mode is exactly 600
   - All required keys present (from secrets_policy.json)
   - No key has placeholder value (`CHANGE_ME`, `TODO`, etc.)
4. Evidence output uses `***REDACTED***` for all secret values
5. No secret ever appears in stdout, logs, or report files

**Offline mode (P11):**
```bash
# Export all pinned images to tarballs
./bin/export_images.sh --config config/bootstrap.test.json --output images/

# On air-gapped host, import
./bin/import_images.sh --input images/

# Run bootstrap in offline mode (config has offline_mode: true)
./bin/bootstrap_run.sh --config config/bootstrap.offline.json
```

---

### Sprint-2-bootstrap-09.md: Test Loop, Idempotency & Final Integration

**Principles:** P6, P17, P18

**Purpose:** Iterative deploy-test-fix loop until error-free. Idempotency verification. Complete integration.

**Outputs:**
- `_build/Logging-Bootstrap/bin/bootstrap_run.sh` — All-in-one runner
- `_build/Logging-Bootstrap/bin/test_loop.sh` — Deploy → verify → fix → cleanup cycle
- `_build/Logging-Bootstrap/bin/bootstrap_cleanup.sh` — Tear down test deployment
- `_build/Logging-Bootstrap/bin/verify_idempotency.sh` — Double-run check (P6)
- `_build/Logging-Bootstrap/DEPLOYMENT.md` — Complete operator guide

**bootstrap_run.sh flow:**
```
1. Acquire lock (P18)
2. Create run bundle directory
3. Validate mode flag (P16)
4. Run preflight → save to bundle
5. If preflight fails → autoheal_scan → exit 2
6. Run apply → save to bundle
7. If apply fails → rollback → autoheal_scan → exit 1
8. Run verify → save to bundle
9. Run autoheal_scan (always, even on success)
10. Write summary.json + summary.md
11. Append to runs.jsonl
12. Release lock
13. Exit with appropriate code
```

**test_loop.sh (iterative):**
```bash
#!/usr/bin/env bash
# Deploy-test-fix loop. Runs until verify is green or max iterations reached.
MAX_ITERATIONS=5
CONFIG="${1:?usage: test_loop.sh <config_path>}"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo "=== Iteration $i of $MAX_ITERATIONS ==="

  # Deploy
  ./bin/bootstrap_run.sh --config "$CONFIG" --mode apply
  RC=$?

  if [[ $RC -eq 0 ]]; then
    echo "=== GREEN: All proofs passed on iteration $i ==="
    # Verify idempotency
    ./bin/verify_idempotency.sh --config "$CONFIG"
    exit $?
  fi

  echo "=== RED: Iteration $i failed (exit $RC) ==="
  echo "Review: out/runs/$(ls -t out/runs/ | head -1)/autoheal.suggestions.json"

  # Cleanup for next iteration
  ./bin/bootstrap_cleanup.sh --config "$CONFIG"
  sleep 5
done

echo "=== FAILED: Did not converge after $MAX_ITERATIONS iterations ==="
exit 1
```

**Idempotency verification (P6):**
```bash
# verify_idempotency.sh
# 1. Run apply a second time
./bin/bootstrap_run.sh --config "$CONFIG" --mode apply
# 2. Compare verify reports from run N and run N+1
# 3. Differences are idempotency violations
# 4. "Benign restarts" (container recreated with same config) are allowed
# 5. Report: out/runs/<latest>/idempotency.report.json
```

**Cleanup script:**
```bash
# bootstrap_cleanup.sh
# 1. Read config for project name
# 2. docker compose -f <compose_file> -p <project> down --volumes --remove-orphans
# 3. Remove generated configs from staging/
# 4. Remove secrets.local.env (test only — never in production)
# 5. Remove test log/telemetry directories
# 6. Produce cleanup.report.json
```

**Interactive elimination check (P17):**
- `bootstrap_run.sh` runs with `DEBIAN_FRONTEND=noninteractive`
- All docker commands use `--no-color` and `-T` (no TTY) where applicable
- If any subprocess tries to read stdin, it gets `/dev/null`
- Preflight has already scanned scripts for interactive patterns

**DEPLOYMENT.md contents:**
- Prerequisites (Docker, Python 3, jq, curl, flock)
- Quick start (5 commands)
- Config reference (every field explained)
- Execution modes (diagnose/apply/repair)
- Offline deployment workflow
- Secrets management
- Rollback procedures
- Evidence and recall
- Troubleshooting by error bucket
- LLM orchestrator usage
- Upgrading bootstrap version

---

## Execution Instructions

For each prompt you generate:

1. **Read the relevant sections** of Sprint-1 and current configs
2. **Create a standalone prompt** following the structure above
3. **Include specific file paths and outputs**
4. **Tag which of the 20 principles (Pxx) it addresses**
5. **Add validation criteria**
6. **Link to next prompt**

**Save each prompt as:**
- `_build/Sprint-2/Sprint-2-bootstrap-01.md`
- `_build/Sprint-2/Sprint-2-bootstrap-02.md`
- ... through `Sprint-2-bootstrap-09.md`

**Test config values to use** (avoid conflicts with production):
```json
{
  "bootstrap_version": "1.0.0",
  "schema_version": "1",
  "compose_project_name": "logging_test",
  "execution_mode": "apply",
  "offline_mode": false,
  "ports": {
    "grafana": 9101,
    "prometheus": 9104
  },
  "path_map": {
    "repo_root": "/home/luce/apps/loki-logging",
    "compose_file": "infra/logging/docker-compose.observability.yml",
    "logs_root": "/tmp/bootstrap-test/logs",
    "telemetry_root": "/tmp/bootstrap-test/telemetry",
    "vllm_root": "/tmp/bootstrap-test/vllm",
    "staging_dir": "_build/Logging-Bootstrap/staging",
    "output_dir": "_build/Logging-Bootstrap/out"
  },
  "image_pins": {
    "grafana": "grafana/grafana:11.1.0",
    "loki": "grafana/loki:3.0.0",
    "prometheus": "prom/prometheus:v2.52.0",
    "node_exporter": "prom/node-exporter:v1.8.1",
    "cadvisor": "gcr.io/cadvisor/cadvisor:v0.49.1",
    "alloy": "grafana/alloy:v1.2.1"
  },
  "secrets_policy": "contracts/secrets_policy.json",
  "toggles": {
    "enable_telemetry_writer": false,
    "verify_dashboards": true,
    "verify_prom_rules": true,
    "verify_codeswarm_ingest": false,
    "verify_cardinality": true,
    "verify_redaction": true
  }
}
```

---

## Principle Coverage Matrix

| Prompt | P1 | P2 | P3 | P4 | P5 | P6 | P7 | P8 | P9 | P10 | P11 | P12 | P13 | P14 | P15 | P16 | P17 | P18 | P19 | P20 |
|--------|----|----|----|----|----|----|----|----|----|----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| 01     | x  | x  | x  | x  |    |    |    | x  | x  | x   |     |     |     |     |     |     |     |     | x   |     |
| 02     | x  |    |    |    |    |    | x  |    | x  | x   | x   |     |     |     |     |     | x   | x   | x   |     |
| 03     | x  |    |    |    |    |    |    | x  | x  | x   | x   |     |     |     |     |     |     |     |     |     |
| 04     | x  |    |    |    | x  | x  | x  | x  |    |     |     |     |     |     |     | x   |     | x   |     |     |
| 05     |    |    | x  |    |    |    | x  |    |    | x   |     |     | x   | x   | x   |     |     |     |     |     |
| 06     |    |    |    | x  |    |    |    |    |    |     |     |     |     |     |     | x   |     |     |     | x   |
| 07     |    |    |    |    |    |    |    |    |    |     |     | x   |     | x   |     |     |     |     |     |     |
| 08     |    | x  |    |    |    |    |    | x  |    |     | x   |     |     |     |     |     |     |     |     |     |
| 09     |    |    |    |    |    | x  |    |    |    |     |     |     |     |     |     |     | x   | x   |     |     |

**All 20 principles covered.** Each principle appears in at least one prompt. Critical principles (P1, P4, P9) appear in multiple prompts.

---

## Quality Gates

Each generated prompt must:

- [ ] Be executable without human intervention (except config editing)
- [ ] Produce deterministic outputs
- [ ] Include validation criteria
- [ ] Reference authoritative upstream docs where applicable
- [ ] Use config-driven approach (no hardcoded values)
- [ ] Handle both fresh install and redeploy
- [ ] Never print secrets
- [ ] Exit with meaningful codes (0=success, 1=soft fail, 2=blocker)
- [ ] Tag which Pxx principles it addresses
- [ ] Use error codes from the taxonomy (P4)
- [ ] Respect execution mode boundaries (P16)
- [ ] Write all output to run bundles (P12)

---

## Constraints

**MUST NOT:**
- Modify current production deployment
- Use production ports/paths in test config
- Print secrets to stdout/logs/reports
- Embed heredocs in prompts
- Create brittle path dependencies
- Use `:latest` image tags
- Grep API responses for validation
- Use frozen timestamps in proof retries
- Allow the LLM orchestrator to execute commands

**MUST:**
- Use TEST config values initially
- Be idempotent (verified by double-run check)
- Produce structured JSON reports in run bundles
- Include cleanup and rollback scripts
- Provide clear error messages with taxonomy codes
- Resolve all paths through config path_map
- Pin all image tags and record provenance
- Acquire concurrency lock before mutating operations
- Scan for interactive commands in preflight
- Support offline deployment mode

---

## Success Criteria

After running all 9 prompts sequentially:

1. `_build/Logging-Bootstrap/` contains complete bootstrap system
2. Test deployment succeeds with `bootstrap.test.json`
3. All verification proofs pass (L1-L8)
4. Idempotency check passes (second run is no-op)
5. Deployment can be cleaned up and re-run
6. Rollback restores last-known-good state
7. Error taxonomy classifies all failures into buckets
8. Evidence recall CLI can query past runs
9. Offline mode works with exported images
10. Documentation is complete and accurate
11. System is ready for production use with `bootstrap.local.json`

---

## Next Steps

1. Generate `Sprint-2-bootstrap-01.md` through `Sprint-2-bootstrap-09.md`
2. Each prompt should be 300-500 lines (more detailed than before)
3. Include bash/python code snippets inline
4. Reference current working configs as examples
5. Ensure generic applicability (not host-specific)
6. Tag every prompt with its Pxx coverage

---

**Execute:** Generate the 9 sequential bootstrap prompts now.
