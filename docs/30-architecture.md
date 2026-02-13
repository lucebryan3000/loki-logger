# Architecture

## Data flow
Sources → Alloy → Loki → Grafana
Metrics → Prometheus → Grafana

## Network
- Docker network: obs
- Loopback exposed:
  - Grafana: 127.0.0.1:
  - Prometheus: 127.0.0.1:
- Loki internal only on obs

## Data flow (conceptual)
- Hosts → Alloy → Loki → Grafana
- Metrics: Prometheus → Grafana
