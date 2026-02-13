# Validation and Tests

# Required Checks
1. Health endpoints return OK.
2. `loki-telemetry-writer.service` is active.
3. Loki queries show expected telemetry and CodeSwarm markers.

# Suggested Automation
- Execute validation prompt if present:
  `_build/Sprint-1/Prompts/Loki-prompt-17-validation.md`

Evidence:
- `/home/luce/apps/loki-logging/temp/codex/evidence/Loki-prompt-20/20260213T040316Z/local-capture`
