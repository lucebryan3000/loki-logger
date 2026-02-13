# codex-sprint Anti-Patterns (Enforced)

These are enforced by `verify.py` and sync guardrails to prevent drift.

1. Avoid phase-specific script proliferation.
- Do not create `evolve_v1.py`, `evolve_v2.py`, `evolve_v3.py`.
- Use `evolve.py` as the only evolution builder.

2. Avoid hidden mutating behavior in utility commands.
- `--help` paths must not execute build/sync logic.
- Keep help paths side-effect free.

3. Avoid sync without canonical allowlist.
- `sync_helpers_to_prod.sh` in `--mode all` must source `sync.allowlist`.
- Do not add ad hoc files directly in `temp/codex-sprint/`.

4. Avoid distributed defaults in multiple scripts.
- Use `codex_sprint.config.json` for default paths/policies.
- Use `codex_sprint.py` as canonical entrypoint for standard workflows.

5. Avoid high-branching logic in shell scripts.
- Scripts should perform deterministic mechanics only.
- Let the LLM pick remediation/strategy when gates fail.
