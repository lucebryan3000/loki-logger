# As Installed

    ## Host / Tooling
    - Docker: 
    - Compose: 

    ## Runtime (compose ps)
    NAME                                  IMAGE                              COMMAND                  SERVICE         CREATED             STATUS                  PORTS
infra_observability-alloy-1           grafana/alloy:v1.2.1               "/bin/alloy run --se…"   alloy           About an hour ago   Up About an hour        
infra_observability-cadvisor-1        gcr.io/cadvisor/cadvisor:v0.49.1   "/usr/bin/cadvisor -…"   cadvisor        17 hours ago        Up 17 hours (healthy)   8080/tcp
infra_observability-grafana-1         grafana/grafana:11.1.0             "/run.sh"                grafana         17 hours ago        Up 17 hours             127.0.0.1:9001->3000/tcp
infra_observability-loki-1            grafana/loki:3.0.0                 "/usr/bin/loki -conf…"   loki            17 hours ago        Up 7 hours              3100/tcp
infra_observability-node_exporter-1   prom/node-exporter:v1.8.1          "/bin/node_exporter …"   node_exporter   17 hours ago        Up 17 hours             9100/tcp
infra_observability-prometheus-1      prom/prometheus:v2.52.0            "/bin/prometheus --c…"   prometheus      About an hour ago   Up About an hour        127.0.0.1:9004->9090/tcp


    ## Containers (docker ps)
    infra_observability-alloy-1	grafana/alloy:v1.2.1	Up About an hour
infra_observability-prometheus-1	prom/prometheus:v2.52.0	Up About an hour
codeswarm-mcp	codeswarm-mcp	Up 4 hours (healthy)
infra_observability-grafana-1	grafana/grafana:11.1.0	Up 17 hours
infra_observability-loki-1	grafana/loki:3.0.0	Up 7 hours
infra_observability-cadvisor-1	gcr.io/cadvisor/cadvisor:v0.49.1	Up 17 hours (healthy)
infra_observability-node_exporter-1	prom/node-exporter:v1.8.1	Up 17 hours
hex-atlas-app-1	7db12c5b0ff1	Up 24 hours (healthy)
hex-atlas-sql-1	postgres:16-alpine	Up 24 hours (healthy)
hex-atlas-typesense-1	atlas-typesense:27.1	Up 24 hours (healthy)


    ## Telemetry writer (systemd)
    ● loki-telemetry-writer.service - Loki Telemetry-as-Logs JSONL Writer
     Loaded: loaded (/etc/systemd/system/loki-telemetry-writer.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-02-12 12:04:43 CST; 10h ago
 Invocation: 93f9995168294e57b4037116cf5a52b6
   Main PID: 3426189 (python3)
      Tasks: 1 (limit: 151210)
     Memory: 5.4M (peak: 5.6M)
        CPU: 692ms
     CGroup: /system.slice/loki-telemetry-writer.service
             └─3426189 /usr/bin/python3 /home/luce/apps/loki-logging/scripts/telemetry/telemetry_writer.py

Feb 12 12:04:43 codeswarm systemd[1]: Started loki-telemetry-writer.service - Loki Telemetry-as-Logs JSONL Writer.
Feb 12 12:04:43 codeswarm python3[3426189]: /home/luce/apps/loki-logging/scripts/telemetry/telemetry_writer.py:9: DeprecationWarning: datetime.datetime.utcnow() is deprecated and scheduled for removal in a future version. Use timezone-aware objects to represent datetimes in UTC: datetime.datetime.now(datetime.UTC).
Feb 12 12:04:43 codeswarm python3[3426189]:   return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
