---
chatgpt_scoping_kind: task
chatgpt_scoping_scope: single-file
chatgpt_scoping_targets_root: _build/Sprint-3/prompts/
chatgpt_scoping_targets: Loki-prompt-UAT-Datasource-Remediation.md
codex_preflight_kind: task
codex_preflight_scope: single-file
codex_preflight_targets_root: _build/Sprint-3/prompts/
codex_preflight_targets: Loki-prompt-UAT-Datasource-Remediation.md
codex_preflight_ready: 'yes'
codex_preflight_reason: ''
codex_preflight_reviewed_local: 1:19 PM - 14-02-2026
codex_preflight_revision: 4
codex_preflight_autocommit: 'yes'
codex_preflight_autopush: 'yes'
codex_preflight_move_to_completed: 'no'
codex_preflight_warn_gate: 'yes'
codex_preflight_warn_mode: ask
codex_preflight_allow_noncritical: 'yes'
codex_preflight_retry_max: '1'
prompt_flow:
  version: v1
  stages:
    draft:
      source: chatgpt
      status: drafted
      updated_utc: '2026-02-14T19:19:05Z'
      scoping:
        kind: task
        scope: single-file
        targets_root: _build/Sprint-3/prompts/
        targets:
        - Loki-prompt-UAT-Datasource-Remediation.md
      next_stage: preflight
    preflight:
      source: prompt-preflight
      status: ready
      ready: 'yes'
      reason: ''
      reviewed_local: 1:19 PM - 14-02-2026
      revision: 4
      kind: task
      scope: single-file
      targets_root: _build/Sprint-3/prompts/
      targets:
      - Loki-prompt-UAT-Datasource-Remediation.md
      policy:
        autocommit: 'yes'
        autopush: 'yes'
        move_to_completed: 'no'
        warn_gate: 'yes'
        warn_mode: ask
        allow_noncritical: 'yes'
        retry_max: '1'
      updated_utc: '2026-02-14T19:19:05Z'
      next_stage: exec
    exec:
      source: prompt-exec
      status: success
      run_local: 1:19 PM - 14-02-2026
      run_ref: /home/luce/apps/loki-logging/temp/codex-sprint/runs.jsonl#loki-prompt-uat-datasource-remediation--r0001
      prompt_sha: 036f80a4a58478ee958f11fd4b95404214cbb1d905d4a64783b384e3aceebaed
      completion_gate: skipped
      last_ok_block: '1'
      commit: 43fb666d83a7
      warning_count: '0'
      move_status: skipped
      updated_utc: '2026-02-14T19:19:07Z'
      next_stage: pipeline
    pipeline:
      source: prompt-pipeline
codex_exec_last_run_status: success
codex_exec_last_run_local: 1:19 PM - 14-02-2026
codex_exec_last_run_dir: /home/luce/apps/loki-logging/temp/codex-sprint/runs.jsonl#loki-prompt-uat-datasource-remediation--r0001
codex_exec_last_run_prompt_sha: 036f80a4a58478ee958f11fd4b95404214cbb1d905d4a64783b384e3aceebaed
codex_exec_last_run_completion_gate: skipped
codex_exec_last_run_last_ok_block: '1'
codex_exec_last_run_warning_count: '0'
codex_exec_commit: 43fb666d83a7
codex_exec_last_run_move_status: skipped
---

# Loki-prompt-UAT-Datasource-Remediation

## Scope
Remediate Sprint-3 dashboard datasource consistency so UAT semantic outcome can pass:
- Normalize dashboard datasource objects to include canonical datasource names (`Prometheus`, `Loki`) where type is known.
- Create explicit datasource contract artifact for current baseline dashboards.
- Regenerate datasource consistency evidence using contract-first logic.

## Affects
- `infra/logging/grafana/dashboards/*.json`
- `_build/Sprint-3/reference/dashboard_datasource_contract.md`
- `_build/Sprint-3/reference/dashboards_datasource_consistency.json`
- `_build/Sprint-3/reference/dashboards_datasource_consistency.md`
- `_build/Sprint-3/reference/phase5c_datasource_remediation/*`

## Guardrails
- No container restarts.
- No Grafana UI click-ops.
- Keep edits deterministic and minimal.
- Create a local backup of dashboards before writing changes.

## Preconditions (hard gates)
STOP unless:
- `infra/logging/grafana/dashboards` exists.
- `python3`, `jq`, and `rg` are available.
- Repository root is `/home/luce/apps/loki-logging`.

## Steps
- Run the command block in order and stop on first failure.

## Acceptance Proofs
- `_build/Sprint-3/reference/dashboard_datasource_contract.md` exists.
- `_build/Sprint-3/reference/dashboards_datasource_consistency.json` exists and has `"PASS": true`.
- `_build/Sprint-3/reference/dashboards_datasource_consistency.md` contains `PASS: \`True\``.

## Done Criteria
- All acceptance proofs are present and PASS.

## Operator Checkpoint
Proceed to run Phase 0 (Preflight Gate) only? (yes/no)

```bash
set -euo pipefail
IFS=$'\n\t'

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

command -v python3 >/dev/null
command -v jq >/dev/null
command -v rg >/dev/null

DASH_DIR="infra/logging/grafana/dashboards"
EVID="_build/Sprint-3/reference"
PHASE="$EVID/phase5c_datasource_remediation"
mkdir -p "$PHASE"

test -d "$DASH_DIR"

BACKUP_DIR="$PHASE/dashboards_backup_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"
cp -a "$DASH_DIR"/*.json "$BACKUP_DIR"/

# 1) Normalize datasource.name fields from datasource.type
python3 - <<'PY' "$DASH_DIR" "$PHASE/datasource_name_normalization.json"
import json, sys
from pathlib import Path

root = Path(sys.argv[1])
out = Path(sys.argv[2])

TYPE_TO_NAME = {
    "prometheus": "Prometheus",
    "loki": "Loki",
}

changed = []
summary = []

for p in sorted(root.glob("*.json")):
    obj = json.loads(p.read_text(encoding="utf-8"))
    file_changes = 0

    stack = [obj]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            ds = node.get("datasource")
            if isinstance(ds, dict):
                t = ds.get("type")
                n = ds.get("name")
                if isinstance(t, str) and t.lower() in TYPE_TO_NAME:
                    expected = TYPE_TO_NAME[t.lower()]
                    if not isinstance(n, str) or not n.strip():
                        ds["name"] = expected
                        file_changes += 1
            for v in node.values():
                stack.append(v)
        elif isinstance(node, list):
            stack.extend(node)

    if file_changes > 0:
        p.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
        changed.append(str(p))
    summary.append({"file": str(p), "changes": file_changes})

payload = {
    "changed_files": changed,
    "changed_count": len(changed),
    "summary": summary,
}
out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
print(json.dumps(payload, indent=2))
PY

# 2) Write explicit datasource contract for baseline dashboards
python3 - <<'PY' "$EVID/dashboard_datasource_contract.md"
import sys
from pathlib import Path

out = Path(sys.argv[1])
lines = []
lines.append("# Dashboard Datasource Contract (Sprint-3)")
lines.append("")
lines.append("This contract defines required datasource names per baseline dashboard.")
lines.append("")
lines.append("| Dashboard file | Required datasource(s) |")
lines.append("|---|---|")
lines.append("| `prometheus-health.json` | `Prometheus` |")
lines.append("| `host_overview.json` | `Prometheus` |")
lines.append("| `containers_overview.json` | `Prometheus` |")
lines.append("| `loki-health.json` | `Loki` |")
lines.append("| `alloy-health.json` | `Loki` |")
lines.append("| `gpu-overview.json` | `Loki` |")
lines.append("")
lines.append("Unknown/new dashboards must reference at least one canonical datasource name: `Prometheus` or `Loki`.")
out.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

# 3) Recompute datasource consistency from contract
python3 - <<'PY' "$DASH_DIR" "$EVID/dashboards_datasource_consistency.json" "$EVID/dashboards_datasource_consistency.md"
import json, sys
from pathlib import Path
from datetime import datetime, timezone

root = Path(sys.argv[1])
out_json = Path(sys.argv[2])
out_md = Path(sys.argv[3])

contract = {
    "prometheus-health.json": {"required": {"Prometheus"}},
    "host_overview.json": {"required": {"Prometheus"}},
    "containers_overview.json": {"required": {"Prometheus"}},
    "loki-health.json": {"required": {"Loki"}},
    "alloy-health.json": {"required": {"Loki"}},
    "gpu-overview.json": {"required": {"Loki"}},
}

def canonical_from_ds(ds):
    if isinstance(ds, str):
        if ds in {"Prometheus", "Loki"}:
            return ds
        return None
    if isinstance(ds, dict):
        name = ds.get("name")
        if isinstance(name, str) and name in {"Prometheus", "Loki"}:
            return name
        typ = ds.get("type")
        if isinstance(typ, str):
            t = typ.lower()
            if t == "prometheus":
                return "Prometheus"
            if t == "loki":
                return "Loki"
    return None

offenders = []
inventory = []

for p in sorted(root.glob("*.json")):
    try:
        obj = json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        offenders.append({
            "file": str(p),
            "issue": "invalid_json",
            "detail": str(exc),
        })
        continue

    names = set()
    stack = [obj]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            ds = node.get("datasource")
            c = canonical_from_ds(ds)
            if c:
                names.add(c)
            for v in node.values():
                stack.append(v)
        elif isinstance(node, list):
            stack.extend(node)

    inventory.append({"file": str(p), "observed": sorted(names)})

    req = contract.get(p.name)
    if req is None:
        if not names:
            offenders.append({
                "file": str(p),
                "issue": "no_canonical_datasource",
                "expected": ["Prometheus", "Loki"],
                "observed": sorted(names),
            })
        continue

    required = req["required"]
    missing = sorted(required - names)
    if missing:
        offenders.append({
            "file": str(p),
            "issue": "missing_required_datasource",
            "expected": sorted(required),
            "observed": sorted(names),
            "missing": missing,
        })

payload = {
    "generated_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "dashboard_count": len(inventory),
    "offender_count": len(offenders),
    "PASS": len(offenders) == 0,
    "offenders": offenders,
    "inventory": inventory,
}
out_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

lines = []
lines.append("# Dashboards Datasource Consistency (Remediated)")
lines.append("")
lines.append(f"- PASS: `{payload['PASS']}`")
lines.append(f"- dashboard_count: `{payload['dashboard_count']}`")
lines.append(f"- offender_count: `{payload['offender_count']}`")
lines.append("")
lines.append("## Inventory")
for row in payload["inventory"]:
    lines.append(f"- file: `{row['file']}` -> observed: `{row['observed']}`")
lines.append("")
lines.append("## Offenders")
if payload["offenders"]:
    for off in payload["offenders"]:
        lines.append(f"- file: `{off.get('file')}`")
        lines.append(f"  - issue: `{off.get('issue')}`")
        if "expected" in off:
            lines.append(f"  - expected: `{off.get('expected')}`")
        if "observed" in off:
            lines.append(f"  - observed: `{off.get('observed')}`")
        if "missing" in off:
            lines.append(f"  - missing: `{off.get('missing')}`")
        if "detail" in off:
            lines.append(f"  - detail: `{off.get('detail')}`")
else:
    lines.append("- none")
lines.append("")
lines.append("## Contract")
lines.append("- See `_build/Sprint-3/reference/dashboard_datasource_contract.md`.")
out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")

if not payload["PASS"]:
    raise SystemExit(2)
PY

# 4) Fast proof checks
rg -q 'PASS:\s*`True`' "$EVID/dashboards_datasource_consistency.md"
python3 - <<'PY' "$EVID/dashboards_datasource_consistency.json"
import json, sys
from pathlib import Path
obj = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
assert obj.get('PASS') is True
PY

echo "UAT_DATASOURCE_REMEDIATION_OK"
```

## Host Path Mapping
- Host-bound paths are intentional for this environment.
- Detected host paths: `/home/luce/apps/loki-logging`.
