# Cloudflared Log Queries

**Service**: cloudflared (Cloudflare tunnel daemon)
**Ingestion**: systemd journal → Alloy (`loki.source.journal`) → Loki
**Label**: `env="sandbox"` (shared with all journal logs)

---

## Quick Queries

### All cloudflared logs (last 24h)
```logql
{env="sandbox"} |~ "cloudflared"
```

### Tunnel connection events
```logql
{env="sandbox"} |~ "cloudflared.*Registered tunnel connection"
```

### Connection errors
```logql
{env="sandbox"} |~ "cloudflared.*(ERR|WRN|error|failed)"
```

### Specific log levels
```logql
{env="sandbox"} |~ "cloudflared.*INF"   # Info
{env="sandbox"} |~ "cloudflared.*WRN"   # Warnings
{env="sandbox"} |~ "cloudflared.*ERR"   # Errors
```

---

## Sample Log Format

```
2026-02-15T03:05:01Z INF Registered tunnel connection connIndex=3 connection=9eac3ea5-7f8a-41e3-b860-abf5655ebc9d event=0 ip=198.41.200.33 location=dfw08 protocol=quic
2026-02-15T03:04:45Z ERR failed to accept incoming stream requests error="failed to accept QUIC stream: timeout: no recent network activity" connIndex=2
2026-02-15T03:04:45Z WRN Connection terminated error="accept stream listener encountered a failure while serving" connIndex=2
```

---

## Grafana Dashboard Queries

### Panel: Tunnel Connection Status
```logql
sum by (location) (
  count_over_time({env="sandbox"} |~ "cloudflared.*Registered tunnel connection" [5m])
)
```

### Panel: Error Rate
```logql
rate({env="sandbox"} |~ "cloudflared.*(ERR|error|failed)" [5m])
```

### Panel: Connection Terminations
```logql
count_over_time({env="sandbox"} |~ "cloudflared.*Connection terminated" [1h])
```

---

## Prometheus Alert Rules

Add to `/home/luce/apps/loki-logging/infra/logging/prometheus/rules/cloudflared_alerts.yml`:

```yaml
groups:
  - name: cloudflared
    interval: 60s
    rules:
      - alert: CloudflaredTunnelDown
        expr: |
          (
            count_over_time({env="sandbox"} |~ "cloudflared.*Registered tunnel connection" [10m])
            or vector(0)
          ) == 0
        for: 5m
        labels:
          severity: warning
          service: cloudflared
        annotations:
          summary: "Cloudflared tunnel has no active connections"
          description: "No tunnel registration events in the last 10 minutes"

      - alert: CloudflaredHighErrorRate
        expr: |
          rate({env="sandbox"} |~ "cloudflared.*ERR" [5m]) > 0.1
        for: 2m
        labels:
          severity: warning
          service: cloudflared
        annotations:
          summary: "Cloudflared error rate is high"
          description: "Error rate: {{ $value }} errors/sec"
```

---

## Filter by Connection Properties

Cloudflared uses structured logfmt output. Extract fields:

### By location (datacenter)
```logql
{env="sandbox"} |~ "cloudflared" | logfmt | location =~ "dfw.*"
```

### By connection index
```logql
{env="sandbox"} |~ "cloudflared" | logfmt | connIndex = "2"
```

### By protocol
```logql
{env="sandbox"} |~ "cloudflared" | logfmt | protocol = "quic"
```

---

## Common Use Cases

### Investigate tunnel disruptions
```logql
{env="sandbox"} |~ "cloudflared.*(terminated|failed|timeout)"
  | line_format "{{.timestamp}} {{.__timestamp__}} {{.connIndex}} {{.error}}"
```

### Monitor connection churn
```logql
sum by (connIndex) (
  count_over_time({env="sandbox"} |~ "cloudflared.*Registered tunnel connection" [1h])
)
```

### Verify tunnel redundancy (should see multiple connIndex values)
```logql
{env="sandbox"} |~ "cloudflared.*Registered tunnel connection"
  | logfmt
  | line_format "{{.connIndex}} {{.location}}"
```

---

## Why No Dedicated `log_source="cloudflared"` Label?

Cloudflared logs are ingested via the **shared journal source** (`loki.source.journal`) which captures ALL systemd services. This approach:

✅ **Pros**:
- Simple configuration (no additional sources/processors)
- Works immediately (no infrastructure changes)
- Easy maintenance (one journal pipeline)
- Query performance is excellent (LogQL line filters are fast)

❌ **Cons**:
- Requires `|~ "cloudflared"` filter in every query
- Cannot create Loki label-based routing rules
- Mixed with other journal logs in storage

**Alternative**: To get a dedicated `log_source="cloudflared"` label, you would need to:
1. Add `loki.relabel` component to filter journal entries by `__journal__systemd_unit`
2. Route cloudflared entries to a dedicated `loki.process.cloudflared` processor
3. Add `log_source = "cloudflared"` static label

This was attempted but adds complexity. The query-based approach is recommended unless you need strict label-based isolation.

---

## References

- [loki.source.journal docs](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.journal/)
- [LogQL line filters](https://grafana.com/docs/loki/latest/query/log_queries/#line-filter-expression)
- [Structured metadata (logfmt parsing)](https://grafana.com/docs/loki/latest/query/log_queries/#parser-expression)

---

**Generated**: 2026-02-15
**Last Updated**: 2026-02-15
