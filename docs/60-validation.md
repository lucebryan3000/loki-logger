# Validation & Tests (Strict)

Required checks
1. Grafana health: curl -sf http://127.0.0.1:/api/health
2. Prometheus ready: curl -sf http://127.0.0.1:/-/ready
3. Telemetry: systemctl is-active loki-telemetry-writer.service; Loki contains {env=~".+"} |= "telemetry tick"
4. CodeSwarm MCP: broad {env=~".+"} |= "<marker>"; labeled {env=~".+",log_source="codeswarm_mcp"} |= "<marker>"
