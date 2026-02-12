# Evidence v2 (NDJSON + temp/.artifacts)
Run UTC: 20260212T224913Z

## New location
- temp/.artifacts/prism/evidence/<RUN_UTC>/

## Files per run
- exec.log
- events.ndjson
- optional large artifacts (json/yml snapshots)

## Prompt pattern
```bash
source scripts/prism/evidence.sh
prism_init
prism_event phase_start phase=X
prism_cmd "check grafana" -- curl --connect-timeout 5 --max-time 20 -sf http://127.0.0.1:9001/api/health
prism_event phase_ok phase=X
```
