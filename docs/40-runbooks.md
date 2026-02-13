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
  - broad: {env=~".+"} |= "<marker>"
  - labeled: {env=~".+",log_source="codeswarm_mcp"} |= "<marker>"

Prometheus rules
- curl -sf http://127.0.0.1:/api/v1/rules | grep loki_logging_v1
