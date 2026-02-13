# Bootstrap Prompt Generator

**Purpose:** Generate 8 sequential prompts that build a generic, config-driven logging bootstrap system.
**Output:** `_build/Sprint-2/Sprint-2-bootstrap-01.md` through `Sprint-2-bootstrap-08.md`
**Target:** `_build/Logging-Bootstrap/`

---

## Execution Model

This prompt set is designed for **autonomous execution**. Each prompt runs without human intervention.

**When blocked:**
- Pick the most reasonable default and proceed. Do not stop to ask.
- If a download fails (reference doc, image pull), log the failure and continue.
- If a path doesn't exist, create it.
- If a config value is ambiguous, use the test config value.
- If a tool is missing, emit the error code and skip that check (don't abort the whole run).
- If two approaches are equally valid, pick the simpler one.
- Document every autonomous decision in the run report under a `decisions` key so a human can review later.

**Never block on:**
- Reference doc fetches (best-effort)
- Optional validation checks (skip and warn)
- Missing optional config fields (use defaults from schema)

**Always block on:**
- Missing required config fields (fail fast with error code)
- Docker daemon unreachable
- Port conflicts with existing services
- Schema version mismatch

---

## What You're Building

A config-driven bootstrap for the Grafana LGTM stack (Grafana + Loki + Alloy + Prometheus + Node Exporter + cAdvisor) on Docker Compose. One JSON config file drives everything — ports, paths, images, retention, secrets. No hardcoded values in any script or template.

**Reference material** (read for patterns, do not copy verbatim):
- `infra/logging/docker-compose.observability.yml` — working compose file
- `infra/logging/alloy-config.alloy` — working Alloy River config
- `infra/logging/loki-config.yml` — working Loki config
- `infra/logging/prometheus/prometheus.yml` — working Prometheus config
- `_build/Sprint-2/references/` — upstream deployment guides

**Rules:**
- No CodeSwarm-specific, host-specific, or project-specific values in output
- All values derive from config. Zero hardcoded paths, ports, or image tags.
- Fail fast: one clear error per invalid field with example fix
- All API validation is semantic (parse JSON, check fields). No grep on responses.
- Scripts do deterministic mechanics. LLM decides what to change next.
- Clean Slate instead of rollback: delete only what bootstrap owns.
- Compact reports: 4 JSON + summary per run. No file spam.
- Every prompt includes an **Affects** section bounding its scope.
- References are best-effort; don't block bootstrap if a download fails.

---

## Design Principles

One imperative sentence each. Tagged Pxx throughout prompts.

- **P1 Source of Truth:** Generated templates are the source of truth; compute SHA-256 of generated configs into `desired_state.json` on every run.
- **P3 Health Model:** All health checks read from `contracts/health_contract.json` — no ad-hoc curl.
- **P4 Error Taxonomy:** Five buckets (ENV/CONFIG/RUNTIME/PROOF/NETWORK) with stable codes; Claude reacts deterministically.
- **P5 Clean Slate:** Delete only what bootstrap owns; `--dry-run` default, `--force` to act.
- **P6 Idempotent:** Second run with same config = no-op; differences are violations.
- **P7 Mount Check:** SHA-compare host file vs in-container file for alloy-config, loki-config, prometheus.yml.
- **P8 Secrets:** One `secrets.local.env` (mode 600, gitignored); never in reports; test by injecting fake marker.
- **P9 Single Config:** One JSON file defines everything; all scripts resolve from it.
- **P10 Pin Images:** Exact tags in config, record `image:tag → sha256:digest` provenance after pull.
- **P12 Compact Reports:** Per run: `preflight.json`, `apply.json`, `verify.json`, `summary.json`, `summary.md`, optional `taskpack.md`.
- **P13 Semantic API:** Parse JSON responses, check `status`/`data` fields. No grep/string-match.
- **P14 Time Windows:** Recompute `end` timestamp each retry; hard max wall-clock; partial diagnostics on timeout.
- **P15 Labels & Security:** Required labels (`env`, `source`, `service`), cardinality < 100, redaction stage check, fake secret injection test.
- **P16 Modes:** `diagnose` (read-only), `apply` (full deploy), `test-loop` (3× clean-slate → apply → verify), `clean-slate` (reset).
- **P17 Non-Interactive:** No stdin prompts; preflight scans scripts for `read -p`/`select` patterns.
- **P18 Lock:** `flock` on `out/.bootstrap.lock`; clear error if locked.
- **P19 Fast Fail:** JSON Schema + semantic lint; one error per field with example patch.
- **P20 LLM Boundaries:** Orchestrator reads reports and proposes patches. Never executes. Generates CLAUDE Task Pack on failure.

---

## Error Taxonomy (Initial Codes)

Prompt 01 creates `contracts/error_taxonomy.json` with at least these codes:

| Code | Bucket | Meaning |
|------|--------|---------|
| `E_ENV_DOCKER_UNREACHABLE` | ENV | Docker daemon not responding |
| `E_ENV_TOOL_MISSING` | ENV | Required tool not in PATH |
| `E_ENV_MODE_VIOLATION` | ENV | Command not allowed in current mode |
| `E_ENV_LOCK_HELD` | ENV | Another bootstrap instance running |
| `E_CONFIG_SCHEMA_INVALID` | CONFIG | JSON Schema validation failed |
| `E_CONFIG_MISSING_KEY` | CONFIG | Required config field absent |
| `E_CONFIG_INVALID_PORT` | CONFIG | Port outside 1024-65535 |
| `E_CONFIG_LATEST_TAG` | CONFIG | Image uses `:latest` |
| `E_CONFIG_PATH_MISSING` | CONFIG | Required path doesn't exist |
| `E_CONFIG_DNS_UNSAFE` | CONFIG | Project name not DNS-safe |
| `E_RUNTIME_PORT_CONFLICT` | RUNTIME | Port already in use |
| `E_RUNTIME_COMPOSE_FAIL` | RUNTIME | `docker compose up` failed |
| `E_RUNTIME_CONTAINER_UNHEALTHY` | RUNTIME | Health check failed after retries |
| `E_RUNTIME_MOUNT_DRIFT` | RUNTIME | Host SHA ≠ container SHA |
| `E_PROOF_MARKER_NOT_FOUND` | PROOF | Log marker not in Loki within timeout |
| `E_PROOF_TIMEOUT` | PROOF | Wall-clock exceeded |
| `E_PROOF_LABEL_MISSING` | PROOF | Required label not in Loki |
| `E_PROOF_CARDINALITY` | PROOF | Label has >100 unique values |
| `E_PROOF_SECRET_LEAKED` | PROOF | Fake secret marker found in logs |
| `E_NETWORK_HEALTH_FAIL` | NETWORK | Service health endpoint unreachable |
| `E_NETWORK_BIND_MISMATCH` | NETWORK | Actual bind address ≠ config |

---

## Known Pitfalls

Prompt 01 creates `docs/known-pitfalls.md`:

- **Alloy River syntax:** No trailing commas; label values must be quoted; `//` comments work at top level but not inside all blocks
- **Loki selectors:** At least one non-empty label matcher required; `{job=""}` is invalid
- **Proof window freeze:** Never cache `end` timestamp across retries; recompute each time
- **Grafana credentials:** Only applied on first startup; changing .env after init requires volume wipe
- **Prometheus retention:** CLI flags only (`--storage.tsdb.retention.time=15d`), not in prometheus.yml
- **Docker network DNS:** Service names resolve only within compose project network; use service name not `localhost`
- **cAdvisor /dev/kmsg:** Requires `privileged: true` + device mount; logs errors without it but still runs

---

## CLAUDE Task Pack Format

When verify fails, generate `taskpack.md`:

```
# CLAUDE Task Pack — Run <timestamp>

## Failed Checks
| Code | Bucket | Check | Message |

## Evidence
- Report: out/runs/<ts>/verify.json

## Fix
[Specific config or template edit]

## Affects
[Exact files — nothing else]

## Rerun
./bin/bootstrap_run.sh --config <config> --mode apply
```

---

## Test Config

All prompts use this vanilla config. No host-specific values.

```json
{
  "bootstrap_version": "1.0.0",
  "schema_version": "1",
  "compose_project_name": "logging_bootstrap_test",
  "execution_mode": "apply",
  "proof_timeout_s": 120,
  "retention": {
    "logs_hours": 720,
    "metrics_days": 15
  },
  "port_exposure": {
    "grafana":    {"port": 9101, "bind": "0.0.0.0", "firewall": true},
    "prometheus": {"port": 9104, "bind": "0.0.0.0", "firewall": true},
    "loki":       {"port": 9102, "bind": "127.0.0.1", "firewall": false}
  },
  "path_map": {
    "compose_dir":    "deploy/",
    "staging_dir":    "staging/",
    "output_dir":     "out/",
    "logs_root":      "/tmp/bootstrap-test/logs",
    "telemetry_root": "/tmp/bootstrap-test/telemetry"
  },
  "image_pins": {
    "grafana":       "grafana/grafana:11.1.0",
    "loki":          "grafana/loki:3.0.0",
    "prometheus":    "prom/prometheus:v2.52.0",
    "node_exporter": "prom/node-exporter:v1.8.1",
    "cadvisor":      "gcr.io/cadvisor/cadvisor:v0.49.1",
    "alloy":         "grafana/alloy:v1.2.1"
  },
  "network_name": "obs",
  "services": {
    "grafana":       {"internal_port": 3000, "health_path": "/api/health"},
    "loki":          {"internal_port": 3100, "health_path": "/ready"},
    "prometheus":    {"internal_port": 9090, "health_path": "/-/ready"},
    "host_monitor":  {"internal_port": 9100, "metrics_path": "/metrics"},
    "docker_metrics":{"internal_port": 8080, "metrics_path": "/metrics"},
    "alloy":         {"internal_port": 12345, "health_cmd": "/bin/alloy fmt --help"}
  },
  "label_contract": {
    "required_labels": ["env", "source", "service"],
    "max_cardinality": 100
  },
  "secrets_policy": "contracts/secrets_policy.json",
  "toggles": {
    "verify_dashboards":    true,
    "verify_prom_rules":    true,
    "verify_cardinality":   true,
    "verify_redaction":     true,
    "verify_port_exposure": true
  }
}
```

---

## Prompt Template

Each generated prompt follows this structure:

```markdown
# Sprint-2-bootstrap-XX: [Title]

## Affects
[Exact files/directories created or modified]

## Principles
[Pxx tags with one-line description of what this prompt does for each]

## Reads
[Input files from prior prompts]

## Creates
[Output files under _build/Logging-Bootstrap/]

## Task
[Executable instructions with code snippets]

## Validation
[How to verify success]
```

---

## Prompt Sequence

---

### Prompt 01: Foundation & Contracts

**Affects:** `_build/Logging-Bootstrap/` directory tree, `contracts/`, `config/`, `docs/`, `references/`, `.gitignore`

**Principles:** P1, P3, P4, P8, P9, P15, P19

**Creates:**
```
_build/Logging-Bootstrap/
├── README.md
├── .gitignore                          # bootstrap.local.json, secrets.local.env, out/, staging/
├── requirements.txt                    # jinja2>=3.1, jsonschema>=4.0
├── docs/
│   └── known-pitfalls.md               # See Known Pitfalls section above
├── references/                         # Best-effort fetch from upstream docs (non-blocking)
│   ├── grafana-docker-install.md
│   ├── loki-docker-install.md
│   ├── alloy-install.md
│   ├── prometheus-install.md
│   ├── node-exporter-guide.md
│   ├── cadvisor-guide.md
│   └── loki-http-api.md
├── contracts/
│   ├── health_contract.json            # P3: every health endpoint with URL, expected code, timeout, retries, backoff
│   ├── error_taxonomy.json             # P4: all codes from Error Taxonomy table above
│   ├── secrets_policy.json             # P8: see structure below
│   ├── label_contract.json             # P15: required labels, max cardinality, selector patterns
│   └── port_exposure.json              # Validation rules for port exposure (valid bind addresses, port ranges). Actual values come from config.
└── config/
    ├── bootstrap.schema.json           # P19: JSON Schema — validate structure + types
    ├── bootstrap.example.json          # Full example with comments (all fields)
    └── bootstrap.test.json             # Test Config from above
```

**health_contract.json structure:**
```json
{
  "checks": [
    {"service": "grafana",       "type": "http", "url": "http://grafana:3000/api/health",      "expect_status": 200, "expect_json": {"database": "ok"}, "timeout_s": 10, "retries": 5, "backoff_s": 3},
    {"service": "loki",          "type": "http", "url": "http://loki:3100/ready",              "expect_status": 200, "timeout_s": 10, "retries": 5, "backoff_s": 3},
    {"service": "prometheus",    "type": "http", "url": "http://prometheus:9090/-/ready",      "expect_status": 200, "timeout_s": 10, "retries": 5, "backoff_s": 3},
    {"service": "alloy",         "type": "cmd",  "container": "alloy", "cmd": ["/bin/alloy", "fmt", "--help"], "expect_exit": 0, "timeout_s": 10, "retries": 3, "backoff_s": 5},
    {"service": "host_monitor",  "type": "http", "url": "http://host-monitor:9100/metrics",   "expect_status": 200, "timeout_s": 10, "retries": 3, "backoff_s": 3, "note": "metrics-only, no structured health"},
    {"service": "docker_metrics","type": "http", "url": "http://docker-metrics:8080/metrics",  "expect_status": 200, "timeout_s": 10, "retries": 3, "backoff_s": 3, "note": "metrics-only, no structured health"}
  ]
}
```

**secrets_policy.json structure:**
```json
{
  "file": "secrets.local.env",
  "mode": "0600",
  "required_keys": [
    "GRAFANA_ADMIN_PASSWORD",
    "GF_SECURITY_ADMIN_PASSWORD",
    "GF_SECURITY_SECRET_KEY"
  ],
  "redaction_pattern": "***REDACTED***",
  "placeholder_values": ["CHANGE_ME", "changeme", "admin", "password", "secret"]
}
```

**config_lint.py** (also created here — standalone CLI, imports validation logic that `config_loader.py` in Prompt 02 will also reuse): Reads `bootstrap.schema.json` + runs semantic checks. One error per field:
- Port in 1024-65535
- Paths are absolute (for host-mounted paths) or relative (for bootstrap-internal paths)
- `compose_project_name` is DNS-safe (`^[a-z][a-z0-9_-]*$`)
- No image uses `:latest`
- All required toggles are boolean
- `secrets_policy` points to existing file
- Output: JSON with `{field, error_code, message, example_fix}` per failure

---

### Prompt 02: Shared Libraries

**Affects:** `bin/lib/`

**Principles:** P1, P4, P12, P18, P19

**Reads:** `contracts/error_taxonomy.json`, `contracts/health_contract.json`, `config/bootstrap.schema.json`

**Creates:**
```
bin/
└── lib/
    ├── __init__.py
    ├── config_loader.py    # Load config, validate against schema, run semantic lint (P9, P19)
    ├── error_emitter.py    # Emit errors with bucket + code from taxonomy (P4)
    ├── desired_state.py    # Compute SHA-256 of file list, save/compare desired_state.json (P1)
    ├── lockfile.py         # flock-based concurrency guard on out/.bootstrap.lock (P18)
    ├── evidence.py         # Create run bundle dir, write reports, append runs.jsonl (P12)
    └── api_validator.py    # assert_json_field(resp, path, expected), assert_http_status(url, code) (P13)
```

Every downstream script imports from `bin/lib/`. This prompt creates the foundation code all other prompts depend on.

**config_loader.py must:**
- Load JSON, validate against schema
- Run `config_lint.py` logic (semantic checks)
- Return typed config object or raise with error codes
- Resolve `path_map` entries to absolute paths

**evidence.py must:**
- `create_run(config) → run_dir` — creates `out/runs/<timestamp>/`
- `write_report(run_dir, phase, data)` — writes `preflight.json`, `apply.json`, or `verify.json`
- `write_summary(run_dir, status, errors, warnings)` — writes `summary.json` + `summary.md`
- `append_index(run_dir, meta)` — appends to `out/runs.jsonl`

---

### Prompt 03: Preflight Validator

**Affects:** `bin/bootstrap_preflight.py`, `tests/test_preflight.sh`

**Principles:** P1, P7, P9, P10, P17, P18, P19

**Reads:** `contracts/*`, `config/bootstrap.test.json`, `bin/lib/*`

**Creates:**
- `bin/bootstrap_preflight.py`
- `tests/test_preflight.sh`

**Preflight checks (in order):**
1. Acquire lock (P18)
2. Load + validate config (P19) — fail fast, one error per field
3. Resolve `path_map` — report missing required vs optional (P9)
4. Docker daemon reachable — `docker info`
5. Required tools — `jq`, `curl`, `docker compose`, `python3`, `flock`; Python packages: `python3 -c "import jinja2; import jsonschema"` (emit `E_ENV_TOOL_MISSING` with `pip install -r requirements.txt` fix)
6. Port conflicts — `ss -tln` for each port in `port_exposure`
7. Bind address check — verify actual bind matches config expectation
8. Image tag check — warn on `:latest` (P10)
9. Compute desired state SHA-256 of config + template files (P1)
10. Drift detection — if previous `desired_state.json` exists, compare (P1, P7)
11. Secrets check — `secrets.local.env` exists with mode 600 (P8)
12. journald persistence — `/var/log/journal` exists
13. Interactive pattern scan — grep `bin/` for `read -p`, `select` (P17)
14. Mode validation — `--mode` is one of diagnose/apply/test-loop/clean-slate (P16)

**Output:** `out/runs/<ts>/preflight.json`
Exit: 0=green, 1=warnings, 2=blocker

---

### Prompt 04: Templates & Config Generation

**Affects:** `templates/`, `bin/generate_configs.py`, `bin/generate_secrets.sh`

**Principles:** P1, P8, P9, P10

**Reads:** `config/bootstrap.test.json`, `bin/lib/*`, `references/*`

This is the critical prompt. It must produce working Jinja2 templates. Expand with specifics.

**Creates:**
```
templates/
├── docker-compose.observability.yml.j2
├── loki-config.yml.j2
├── alloy-config.alloy.j2
├── prometheus.yml.j2
├── prometheus-rules-placeholder.yml.j2  # Empty rules file so mount doesn't fail
├── grafana-datasources.yml.j2           # Provisioning: Loki + Prometheus datasources
├── grafana-dashboards.yml.j2            # Provisioning: dashboard provider config
├── .env.j2
└── secrets.local.env.j2
bin/
├── generate_configs.py
└── generate_secrets.sh
```

**Template specifications:**

**docker-compose.observability.yml.j2** — reference: `infra/logging/docker-compose.observability.yml`
- `name:` from `config.compose_project_name`
- `env_file:` pointing to generated `.env` in `config.path_map.compose_dir`
- Network `{{ config.network_name }}` with bridge driver
- 3 named volumes: grafana-data, prometheus-data, loki-data
- 6 services, each using `{{ config.image_pins.<service> }}`
- Port bindings: for each service in `config.port_exposure`, emit `{{ svc.bind }}:{{ svc.port }}:{{ config.services[svc].internal_port }}`. If a service has no port_exposure entry, no `ports:` section (internal only).
- Grafana: mount provisioning dirs `./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro` and `./grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro`
- Loki: command `-config.file=/etc/loki/loki-config.yml`. Port exposed only if `loki` key exists in `port_exposure`.
- Prometheus: command includes `--storage.tsdb.retention.time={{ config.retention.metrics_days }}d` (CLI flag, NOT config file). Mount `./prometheus/rules:/etc/prometheus/rules:ro`.
- cAdvisor: `privileged: true`, device `/dev/kmsg:/dev/kmsg`
- Node exporter: `pid: host`, command `--path.rootfs=/host`
- Alloy: `user: "0:0"`, command includes `--server.http.listen-addr=0.0.0.0:{{ config.services.alloy.internal_port }}`
- Health checks from `contracts/health_contract.json` (interval, timeout, retries, start_period)
- All volume mounts parameterized via `config.path_map`

**grafana-datasources.yml.j2** — Grafana auto-provisioning:
```yaml
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:{{ config.services.loki.internal_port }}
    isDefault: true
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:{{ config.services.prometheus.internal_port }}
```

**grafana-dashboards.yml.j2** — Dashboard provider (points to provisioned dashboards dir):
```yaml
apiVersion: 1
providers:
  - name: default
    type: file
    options:
      path: /var/lib/grafana/dashboards
```

**loki-config.yml.j2** — reference: `infra/logging/loki-config.yml`
- `auth_enabled: false`
- `http_listen_port: {{ config.services.loki.internal_port }}`
- `retention_period: {{ config.retention.logs_hours }}h`
- Schema: tsdb, v13, filesystem
- Compactor with retention enabled

**alloy-config.alloy.j2** — reference: `infra/logging/alloy-config.alloy` — CAUTION: River syntax
- `discovery.docker "all"` block
- `loki.source.docker` forwarding to `loki.process.docker.receiver`
- `loki.source.journal` forwarding to `loki.process.journal.receiver`
- File sources from `config.path_map.logs_root` and `config.path_map.telemetry_root`, forwarding to `loki.process.file.receiver`
- **Three separate `loki.process` blocks** to set `source` label per source type:
  - `loki.process "docker"` → `stage.static_labels { values = { env = "...", source = "docker" } }`
  - `loki.process "journal"` → `stage.static_labels { values = { env = "...", source = "journal" } }`
  - `loki.process "file"` → `stage.static_labels { values = { env = "...", source = "file" } }`
  - All three forward to `loki.write.default.receiver`
- `service` label: comes from Docker container labels via `discovery.docker` (for docker source) or set via `stage.static_labels` as `"bootstrap"` for journal/file sources
- `loki.write "default"` pointing to `http://loki:{{ config.services.loki.internal_port }}/loki/api/v1/push`
- **No trailing commas.** Label values in quotes. No CodeSwarm-specific sources.
- Label contract compliance: every log line gets `env`, `source`, and `service` labels

**prometheus.yml.j2** — reference: `infra/logging/prometheus/prometheus.yml`
- 5 scrape targets: prometheus, host-monitor, docker-metrics, loki, alloy
- Each target uses service name + internal port from `config.services`
- `rule_files: ["/etc/prometheus/rules/*.yml"]`

**generate_configs.py must:**
1. Load config via `config_loader`
2. Render each template with Jinja2
3. Write to `staging/` directory with correct subdirectory structure:
   - `staging/docker-compose.observability.yml`
   - `staging/loki-config.yml`
   - `staging/alloy-config.alloy`
   - `staging/prometheus/prometheus.yml`
   - `staging/prometheus/rules/` (placeholder)
   - `staging/grafana/provisioning/datasources/datasources.yml`
   - `staging/grafana/provisioning/dashboards/dashboards.yml`
   - `staging/.env`
   - `staging/secrets.local.env` (only if doesn't already exist)
4. Pull images (unless config has no network), record provenance `image:tag → sha256:digest`
5. Compute SHA-256 of generated files → include in `desired_state.json`
6. Output: list of generated files + provenance

**generate_secrets.sh must:**
1. Read required keys from `contracts/secrets_policy.json`
2. Generate random values (`openssl rand -base64 24`)
3. Write `secrets.local.env`, set mode 600
4. Never print generated values to stdout

---

### Prompt 05: Apply & Clean Slate

**Affects:** `bin/bootstrap_apply.sh`, `bin/clean_slate.sh`, `bin/lib/checkpoint.sh`

**Principles:** P1, P5, P6, P7, P8, P16, P18

**Reads:** `bin/lib/*`, `bin/generate_configs.py`, `contracts/health_contract.json`

**Apply stages:**
```
0. Acquire lock (P18)
1. Snapshot: running containers, config SHAs → out/checkpoints/<ts>/
2. Generate configs → staging/ (calls generate_configs.py)
3. Validate staging: diff vs current, SHA comparison (P7)
   → If --mode diagnose: print diff, exit 0
4. Write: swap staging/ → deploy/ target; generate secrets if missing (P8); verify mode 600
5. Compose up: docker compose -f <compose> -p <project> up -d; wait for health (P3)
6. Mount check: host SHA vs container SHA for alloy-config, loki-config, prometheus.yml (P7)
7. Checkpoint: record success → out/checkpoints/; release lock
```

**clean_slate.sh:**
```bash
# --dry-run (default): list what would be deleted
# --force: actually delete
# --config <path>: required
#
# Deletes (bootstrap-owned only):
# 1. Docker compose project: docker compose -p <project_name> down --volumes --remove-orphans
# 2. Generated configs in staging/ and deploy/
# 3. Bootstrap output in out/
# 4. secrets.local.env (if test config)
# 5. Test directories from path_map (logs_root, telemetry_root)
#
# Does NOT delete: templates, contracts, config files, references, the bootstrap system itself
```

**Output:** `out/runs/<ts>/apply.json`
Exit: 0=success, 1=failed (ran clean-slate), 2=preflight blocker

---

### Prompt 06: Verification & Proofs

**Affects:** `bin/bootstrap_verify.py`, `bin/lib/health_checker.py` (uses `api_validator` from Prompt 02), `bin/lib/proof_helper.py`, `bin/lib/cardinality_checker.py`

**Principles:** P3, P7, P8, P10, P13, P14, P15

**Reads:** `contracts/*`, `bin/lib/*`, `references/loki-http-api.md`

10 verification levels. Each produces a check entry in `verify.json`.

**L1 Service Health (P3):** Read `health_contract.json`. For each check: HTTP GET → parse JSON → assert expected fields. Use contract timeout/retries/backoff.

**L2 Loki Reachability (P13):** Run disposable container on compose network:
```bash
docker run --rm --network={{ network_name }} curlimages/curl \
  curl -s http://loki:3100/ready
```
Parse JSON. Assert HTTP 200.

**L3 Log Ingestion Proof (P13, P14):** Write marker `BOOTSTRAP_PROOF_<uuid>` to `path_map.logs_root/test.log`. Query Loki:
```
GET http://loki:3100/loki/api/v1/query_range?query={source="file"}&limit=100&start=<ns>&end=<ns>
```
Parse JSON → `data.result[].values[]` → find marker string. Recompute `end` each retry. Max `proof_timeout_s` wall-clock. On timeout: emit partial diagnostics with retry log.

**L4 Label Contract (P13, P15):** Query `GET /loki/api/v1/labels` → parse `data` array → assert required labels from `label_contract.json`. Query `/loki/api/v1/label/<name>/values` for each → flag if >100 values. Check Alloy config for container allowlist + journald unit list + redaction stage.

**L5 Security Hardening (P8, P15):** Write `BOOTSTRAP_TEST_SECRET_CANARY` to test log. Query Loki for it — must be absent or redacted. Check `secrets.local.env` mode 600. Grep all `out/` for secret values.

**L6 Port Exposure:** For each service in `port_exposure`: `ss -tln` → verify bind address. If `bind: "0.0.0.0"` → curl from localhost must work. If `bind: "127.0.0.1"` → verify loopback only.

**L7 Dashboard Provisioning:** `GET http://grafana:3000/api/search?type=dash-db` (auth: admin/admin or from secrets) → parse JSON → assert dashboard count > 0.

**L8 Prometheus Targets:** `GET http://prometheus:9090/api/v1/targets` → parse `data.activeTargets` → assert expected job names (prometheus, host-monitor, docker-metrics, loki, alloy).

**L9 Provenance (P10):** For each running container: `docker inspect --format='{{.Image}}'` → compare digest against provenance from apply phase.

**L10 Mount Correctness (P7):** For each critical config mount:
```bash
sha256sum deploy/loki-config.yml
docker exec <loki_container> sha256sum /etc/loki/loki-config.yml
# Must match
```
Critical mounts: alloy-config, loki-config, prometheus.yml.

**Output:** `out/runs/<ts>/verify.json`
Exit: 0=green, 1=warnings, 2=critical

---

### Prompt 07: Orchestrator & Task Pack

**Affects:** `orchestrator/`, `bin/lib/mode_guard.py`, `bin/recall.sh`

**Principles:** P4, P12, P16, P20

**Reads:** `contracts/error_taxonomy.json`, `out/runs/` report format from prior prompts

**Creates:**
- `orchestrator/LLM_ORCHESTRATOR.md` — prompt template with MAY/MUST NOT boundaries
- `orchestrator/autoheal_scan.py` — reads latest run reports, classifies errors by bucket, emits one action per active bucket
- `orchestrator/taskpack_gen.py` — reads verify.json, generates `taskpack.md` (see format above)
- `bin/lib/mode_guard.py` — enforces allowed commands per mode; violation = `E_ENV_MODE_VIOLATION`
- `bin/recall.sh` — CLI to query `out/runs.jsonl`: `list`, `latest`, `list --status red`, `list --bucket CONFIG`, `show <id>`, `export <id>`

**LLM Orchestrator MAY:** Read reports, classify failures, propose patch as JSON, generate one next prompt, reference known-pitfalls.md.
**LLM Orchestrator MUST NOT:** Execute commands, modify files, propose multi-bucket fixes at once, access secrets.

**autoheal_scan.py output:**
```json
{
  "run_id": "<ts>",
  "active_buckets": [
    {"bucket": "CONFIG", "codes": ["E_CONFIG_INVALID_PORT"], "count": 1,
     "action": "Edit config: set port_exposure.grafana.port to value in 1024-65535",
     "example": {"port_exposure": {"grafana": {"port": 9101}}}}
  ],
  "resolved_buckets": ["ENV", "RUNTIME", "PROOF", "NETWORK"]
}
```

---

### Prompt 08: Test Loop, Integration & Deployment Guide

**Affects:** `bin/bootstrap_run.sh`, `bin/test_loop.sh`, `bin/verify_idempotency.sh`, `DEPLOYMENT.md`

**Principles:** P5, P6, P16, P17, P18

**Reads:** All prior scripts and contracts

**Creates:**

**bootstrap_run.sh** — single-run orchestrator:
```
1. Acquire lock
2. Create run bundle (evidence.create_run)
3. Validate mode
4. Preflight → preflight.json (exit 2 if blocker)
5. Apply → apply.json (clean-slate on failure, exit 1)
6. Verify → verify.json
7. If verify fails → taskpack_gen → taskpack.md
8. Write summary.json + summary.md
9. Append runs.jsonl
10. Release lock
11. Exit 0/1/2
```

**test_loop.sh** — 3× autonomous cycle:
```bash
#!/usr/bin/env bash
set -uo pipefail  # no -e: we capture exit codes explicitly
MAX=3; CONFIG="${1:?usage: test_loop.sh <config>}"

for i in $(seq 1 $MAX); do
  echo "=== Iteration $i/$MAX ==="
  ./bin/clean_slate.sh --config "$CONFIG" --force
  ./bin/bootstrap_run.sh --config "$CONFIG" --mode apply
  RC=$?
  if [[ $RC -eq 0 ]]; then
    echo "=== GREEN on iteration $i ==="
    ./bin/verify_idempotency.sh --config "$CONFIG"
    exit $?
  fi
  echo "=== RED: exit $RC ==="
  echo "Task pack: out/runs/$(ls -t out/runs/ | head -1)/taskpack.md"
done
echo "=== FAILED after $MAX iterations — hand off with latest task pack ==="
exit 1
```

**verify_idempotency.sh** — run apply a second time, diff verify reports, flag differences.

**DEPLOYMENT.md:**
- Prerequisites: Docker, Python 3, jq, curl, flock, Jinja2 (`pip install jinja2`)
- Quick start: 5 commands (lint → preflight → apply → verify → recall)
- Config reference: every field with type and example
- Modes: diagnose / apply / test-loop / clean-slate
- Secrets management
- Evidence and recall CLI
- Troubleshooting by error bucket (table: bucket → common codes → fix)
- LLM orchestrator usage + task pack format
- Known pitfalls reference

**Integration validation (run after all prompts):**
1. `python3 bin/config_lint.py config/bootstrap.test.json` → exit 0
2. `./bin/test_loop.sh config/bootstrap.test.json` → converge green within 3
3. `./bin/verify_idempotency.sh --config config/bootstrap.test.json` → no-op
4. `./bin/clean_slate.sh --config config/bootstrap.test.json --force` → only bootstrap artifacts removed
5. `./bin/recall.sh list` → shows all runs
6. `grep -r 'BOOTSTRAP_TEST_SECRET' out/` → zero matches
7. `grep -rn '/home/' bin/ templates/` → zero matches (no hardcoded paths)

---

## Generate Now

Produce `Sprint-2-bootstrap-01.md` through `Sprint-2-bootstrap-08.md`. Each prompt 300-500 lines with inline code snippets. Reference `_build/Sprint-2/references/` for upstream docs. Include Affects section in every prompt. One prompt at a time — stop after each and confirm before next.
