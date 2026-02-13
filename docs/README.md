# Loki Logging Quickstart

Endpoints (loopback):
- Grafana: http://127.0.0.1:9001
- Prometheus: http://127.0.0.1:9004
- Loki: internal-only on docker network `obs` at http://loki:3100

Control scripts:
- scripts/mcp/logging_stack_up.sh
- scripts/mcp/logging_stack_down.sh
- scripts/mcp/logging_stack_health.sh

Runbook reference:
- `_build/Sprint-1/Loki-logging-1.md`

Secrets posture:
- `.env stat`: `600 luce:luce infra/logging/.env`
- Secret values are never printed in docs/evidence.
