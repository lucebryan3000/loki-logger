# Server-Specific API Usage (loki-logging)

This document maps API usage to the actual configuration in this repository and current local environment settings.

## Configuration Snapshot

Source files used:
- `infra/logging/docker-compose.observability.yml`
- `infra/logging/loki-config.yml`
- `infra/logging/alloy-config.alloy`
- `infra/logging/grafana/provisioning/datasources/loki.yml`
- `.env` (non-secret keys only)

As configured on **2026-02-19**:
- Compose project: `logging`
- Grafana bind: `0.0.0.0:9001` (use `http://127.0.0.1:9001` locally, or `http://<server-ip>:9001` remotely)
- Prometheus bind: `0.0.0.0:9004` (use `http://127.0.0.1:9004` locally, or `http://<server-ip>:9004` remotely)
- Loki bind: `0.0.0.0:3200` (use `http://127.0.0.1:3200` locally, or `http://<server-ip>:3200` remotely)
- Loki internal (Docker network `obs`): `http://loki:3100`
- Grafana Loki datasource URL: `http://loki:3100`
- Loki datasource UID in Grafana provisioning: `P8E80F9AEF21F6940`

## Auth Model In This Stack

- **Loki auth is disabled in config** (`auth_enabled: false` in `infra/logging/loki-config.yml`).
- **Grafana API is authenticated** (admin credentials and/or service account tokens).
- **Inference from Loki docs + local config:** because `auth_enabled` is false, tenant headers (`X-Scope-OrgID`) are not required for this deployment.

## Endpoint Table (What To Call)

### Preferred: Direct Loki Queries

- `GET|POST http://127.0.0.1:3200/loki/api/v1/query`
- `GET|POST http://127.0.0.1:3200/loki/api/v1/query_range`
- `GET http://127.0.0.1:3200/loki/api/v1/labels`
- `GET http://127.0.0.1:3200/loki/api/v1/label/<label>/values`
- `GET http://127.0.0.1:3200/ready`

### Grafana API (When Integrating Through Grafana)

- `GET http://127.0.0.1:9001/api/health`
- `POST http://127.0.0.1:9001/api/ds/query`

## Label Schema You Can Depend On

From `infra/logging/alloy-config.alloy`, the following labels are consistently useful:

Global/static:
- `env="sandbox"` on all processing pipelines

Source identity:
- `log_source` values include:
  - `docker`
  - `journald`
  - `rsyslog_syslog`
  - `tool_sink`
  - `telemetry`
  - `gpu_telemetry`
  - `nvidia_telem`
  - `codeswarm_mcp`
  - `vscode_server`

Docker-derived:
- `stack` (`vllm` or `hex`)
- `service` (compose service name)
- `source_type="docker"`

CodeSwarm parsed JSON labels:
- `mcp_kind`
- `mcp_tool`
- `mcp_level`

GPU CSV labels:
- `stream` (`gpu` or `proc`)
- `gpu_name` (on GPU stream records)

## Query Recipes

### 1) Confirm Loki Is Reachable

```bash
curl -fsS "http://127.0.0.1:3200/ready"
```

Expected: HTTP 200 and body `ready`.

### 2) Discover Labels Before Building Queries

```bash
curl -sS "http://127.0.0.1:3200/loki/api/v1/labels"
```

```bash
curl -sS "http://127.0.0.1:3200/loki/api/v1/label/log_source/values"
```

### 3) Query Your Example Error Directly (Loki)

Error text:
`Error: Cannot find module '/home/luce/apps/hex/dist/mcp/server/index.js'`

```bash
curl -G "http://127.0.0.1:3200/loki/api/v1/query_range" \
  --data-urlencode 'query={env="sandbox",stack="hex"} |= "Cannot find module" |= "/home/luce/apps/hex/dist/mcp/server/index.js"' \
  --data-urlencode "start=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --data-urlencode "end=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --data-urlencode 'limit=500' \
  --data-urlencode 'direction=backward'
```

If stack label is missing in some lines, broaden:

```bash
curl -G "http://127.0.0.1:3200/loki/api/v1/query_range" \
  --data-urlencode 'query={env="sandbox"} |= "Cannot find module" |= "/home/luce/apps/hex/dist/mcp/server/index.js"' \
  --data-urlencode "since=24h" \
  --data-urlencode 'limit=500'
```

### 4) Count Frequency (5m Buckets)

```bash
curl -G "http://127.0.0.1:3200/loki/api/v1/query" \
  --data-urlencode 'query=sum by (service) (count_over_time({env="sandbox",stack="hex"} |= "Cannot find module" [5m]))'
```

### 5) Query Through Grafana API (`/api/ds/query`)

Use a Grafana service account token:

```bash
FROM_MS="$(($(date -u +%s%3N) - 24*60*60*1000))"
TO_MS="$(date -u +%s%3N)"

curl -sS -X POST "http://127.0.0.1:9001/api/ds/query" \
  -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "from":"'"${FROM_MS}"'",
    "to":"'"${TO_MS}"'",
    "queries":[
      {
        "refId":"A",
        "datasource":{"uid":"P8E80F9AEF21F6940"},
        "expr":"{env=\"sandbox\",stack=\"hex\"} |= \"Cannot find module\" |= \"/home/luce/apps/hex/dist/mcp/server/index.js\"",
        "queryType":"range",
        "maxLines":500
      }
    ]
  }'
```

Notes:
- Grafana accepts several time formats; epoch milliseconds are the safest for strict API clients.
- For long-term automation, prefer direct Loki API unless you explicitly need Grafana RBAC mediation.
- If `/api/ds/query` payload validation fails, copy the exact Loki query JSON from Grafana Explore → Query inspector and mirror that structure.

## Minimal Integration Flow For Another App

1. Health gate
- Call `GET /ready` on Loki.

2. Capability discovery
- Call `/loki/api/v1/labels` and selected `/label/<name>/values`.

3. Execute narrow query
- Start with labels (`env`, `stack`, `log_source`), then line filters.

4. Parse response defensively
- Validate `status=="success"` and expected `data.resultType`.

5. Backoff/retry
- Retry transient HTTP 5xx and network errors with exponential backoff.

## Known Repo-Specific Caveats

- `.env` includes `LOKI_PUBLISH`, but compose currently binds Loki using `LOKI_HOST`/`LOKI_PORT` directly; `LOKI_PUBLISH` is not consumed by `docker-compose.observability.yml`.
- This means Loki is currently externally reachable on host interfaces at port `3200` per `.env`.
- If you want internal-only Loki again, set `LOKI_HOST=127.0.0.1` (or remove exposed port mapping) and redeploy.

## Fast Troubleshooting

No matches for known error:
- Expand time window (`since=7d`).
- Remove restrictive labels and re-add one by one.
- Confirm source labels exist:
  - `/label/stack/values`
  - `/label/service/values`
  - `/label/log_source/values`

API failure from app:
- Check Loki readiness: `curl -fsS http://127.0.0.1:3200/ready`
- Check container: `docker compose -p logging -f infra/logging/docker-compose.observability.yml ps loki`
- Check logs: `docker logs logging-loki-1 --tail 200`

## Cross-References

- [authoritative-loki-grafana-api.md](authoritative-loki-grafana-api.md)
- [../reference.md](../reference.md)
- [../operations.md](../operations.md)
