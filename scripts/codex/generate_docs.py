#!/usr/bin/env python3
"""
Generate Loki logging docs (quickstart, as-installed, as-configured, architecture, runbooks,
troubleshooting, validation, security, maintenance) using evidence snapshots.
Assumes PRISM_EVID_DIR is set by prism/evidence.sh and REPO_ROOT points to repo root.
"""
from __future__ import annotations

import json
import os
import pathlib
import textwrap

REPO = pathlib.Path(os.environ.get("REPO_ROOT", ".")).resolve()
DOCS = REPO / "docs"
EVID = pathlib.Path(os.environ["PRISM_EVID_DIR"])

DOCS.mkdir(parents=True, exist_ok=True)
(DOCS / "snippets").mkdir(parents=True, exist_ok=True)


def read_text(path: pathlib.Path, limit: int = 120_000) -> str:
    try:
        data = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""
    return data if len(data) <= limit else data[:limit] + "\n... (truncated)\n"


meta = {
    "generated_local": os.environ.get("DATE_LOCAL", ""),
    "generated_utc": os.environ.get("DATE_UTC", ""),
    "git_branch": os.environ.get("GIT_BRANCH", ""),
    "git_head": os.environ.get("GIT_HEAD", ""),
    "compose_project": os.environ.get("COMPOSE_PROJECT_NAME", ""),
    "grafana_port": os.environ.get("GRAFANA_PORT", ""),
    "prom_port": os.environ.get("PROM_PORT", ""),
    "docker_version": os.environ.get("DOCKER_VER", ""),
    "compose_version": os.environ.get("COMPOSE_VER", ""),
    "env_stat": os.environ.get("ENV_STAT", ""),
    "evidence_dir": str(EVID),
}

compose_ps = read_text(EVID / "compose_ps.txt")
docker_ps = read_text(EVID / "docker_ps.txt")
cfg_hashes = read_text(EVID / "config.sha256")
telemetry_status = read_text(EVID / "telemetry_writer_status.txt")
rendered = read_text(EVID / "compose_rendered.yml")

loki_cfg = read_text(REPO / "infra/logging/loki-config.yml", 80_000)
alloy_cfg = read_text(REPO / "infra/logging/alloy-config.alloy", 80_000)
prom_cfg = read_text(REPO / "infra/logging/prometheus/prometheus.yml", 80_000)

(DOCS / "snippets" / "loki-config.yml").write_text(loki_cfg, encoding="utf-8")
(DOCS / "snippets" / "alloy-config.alloy").write_text(alloy_cfg, encoding="utf-8")
(DOCS / "snippets" / "prometheus.yml").write_text(prom_cfg, encoding="utf-8")

index = textwrap.dedent(
    f"""
    # Loki Logging Documentation

    Generated: {meta['generated_local']} (UTC {meta['generated_utc']})
    Git: `{meta['git_branch']}` @ `{meta['git_head']}`
    Compose project: `{meta['compose_project']}`

    - [Quickstart](README.md)
    - [As Installed](10-as-installed.md)
    - [As Configured](20-as-configured.md)
    - [Architecture](30-architecture.md)
    - [Operations Runbooks](40-runbooks.md)
    - [Troubleshooting](50-troubleshooting.md)
    - [Validation & Tests](60-validation.md)
    - [Security](70-security.md)
    - [Maintenance](80-maintenance.md)

    Snippets:
    - [Loki config](snippets/loki-config.yml)
    - [Alloy config](snippets/alloy-config.alloy)
    - [Prometheus config](snippets/prometheus.yml)

    Evidence used to generate these docs:
    - {meta['evidence_dir']}
    """
).strip() + "\n"

quickstart = textwrap.dedent(
    f"""
    # Loki Logging Quickstart

    ## Endpoints (loopback)
    - Grafana: http://127.0.0.1:{meta['grafana_port']}
    - Prometheus: http://127.0.0.1:{meta['prom_port']}
    - Loki: internal-only (docker network `obs`), http://loki:3100

    ## Start / Stop
    - Up: scripts/mcp/logging_stack_up.sh
    - Down: scripts/mcp/logging_stack_down.sh
    - Health: scripts/mcp/logging_stack_health.sh

    ## What this stack ships into Loki
    - Docker logs (via Alloy docker source)
    - File tails:
      - /home/luce/_logs/*.log
      - /home/luce/_telemetry/*.jsonl
      - /home/luce/apps/vLLM/_data/mcp-logs/*.log (CodeSwarm MCP)

    ## Proof queries (LogQL)
    Broad selector must use a non-empty matcher (e.g. env=~".+").
    - Telemetry: {{env=~".+"}} |= "telemetry tick"
    - CodeSwarm labeled: {{env=~".+",log_source="codeswarm_mcp"}} |= "codeswarm_mcp_proof_"

    ## Secrets posture
    - .env present: {bool(meta['env_stat'])}
    - .env stat: {meta['env_stat'] or "(missing)"}
    Never print .env contents in docs/evidence.
    """
).strip() + "\n"

as_installed = textwrap.dedent(
    f"""
    # As Installed

    ## Host / Tooling
    - Docker: {meta['docker_version']}
    - Compose: {meta['compose_version']}

    ## Runtime (compose ps)
    {compose_ps}

    ## Containers (docker ps)
    {docker_ps}

    ## Telemetry writer (systemd)
    {telemetry_status}
    """
).strip() + "\n"

as_configured = textwrap.dedent(
    f"""
    # As Configured

    ## Key files
    - infra/logging/docker-compose.observability.yml
    - infra/logging/loki-config.yml
    - infra/logging/alloy-config.alloy
    - infra/logging/prometheus/prometheus.yml
    - infra/logging/grafana/provisioning/**
    - infra/logging/grafana/dashboards/**

    ## Config hashes (sha256)
    {cfg_hashes}

    ## Rendered compose (truncated)
    {rendered}
    """
).strip() + "\n"

architecture = textwrap.dedent(
    f"""
    # Architecture

    ## Data flow
    Sources → Alloy → Loki → Grafana
    Metrics → Prometheus → Grafana

    ## Network
    - Docker network: obs
    - Loopback exposed:
      - Grafana: 127.0.0.1:{meta['grafana_port']}
      - Prometheus: 127.0.0.1:{meta['prom_port']}
    - Loki internal only on obs

    ## Data flow (conceptual)
    - Hosts → Alloy → Loki → Grafana
    - Metrics: Prometheus → Grafana
    """
).strip() + "\n"

runbooks = textwrap.dedent(
    f"""
    # Operations Runbooks

    Stack control
    - Up: scripts/mcp/logging_stack_up.sh
    - Down: scripts/mcp/logging_stack_down.sh
    - Health: scripts/mcp/logging_stack_health.sh

    Force reload Alloy config
    - docker compose -f infra/logging/docker-compose.observability.yml up -d --force-recreate alloy

    Validate CodeSwarm ingestion (manual)
    - append marker to /home/luce/apps/vLLM/_data/mcp-logs/mcp-test.log
    - queries:
      - broad: {{env=~".+"}} |= "<marker>"
      - labeled: {{env=~".+",log_source="codeswarm_mcp"}} |= "<marker>"

    Prometheus rules
    - curl -sf http://127.0.0.1:{meta['prom_port']}/api/v1/rules | grep loki_logging_v1
    """
).strip() + "\n"

troubleshooting = textwrap.dedent(
    """
    # Troubleshooting

    Alloy parse/load errors
    - illegal character '#', block comment not terminated, sys.env missing, initial load failure
    - Fix: use // comments, ensure block nesting valid, force reload Alloy, verify mounts via docker inspect.

    Loki query returns nothing
    - Use selector {env=~".+"}; recompute timestamps; ensure marker written before end.

    "entry too far behind"
    - Clear stale file backlog and restart Alloy tailer positions; Loki already allows old samples in sandbox.
    """
).strip() + "\n"

validation = textwrap.dedent(
    f"""
    # Validation & Tests (Strict)

    Required checks
    1. Grafana health: curl -sf http://127.0.0.1:{meta['grafana_port']}/api/health
    2. Prometheus ready: curl -sf http://127.0.0.1:{meta['prom_port']}/-/ready
    3. Telemetry: systemctl is-active loki-telemetry-writer.service; Loki contains {{env=~".+"}} |= "telemetry tick"
    4. CodeSwarm MCP: broad {{env=~".+"}} |= "<marker>"; labeled {{env=~".+",log_source="codeswarm_mcp"}} |= "<marker>"
    """
).strip() + "\n"

security = textwrap.dedent(
    """
    # Security
    - Loopback-only endpoints for Grafana/Prometheus
    - Loki internal-only
    - Secrets in infra/logging/.env (never print; never commit)
    - Keep label cardinality low; avoid IDs in labels
    """
).strip() + "\n"

maintenance = textwrap.dedent(
    """
    # Maintenance
    - Prefer pinned images; upgrade intentionally
    - After truncating tailed files, restart Alloy to reset positions
    - Evidence accumulation: temp/codex-sprint/ (current), temp/codex/evidence/ + temp/.artifacts/prism/evidence/ (legacy)
    - Rotate or prune as desired in sandbox
    """
).strip() + "\n"

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
    (DOCS / name).write_text(content, encoding="utf-8")

manifest = {
    "meta": meta,
    "docs_dir": str(DOCS),
    "files": sorted(files.keys()),
    "snippets": [
        "snippets/loki-config.yml",
        "snippets/alloy-config.alloy",
        "snippets/prometheus.yml",
    ],
}
(DOCS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
