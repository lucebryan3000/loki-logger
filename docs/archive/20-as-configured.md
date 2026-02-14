# As Configured

Key files:
- infra/logging/docker compose -p logging.observability.yml
- infra/logging/loki-config.yml
- infra/logging/alloy-config.alloy
- infra/logging/prometheus/prometheus.yml
- infra/logging/grafana/provisioning/**
- infra/logging/grafana/dashboards/**

Config hashes (sha256):
```
5888badf65105217b6847f2297f7c5d06db152ffd566db83bff7e238442e5ff7  infra/logging/docker compose -p logging.observability.yml
dfd4b882c188e80f889fc1fcb4ca798a80c81e3d9fc1e37b3747c7b3dc179d41  infra/logging/loki-config.yml
db3bcaa1b0d0a2bd3e8df59689664bb257d97383e5f53e63f9316aaedfe8a8b3  infra/logging/alloy-config.alloy
c7f4f252d99c1535da5cc5eab5103177d0fd60e7d2c934be07edd091f2b072bb  infra/logging/prometheus/prometheus.yml
239185950f2ca047da8553fc0e74f86600029e4336ccea52db224df0aa41b574  infra/logging/grafana/provisioning/datasources/loki.yml
04ef53d5dd3d7c4e5fb296de7517721826fc334bac8cd4da6aea6938161a005e  infra/logging/grafana/provisioning/datasources/prometheus.yml
9d42eb00934d445c9dbd18698ea026a773b11674241d166d9d18c8b3934f4e61  infra/logging/grafana/provisioning/dashboards/dashboards.yml
```

Rendered compose (truncated):
```
name: infra_observability
services:
  alloy:
    command:
      - run
      - --server.http.listen-addr=0.0.0.0:12345
      - /etc/alloy/config.alloy
    depends_on:
      loki:
        condition: service_started
        required: true
    image: grafana/alloy:v1.2.1
    networks:
      obs: null
    restart: unless-stopped
    user: "0:0"
    volumes:
      - type: bind
        source: /var/run/docker.sock
        target: /var/run/docker.sock
        read_only: true
        bind: {}
      - type: bind
        source: /run/log/journal
        target: /run/log/journal
        read_only: true
        bind: {}
      - type: bind
        source: /var/log/journal
        target: /var/log/journal
        read_only: true
        bind: {}
      - type: bind
        source: /home
        target: /host/home
        read_only: true
        bind: {}
      - type: bind
        source: /home/luce/apps/loki-logging/infra/logging/alloy-config.alloy
        target: /etc/alloy/config.alloy
        read_only: true
        bind: {}
  cadvisor:
    devices:
      - source: /dev/kmsg
        target: /dev/kmsg
        permissions: rwm
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    networks:
      obs: null
    privileged: true
    restart: unless-stopped
    volumes:
      - type: bind
        source: /
        target: /rootfs
        read_only: true
        bind: {}
      - type: bind
        source: /var/run
        target: /var/run
        bind: {}
      - type: bind
        source: /sys
        target: /sys
        read_only: true
        bind: {}
      - type: bind
        source: /var/lib/docker/
        target: /var/lib/docker
        read_only: true
        bind: {}
  grafana:
    depends_on:
      loki:
        condition: service_started
        required: true
      prometheus:
        condition: service_started
        required: true
    environment:
      GF_SECURITY_ADMIN_PASSWORD: rvo_tsWRVzRY1wUJ2pC_LzeUukruEEEs
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_SECRET_KEY: 57000e351d9494155362b401f2cf360cf47597495955025b68c0e008274c57c0
      GF_SERVER_HTTP_PORT: "3000"
      GRAFANA_ADMIN_PASSWORD: rvo_tsWRVzRY1wUJ2pC_LzeUukruEEEs
      GRAFANA_ADMIN_USER: admin
      GRAFANA_SECRET_KEY: 57000e351d9494155362b401f2cf360cf47597495955025b68c0e008274c57c0
    image: grafana/grafana:11.1.0
    networks:
      obs: null
    ports:
      - mode: ingress
        host_ip: 127.0.0.1
        target: 3000
        published: "9001"
        protocol: tcp
    restart: unless-stopped
    volumes:
      - type: volume
        source: grafana-data
        target: /var/lib/grafana
        volume: {}
      - type: bind
        source: /home/luce/apps/loki-logging/infra/logging/grafana/provisioning
        target: /etc/grafana/provisioning
        read_only: true
        bind: {}
      - type: bind
        source: /home/luce/apps/loki-logging/infra/logging/grafana/dashboards
        target: /var/lib/grafana/dashboards
        read_only: true
        bind: {}
  loki:
    command:
      - -config.file=/etc/loki/loki-config.yml
    image: grafana/loki:3.0.0
    networks:
      obs: null
    restart: unless-stopped
    volumes:
      - type: volume
        source: loki-data
        target: /loki
        volume: {}
      - type: bind
        source: /home/luce/apps/loki-logging/infra/logging/loki-config.yml
        target: /etc/loki/loki-config.yml
        read_only: true
        bind: {}
  node_exporter:
    command:
      - --path.rootfs=/host
    image: prom/node-exporter:v1.8.1
    networks:
      obs: null
    pid: host
    restart: unless-stopped
    volumes:
      - type: bind
        source: /
        target: /host
        read_only: true
        bind:
          propagation: rslave
  prometheus:
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=15d
    image: prom/prometheus:v2.52.0
    networks:
      obs: null
    ports:
      - mode: ingress
        host_ip: 127.0.0.1
        target: 9090
        published: "9004"
        protocol: tcp
    restart: unless-stopped
    volumes:
      - type: volume
        source: prometheus-data
        target: /prometheus
        volume: {}
      - type: bind
        source: /home/luce/apps/loki-logging/infra/logging/prometheus/prometheus.yml
        target: /etc/prometheus/prometheus.yml
        read_only: true
        bind: {}
      - type: bind
        source: /home/luce/apps/loki-logging/infra/logging/prometheus/rules
        target: /etc/prometheus/rules
        read_only: true
        bind: {}
networks:
  obs:
    name: obs
    driver: bridge
volumes:
  grafana-data:
    name: infra_observability_grafana-data
  loki-data:
    name: infra_observability_loki-data
  prometheus-data:
    name: infra_observability_prometheus-data
```
