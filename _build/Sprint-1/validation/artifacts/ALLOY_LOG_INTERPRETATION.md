# Alloy Log Interpretation (Sandbox)
Run: 20260212T222441Z

## Expected on restart
- "interrupt received" indicates graceful SIGINT/SIGTERM handling.
- "context canceled" in downstream components during shutdown is expected.

## Optional in sandbox
- Journald ingestion may timeout in containerized setups depending on permissions/mounts.
- If timeout noise is persistent and journald is not required for v1, disabling journald is acceptable.

## Evidence
- /home/luce/apps/loki-logging/.artifacts/prism/evidence/20260212T222441Z
