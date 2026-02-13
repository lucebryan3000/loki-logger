# Maintenance

# Upgrades
- Prefer pinned image tags.
- Update cycle: `docker compose pull` then `docker compose up -d`.

# Evidence Retention
- Prompt-exec evidence: `temp/codex/evidence/...`
- Legacy captures may exist under `temp/.artifacts/...`

# Hygiene
- Restart Alloy after truncating tailed files.
- Keep a single canonical Prometheus rule mount.

Evidence:
- `/home/luce/apps/loki-logging/temp/codex/evidence/Loki-prompt-20/20260213T040316Z/local-capture`
