# Loki Logging Quickstart

## Endpoints (loopback)
- Grafana: http://127.0.0.1:
- Prometheus: http://127.0.0.1:
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
- Telemetry: {env=~".+"} |= "telemetry tick"
- CodeSwarm labeled: {env=~".+",log_source="codeswarm_mcp"} |= "codeswarm_mcp_proof_"

## Secrets posture
- .env present: False
- .env stat: (missing)
Never print .env contents in docs/evidence.
