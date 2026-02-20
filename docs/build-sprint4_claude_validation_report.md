# Sprint-4 Claude Findings Validation Report

Generated: 2026-02-17T21:40:21.278886Z
Source: `_build/Sprint-4/claude/`

## Intake summary
- Claude `discovery.json` reported findings: **89**
- Severity from scan: critical=2, high=16, medium=28, low=31, pass=12
- ADR severity statements parsed from `adr.md`: **127** (includes supplementary passes and pass-level notes)

## Validation method (truth-first)
- Runtime truth: `docker ps`, Grafana API, Loki/Prom readiness
- Source truth: `infra/logging/*.yml`, `infra/logging/alloy-config.alloy`, `scripts/prod/mcp/*.sh`, docs
- Only validated findings are eligible for implementation.

## Validated status (high-value slice)
1. **Confirmed (implement now): rsyslog bypasses redaction/main process**  
   (evidence: `rg -n "loki.source.syslog|forward_to" infra/logging/alloy-config.alloy` => `forward_to = [loki.write.default.receiver]`)
2. **Confirmed (implement now): destructive `down -v` default**  
   (evidence: `nl -ba scripts/prod/mcp/logging_stack_down.sh` => `docker compose ... down -v`)
3. **Confirmed (implement now): health script uses `rg` without dependency check and hardcoded ports**  
   (evidence: `nl -ba scripts/prod/mcp/logging_stack_health.sh` => `rg -q` and `127.0.0.1:9001/9004`)
4. **Confirmed (implement now): datasource provisioning files omit explicit UIDs**  
   (evidence: `nl -ba infra/logging/grafana/provisioning/datasources/*.yml` => no `uid:` lines)
5. **Confirmed (doc fix now): docs claim `host=codeswarm` label that is not configured**  
   (evidence: `CLAUDE.md` label section vs `alloy-config.alloy` no `host` static label)
6. **Confirmed (doc fix now): `docs/reference.md` reports 7 sources but runtime/source include 8 incl. `rsyslog_syslog`**  
   (evidence: source pipelines in `alloy-config.alloy` + docs table missing explicit rsyslog row)

## Validated status (stale/partial from scan)
1. **Stale:** Loki port mapping drift in scan is no longer true in current compose render.  
   (evidence: `docker compose ... config` includes Loki published port 3200)
2. **Partial:** dashboard subdirectory loading risk is mitigated by observed provisioned dashboards under `sources/` and `adopted/`.  
   (evidence: prior verifier artifacts in `_build/logging/*` show provisioned counts)
3. **Still true but deferred (non-trivial):** template-engine `eval` injection risk in `src/log-truncation/lib/template-engine.sh` (requires redesign, not quick patch).

## Implementation scope for this execution
- Apply four code/config hardening fixes + two documentation accuracy fixes.
- Do not change ingestion architecture beyond rsyslog forwarding correction.
- Do not perform broad refactors or version upgrades in this pass.

## Implemented in this pass
- `infra/logging/alloy-config.alloy`: rsyslog now forwards through `loki.process.main`.
- `scripts/prod/mcp/logging_stack_down.sh`: default is non-destructive `down`; explicit `--purge` required for `down -v`.
- `scripts/prod/mcp/logging_stack_health.sh`: removed `rg` dependency and made Grafana/Prom URLs `.env`-driven.
- `infra/logging/grafana/provisioning/datasources/loki.yml`: pinned Loki UID.
- `infra/logging/grafana/provisioning/datasources/prometheus.yml`: pinned Prometheus UID.
- `CLAUDE.md`, `docs/reference.md`: corrected label/source documentation drift.

## Traceability
- Full parsed inventory: `_build/melissa/sprint4_findings_inventory.json`
