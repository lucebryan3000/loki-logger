# Security

- Grafana/Prometheus are loopback-bound (or LAN-bound if configured).
- Loki is internal-only unless explicitly published.
- Secrets live in infra/logging/.env; never print or commit secret values.
