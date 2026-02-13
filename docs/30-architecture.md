# Architecture

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
- Grafana: 127.0.0.1:9001
- Prometheus: 127.0.0.1:9004
- Loki: internal-only (http://loki:3100)
