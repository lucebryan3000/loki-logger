# Runbooks

Health:
- scripts/mcp/logging_stack_health.sh

Force reload Alloy:
- docker compose -f infra/logging/docker-compose.observability.yml up -d --force-recreate alloy

Loki queries (LogQL):
- Telemetry: {env=~".+"} |= "telemetry tick"
- CodeSwarm broad: {env=~".+"} |= "codeswarm_mcp_proof_"
- CodeSwarm labeled: {env=~".+",log_source="codeswarm_mcp"} |= "codeswarm_mcp_proof_"
