# Security

# Exposure
- Grafana and Prometheus bind to loopback.
- Loki is internal on docker network.

# Secrets
- Secrets live in `infra/logging/.env`.
- Secret values are not captured in docs.
- Keep `.env` gitignored and permission-restricted.

Evidence:
- `/home/luce/apps/loki-logging/temp/codex/evidence/Loki-prompt-20/20260213T040316Z/local-capture`
