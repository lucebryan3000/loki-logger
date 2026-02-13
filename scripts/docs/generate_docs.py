#!/usr/bin/env python3
import json
import os
from pathlib import Path

def rtext(p: Path, limit=140_000) -> str:
    try:
        s = p.read_text(encoding="utf-8", errors="replace")
        return s if len(s) <= limit else s[:limit] + "\n... (truncated)\n"
    except Exception:
        return ""

def main():
    repo = Path(os.environ.get("REPO", "/home/luce/apps/loki-logging"))
    evid = Path(os.environ["EVID_DIR"])
    docs = Path(os.environ.get("DOCS_DIR", str(repo / "docs")))
    docs.mkdir(parents=True, exist_ok=True)
    (docs / "snippets").mkdir(parents=True, exist_ok=True)

    # IMPORTANT: avoid literal markdown fence lines in THIS SOURCE.
    fence = "`" * 3

    meta = {
        "generated_local": rtext(evid / "generated_local.txt", 500).strip(),
        "generated_utc": rtext(evid / "generated_utc.txt", 500).strip(),
        "git_head": rtext(evid / "git_head.txt", 500).strip(),
        "git_branch": rtext(evid / "git_branch.txt", 500).strip(),
        "compose_project": os.environ.get("COMPOSE_PROJECT_NAME", ""),
        "compose_file": os.environ.get("OBS", ""),
        "evidence_dir": str(evid),
        "docker_version": rtext(evid / "docker_version.txt", 500).strip(),
        "compose_version": rtext(evid / "compose_version.txt", 2000).strip(),
        "grafana_port": os.environ.get("GRAFANA_PORT", ""),
        "prom_port": os.environ.get("PROM_PORT", ""),
        "env_stat": rtext(evid / "env_stat.txt", 500).strip(),
        "runbook_ref": os.environ.get("RUNBOOK_REF", "_build/Sprint-1/Loki-logging-1.md"),
    }

    # Evidence excerpts
    compose_ps = rtext(evid / "compose_ps.txt", 80_000)
    docker_ps = rtext(evid / "docker_ps.txt", 80_000)
    cfg_hashes = rtext(evid / "config_sha256.txt", 80_000)
    telemetry_status = rtext(evid / "telemetry_writer_status.txt", 80_000)
    rendered = rtext(evid / "compose_rendered.yml", 140_000)

    # Snippets of configs (these may include fences; safe because they’re written to docs, not parsed as prompt)
    (docs / "snippets" / "loki-config.yml").write_text(rtext(repo / "infra/logging/loki-config.yml"), encoding="utf-8")
    (docs / "snippets" / "alloy-config.alloy").write_text(rtext(repo / "infra/logging/alloy-config.alloy"), encoding="utf-8")
    (docs / "snippets" / "prometheus.yml").write_text(rtext(repo / "infra/logging/prometheus/prometheus.yml"), encoding="utf-8")

    index = f"""# Loki Logging Documentation

Generated: {meta["generated_local"]} (UTC {meta["generated_utc"]})
Git: `{meta["git_branch"]}` @ `{meta["git_head"]}`
Compose project: `{meta["compose_project"]}`

- [Quickstart](README.md)
- [As Installed](10-as-installed.md)
- [As Configured](20-as-configured.md)
- [Architecture](30-architecture.md)
- [Runbooks](40-runbooks.md)
- [Troubleshooting](50-troubleshooting.md)
- [Validation & Tests](60-validation.md)
- [Security](70-security.md)
- [Maintenance](80-maintenance.md)

Snippets:
- [Loki config](snippets/loki-config.yml)
- [Alloy config](snippets/alloy-config.alloy)
- [Prometheus config](snippets/prometheus.yml)

Evidence:
- `{meta["evidence_dir"]}`
"""

    quickstart = f"""# Loki Logging Quickstart

Endpoints (loopback):
- Grafana: http://127.0.0.1:{meta["grafana_port"]}
- Prometheus: http://127.0.0.1:{meta["prom_port"]}
- Loki: internal-only on docker network `obs` at http://loki:3100

Control scripts:
- scripts/mcp/logging_stack_up.sh
- scripts/mcp/logging_stack_down.sh
- scripts/mcp/logging_stack_health.sh

Runbook reference:
- `{meta["runbook_ref"]}`

Secrets posture:
- `.env stat`: `{meta["env_stat"] or "(missing)"}`
- Secret values are never printed in docs/evidence.
"""

    as_installed = f"""# As Installed

Tooling:
- Docker: `{meta["docker_version"]}`
- Compose: `{meta["compose_version"]}`

Host (uname):
{fence}
{rtext(evid / "uname.txt", 4000).strip()}
{fence}

os-release:
{fence}
{rtext(evid / "os-release.txt", 8000).strip()}
{fence}

docker compose ps:
{fence}
{compose_ps.strip()}
{fence}

docker ps:
{fence}
{docker_ps.strip()}
{fence}

Telemetry writer (systemd):
{fence}
{telemetry_status.strip()}
{fence}
"""

    as_configured = f"""# As Configured

Key files:
- infra/logging/docker-compose.observability.yml
- infra/logging/loki-config.yml
- infra/logging/alloy-config.alloy
- infra/logging/prometheus/prometheus.yml
- infra/logging/grafana/provisioning/**
- infra/logging/grafana/dashboards/**

Config hashes (sha256):
{fence}
{cfg_hashes.strip()}
{fence}

Rendered compose (truncated):
{fence}
{rendered.strip()}
{fence}
"""

    architecture = f"""# Architecture

Data flow:
Sources -> Alloy -> Loki -> Grafana
Metrics -> Prometheus -> Grafana

Sources include:
- Docker logs (via docker socket)
- /home/luce/_logs/*.log
- /home/luce/_telemetry/*.jsonl
- /home/luce/apps/vLLM/_data/mcp-logs/*.log (CodeSwarm MCP)

Network:
- docker network: obs
- Grafana: 127.0.0.1:{meta["grafana_port"]}
- Prometheus: 127.0.0.1:{meta["prom_port"]}
- Loki: internal-only (http://loki:3100)
"""

    runbooks = """# Runbooks

Health:
- scripts/mcp/logging_stack_health.sh

Force reload Alloy:
- docker compose -f infra/logging/docker-compose.observability.yml up -d --force-recreate alloy

Loki queries (LogQL):
- Telemetry: {env=~".+"} |= "telemetry tick"
- CodeSwarm broad: {env=~".+"} |= "codeswarm_mcp_proof_"
- CodeSwarm labeled: {env=~".+",log_source="codeswarm_mcp"} |= "codeswarm_mcp_proof_"
"""

    troubleshooting = """# Troubleshooting

Alloy parse errors:
- No '#' comments (use '//' or block comments).
- Avoid invalid nested blocks in Alloy config.
- Force-recreate alloy after config changes.

Empty Loki results:
- Avoid invalid selector {}. Use {env=~".+"} for broad queries.
- Ensure query window end timestamp is current (recompute end per retry).
"""

    validation = f"""# Validation & Tests (Strict)

Required:
1) Grafana health:
- curl -sf http://127.0.0.1:{meta["grafana_port"]}/api/health

2) Prometheus ready:
- curl -sf http://127.0.0.1:{meta["prom_port"]}/-/ready

3) Loki telemetry:
- {{"env"=~".+"}} |= "telemetry tick"

4) CodeSwarm MCP labeled proof:
- {{"env"=~".+","log_source"="codeswarm_mcp"}} |= "codeswarm_mcp_proof_"
"""

    security = """# Security

- Grafana/Prometheus are loopback-bound (or LAN-bound if configured).
- Loki is internal-only unless explicitly published.
- Secrets live in infra/logging/.env; never print or commit secret values.
"""

    maintenance = """# Maintenance

- Prefer pinned image tags and intentional upgrades.
- If you truncate tailed files, restart Alloy to reset positions.
- Evidence roots:
  - temp/codex/evidence/ (runner)
  - temp/.artifacts/prism/evidence/ (legacy)
"""

    files = {
        "INDEX.md": index,
        "README.md": quickstart,
        "10-as-installed.md": as_installed,
        "20-as-configured.md": as_configured,
        "30-architecture.md": architecture,
        "40-runbooks.md": runbooks,
        "50-troubleshooting.md": troubleshooting,
        "60-validation.md": validation,
        "70-security.md": security,
        "80-maintenance.md": maintenance,
    }

    for name, content in files.items():
        (docs / name).write_text(content.rstrip() + "\n", encoding="utf-8")

    manifest = {"meta": meta, "docs_dir": str(docs), "files": sorted(files.keys()), "snippets": ["snippets/loki-config.yml","snippets/alloy-config.alloy","snippets/prometheus.yml"]}
    (docs / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
