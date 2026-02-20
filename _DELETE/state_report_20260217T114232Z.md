# State Report — Grafana as Authority (20260217T114232Z)

## Expected contract
- Loki receives logs end-to-end.
- Grafana provisioned dashboards represent authoritative visibility.
- Grafana unified alert rules are file-provisioned.
- Verifier emits machine-readable PASS artifact.

## Observed (runtime + source)
- Grafana health database: ok
- Target dashboards present by UID count (pipeline-health, host-container-overview): 2
- Alert UID logging-e2e-marker-missing present: yes
- Alert UID logging-total-ingest-down present: yes
- Alert provenance=file present: yes
- Loki total-ingest query series count (5m): 1
- Loki marker query series count (15m): 0
- Prometheus up series count: 6
- E2E timer enabled: yes
- E2E PASS lines in last 24h: 2
- Verifier artifact pass: true

## Expected vs observed gaps
- Gap: direct one-off E2E script run produced  while verifier run immediately after passed.
- Interpretation: intermittent journald visibility/injection timing issue is plausible; pipeline path itself remains healthy per verifier + timer evidence.

## Blockers (ranked)
1. Intermittent one-off E2E flake at journald marker check (non-deterministic precondition).
2. Marker query may be empty when no marker emitted in last 15m (expected without fresh test injection).
3. No hard blocker on Grafana/Loki/Prom readiness detected.
