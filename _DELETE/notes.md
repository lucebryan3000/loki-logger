Based on the current alloy-config.alloy:

#	Source name	Path / Input	Processor	log_source	Type

3	tool_sink	/home/luce/_logs/*.log	main	(none)	file
4	telemetry	/home/luce/_telemetry/*.jsonl	main	(none)	file
7	codeswarm_mcp	apps/vLLM/_data/mcp-logs/*.log	codeswarm	codeswarm_mcp	file


node-exporter
CodeSwarm MCP (1): codeswarm-mcp (healthy)
Hex Atlas (3): app, postgres, typesense
Observability & Logging
Grafana - Port 9001 (running in Docker)
Prometheus - Port 9004 (running in Docker)
Loki - Internal only, port 3100 (running in Docker)
Alloy - Log collection agent (running in Docker)
Node Exporter - System metrics (running in Docker)
cAdvisor - Container metrics (running in Docker)
Loki Telemetry Writer - Custom systemd service for JSONL telemetry ingestion
File Sharing & Storage
Samba - SMB/CIFS file sharing (nmbd + smbd running)
Ports 139, 445 listening on all interfaces
NFS - Not detected
Databases
PostgreSQL - Client v17 installed, server running in Docker (hex-atlas-sql, port 5432)
Typesense - Search engine running in Docker (hex-atlas)
Web Servers
Nginx - v1.26.3 installed (not currently running as service)
System Services


systemd-networkd - Network configuration
systemd-resolved - DNS resolution
systemd-timesyncd - NTP time sync
rsyslog - System logging
thermald - Thermal management
NVIDIA Persistence Daemon - GPU persistence
Custom SystemD Services
loki-telemetry-writer.service
opencode-serve.service
cloudflared.service
codeswarm.service
system-stats-api.service
cpu-performance.service
kbgen-improver.service
Development Tools
Python - v3.14.3 (Homebrew)
Node.js - v25.6.0 (Homebrew)
npm - v11.8.0 (Homebrew)
GitHub CLI (gh) - v2.86.0
Redis Python client - Installed
Package Managers
Homebrew - Linuxbrew at /home/linuxbrew/.linuxbrew
Snap - Running (core, core22, lsd, tree packages)
APT/dpkg - System packages
Listening Ports Summary
22 - SSH (all interfaces)
139, 445 - Samba (all interfaces)
3000 - Hex Atlas app (all interfaces)
3100 - Loki (internal Docker network)
5432 - PostgreSQL (all interfaces)
8000 - Unknown service (all interfaces)
8080 - Code-Server (all interfaces)
8082 - OpenCode server (all interfaces)
8108 - Typesense (all interfaces)
9001 - Grafana (localhost)
9004 - Prometheus (localhost)
