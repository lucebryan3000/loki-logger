# Architecture

# Data Flow
Sources -> Alloy -> Loki -> Grafana

Sources include Docker logs, `/home/luce/_logs/*.log`, `/home/luce/_telemetry/*.jsonl`, and `/home/luce/apps/vLLM/_data/mcp-logs/*.log`.

Prometheus scrapes node_exporter, cAdvisor, and configured metrics endpoints.

# Network
- Docker network from compose file: `/home/luce/apps/loki-logging/infra/logging/docker-compose.observability.yml`
- Grafana: 127.0.0.1:9001
- Prometheus: 127.0.0.1:9004
- Loki: internal only

Evidence:
- `/home/luce/apps/loki-logging/temp/codex/evidence/Loki-prompt-20/20260213T040316Z/local-capture`
