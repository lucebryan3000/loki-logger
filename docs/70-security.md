# Security
- Loopback-only endpoints for Grafana/Prometheus
- Loki internal-only
- Secrets in infra/logging/.env (never print; never commit)
- Keep label cardinality low; avoid IDs in labels
