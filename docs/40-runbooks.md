# Runbooks

# Stack Control
- Up: `scripts/mcp/logging_stack_up.sh`
- Down: `scripts/mcp/logging_stack_down.sh`
- Health: `scripts/mcp/logging_stack_health.sh`

# Query Checks
- Telemetry broad query: `{env=~".+"} |= "telemetry tick"`
- CodeSwarm broad query: `{env=~".+"} |= "codeswarm_mcp_proof_"`
- CodeSwarm labeled query: `{env=~".+",log_source="codeswarm_mcp"} |= "codeswarm_mcp_proof_"`

Evidence:
- `/home/luce/apps/loki-logging/temp/codex/evidence/Loki-prompt-20/20260213T040316Z/local-capture`
