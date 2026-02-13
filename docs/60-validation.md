# Validation & Tests (Strict)

Required:
1) Grafana health:
- curl -sf http://127.0.0.1:9001/api/health

2) Prometheus ready:
- curl -sf http://127.0.0.1:9004/-/ready

3) Loki telemetry:
- {"env"=~".+"} |= "telemetry tick"

4) CodeSwarm MCP labeled proof:
- {"env"=~".+","log_source"="codeswarm_mcp"} |= "codeswarm_mcp_proof_"
