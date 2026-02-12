
## Phase B — CodeSwarm mounts applied (20260212T212226Z)
- File: /home/luce/apps/vLLM/docker-compose.yml
- Binds added:
  - /home/luce/apps/vLLM/_data/mcp-state:/logs
  - /home/luce/apps/vLLM/_data/mcp-logs:/logs/mcp
- Evidence: /home/luce/apps/loki-logging/.artifacts/prism/evidence/20260212T212226Z

## Phase H — Tighten local logging (20260212T234329Z)
- File: /home/luce/apps/vLLM/docker-compose.yml
- Service: codeswarm-mcp
- Change: logging.options.max-file -> "3"
- Before: 3
- After: 3
- Runtime (inspect): 3
- Evidence dir: /home/luce/apps/loki-logging/temp/.artifacts/prism/evidence/20260212T234329Z
