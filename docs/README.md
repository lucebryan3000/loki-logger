# Loki Logging Quickstart

This repo deploys a local observability stack with Grafana, Loki, Alloy, Prometheus, node_exporter, and cAdvisor.

# URLs
- Grafana: http://127.0.0.1:9001
- Prometheus: http://127.0.0.1:9004
- Loki: internal docker network endpoint `http://loki:3100`

# Control Scripts
- `scripts/mcp/logging_stack_up.sh`
- `scripts/mcp/logging_stack_down.sh`
- `scripts/mcp/logging_stack_health.sh`

Runbook reference:
- `_build/Sprint-1/Loki-logging-1.md`

Evidence:
- `/home/luce/apps/loki-logging/temp/codex/evidence/Loki-prompt-20/20260213T040316Z/local-capture`
