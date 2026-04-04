# AGENTS.md

This repository already maintains the fuller agent-facing guide in `CLAUDE.md`.

Use `CLAUDE.md` as the primary operating reference. This file only records additional workflows and commands verified in the current worktree.

## Execution Context

- Run commands from the repository root so relative paths in scripts resolve correctly.

## Prerequisites

- `make lint` and `make lint-scripts`: requires `shellcheck` on `PATH`.
- `./scripts/prod/mcp/test_suite.sh`: no extra prerequisites for static checks; install `shellcheck` to enable its lint section.
- Runtime health validation in `test_suite.sh` and stack checks require Docker running and a valid root `.env` for the compose project.

## Additional Verified Commands

```bash
# Run shellcheck across repo scripts
make lint
make lint-scripts

# Run stack validation
# - static config checks always
# - shellcheck checks when installed
# - runtime health checks only when the stack is up
./scripts/prod/mcp/test_suite.sh
```

## When To Run What

| Change Type | Run |
|---|---|
| Shell scripts under `scripts/`, `src/`, or `infra/logging/scripts/` | `make lint` |
| Stack config (`infra/logging/*.yml`, `infra/logging/*.alloy`, provisioning/rules) | `./scripts/prod/mcp/test_suite.sh` |
| Operational script behavior (`scripts/prod/mcp/*.sh`) | `make lint` then `./scripts/prod/mcp/test_suite.sh` |

## Workflow Notes

- Prefer `make lint` before changing shell scripts; it covers scripts under `scripts/`, `src/`, and `infra/logging/scripts/`.
- Prefer `./scripts/prod/mcp/test_suite.sh` for validation when changing stack config or operational scripts; it combines static checks with runtime checks when containers are running.

## Failure Triage

- If `test_suite.sh` skips runtime checks, confirm the stack is up with `docker compose -p logging -f infra/logging/docker-compose.observability.yml ps`.
- If health checks fail, run `./scripts/prod/mcp/logging_stack_health.sh` for per-service pass/fail signals.
- If lint fails, resolve `shellcheck` findings first; rerun `make lint`.

## Destructive Command Safety

- `./scripts/prod/mcp/logging_stack_down.sh` preserves volumes by default.
- `./scripts/prod/mcp/logging_stack_down.sh --purge` permanently deletes Loki, Prometheus, and Grafana data volumes.

## Blocked Workflow: Add Log Source

- `./scripts/add-log-source.sh` is present, but it depends on `.claude/prompts/loki-logging-setup-playbook.md` and `.claude/prompts/loki-logging-setup-reference.md`.
- This checkout currently does not include `.claude/prompts/`; treat this workflow as blocked until those files are restored or the script is updated to use available prompt assets.
