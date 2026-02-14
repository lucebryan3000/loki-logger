# Security

## Exposure Posture

This logging stack is designed for **local development** with minimal external exposure.

### External Access (Loopback Only)

| Service | Binding | Port | Authentication |
|---------|---------|------|----------------|
| Grafana | 127.0.0.1 | 9001 | Username/password |
| Prometheus | 127.0.0.1 | 9004 | None (loopback trusted) |

**Security model:** Only loopback (127.0.0.1) is bound. No services are accessible from network.

**Access from localhost only:**
```bash
# Accessible
curl http://127.0.0.1:9001/api/health
curl http://127.0.0.1:9004/-/ready

# Not accessible (connection refused)
curl http://192.168.1.x:9001/api/health  # From another machine
```

### Internal-Only Services

These services have **no exposed ports** and are only accessible from the `obs` Docker network:

- **Loki** (http://loki:3100) — No external binding
- **Alloy** (internal UI on 12345) — No external binding
- **Node Exporter** (port 9100) — No external binding
- **cAdvisor** (port 8080) — No external binding

**Rationale:** Loki contains raw logs which may include sensitive data. Keeping it internal-only prevents accidental exposure.

## Secrets Management

### Environment Variables (.env)

**Location:** `.env`

**Required secrets:**
- `GRAFANA_ADMIN_USER` — Grafana admin username
- `GRAFANA_ADMIN_PASSWORD` — Grafana admin password
- `GRAFANA_SECRET_KEY` — Session encryption key (32+ random chars)

**Security requirements:**
```bash
# File permissions must be 600 (owner read/write only)
ls -l .env
# Expected: -rw------- 1 luce luce

# Verify not committed to git
git check-ignore .env
# Expected: .env (should be gitignored)
```

**If permissions are wrong:**
```bash
chmod 600 .env
```

### Secret Values Never Logged

**Strict policy:** Secrets from `.env` are **never printed or logged** in:
- Evidence files (`temp/evidence/`)
- Documentation
- Docker logs
- CI/CD outputs

**Verification:**
```bash
# Evidence should never contain secret values
grep -r "GRAFANA_ADMIN_PASSWORD" temp/evidence/
# Expected: no matches

# Logs should not contain passwords
docker logs logging-grafana-1 2>&1 | grep -i password
# Expected: no plaintext passwords (masked or omitted)
```

### Generating Strong Secrets

```bash
# Generate random password (16 chars)
openssl rand -base64 16

# Generate secret key (32 chars)
openssl rand -base64 32

# Or use /dev/urandom
head -c 32 /dev/urandom | base64
```

## Authentication

### Grafana

**Default authentication:** Local username/password (from `.env`)

**First login:**
1. Navigate to http://127.0.0.1:9001
2. Enter `GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD` from `.env`

**Change admin password:**
```bash
docker exec -it logging-grafana-1 \
  grafana cli admin reset-admin-password <new-password>

# Update .env to match
nano .env
```

**Add additional users (Grafana UI):**
1. Configuration → Users → Invite
2. Set role: Viewer, Editor, or Admin

**Security best practices:**
- Use unique password (not reused elsewhere)
- Minimum 12 characters
- Rotate every 90 days (for production use)

### Prometheus

**No authentication** by default (loopback access trusted).

**If authentication needed:**
1. Add reverse proxy (nginx, Caddy) with basic auth
2. OR use SSH tunnel for remote access (see [Remote Access](#remote-access))

**Not recommended:** Exposing Prometheus directly to network without auth.

## Firewall (UFW)

This stack is designed for loopback-only access. No additional firewall rules are needed.

**Verify loopback binding:**
```bash
ss -tln | grep -E ':(9001|9004)'
```

**Expected output:**
```
LISTEN 0 4096 127.0.0.1:9001 0.0.0.0:*
LISTEN 0 4096 127.0.0.1:9004 0.0.0.0:*
```

**Note:** `127.0.0.1` binding means traffic is local-only, regardless of UFW rules.

**If UFW is enabled:**
```bash
sudo ufw status
# No rules needed for loopback-only services
```

## Remote Access

**Scenario:** Access Grafana from another machine (laptop → desktop with stack)

**Recommended approach: SSH tunnel**

```bash
# From remote machine
ssh -L 9001:127.0.0.1:9001 luce@<desktop-ip>

# Access Grafana at http://localhost:9001 on remote machine
```

**DO NOT bind to 0.0.0.0** unless you add firewall rules and authentication.

**Bad practice (exposes to network):**
```bash
# ❌ NEVER DO THIS (binds to all interfaces)
GRAFANA_HOST=0.0.0.0
```

**If network access is required:**
1. Use SSH tunnel (recommended)
2. OR set up reverse proxy (nginx) with TLS + basic auth
3. OR configure UFW to allow specific IPs only:
   ```bash
   sudo ufw allow from <trusted-ip> to any port 9001
   ```

## Docker Socket Security

Alloy requires access to `/var/run/docker.sock` to read container logs.

**Security implications:**
- Alloy runs as **root** inside container (user: "0:0")
- Socket access grants full Docker API control (privilege escalation risk)

**Mitigations:**
- Alloy is read-only on socket: `-v /var/run/docker.sock:/var/run/docker.sock:ro`
- Container is on isolated `obs` network
- No port exposure (internal only)

**Verification:**
```bash
# Check socket mount is read-only
docker inspect logging-alloy-1 | grep -A5 docker.sock
# Expected: "RW": false
```

**Best practice:** Do not expose Alloy container to untrusted networks.

## Log Data Security

### Sensitive Data in Logs

**Assumption:** Logs may contain sensitive data (API keys, user info, errors with stack traces)

**Protections:**
1. Loki is **internal-only** (no external exposure)
2. Grafana requires authentication
3. Evidence files are stored in `temp/` (gitignored)

**Do NOT:**
- Commit evidence files to public repos
- Share Loki queries containing sensitive data
- Export logs without redaction

### PII Handling

If logs contain Personally Identifiable Information (PII):
1. **Retention:** Enforce 30-day max (current Loki config: 720h)
2. **Access control:** Limit Grafana users (use Viewer role for read-only)
3. **Redaction:** Filter sensitive fields before export

**Example: Redact emails in export**
```bash
# Export logs from Grafana
# Copy to clipboard, then:
cat export.log | sed 's/[a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]*\.[a-zA-Z]{2,}/[EMAIL_REDACTED]/g'
```

### Compliance (GDPR, HIPAA)

This stack is **not GDPR/HIPAA compliant** by default.

**For compliance:**
- Add audit logging (who accessed what logs)
- Implement data retention policies (30 days max)
- Add encryption at rest (Docker volume encryption)
- Restrict access (role-based access control in Grafana)
- Document log sources and data classification

## Container Security

### Image Sources

All images are from official sources:

- `grafana/grafana:11.1.0` — Official Grafana image
- `grafana/loki:3.0.0` — Official Loki image
- `grafana/alloy:v1.2.1` — Official Alloy image
- `prom/prometheus:v2.52.0` — Official Prometheus image
- `prom/node-exporter:v1.8.1` — Official Prometheus exporter
- `gcr.io/cadvisor/cadvisor:v0.49.1` — Official Google cAdvisor image

**Verification:**
```bash
docker compose images
# All images should be from official registries (no third-party)
```

### Image Updates

**Security patches:** Pin specific versions (not `latest`) to avoid unexpected breaking changes.

**Upgrade process:**
1. Check release notes for security fixes
2. Update version in `docker-compose.observability.yml`
3. Test in dev environment
4. Pull and redeploy:
   ```bash
   docker compose pull
   docker compose up -d
   ```

See [maintenance.md](maintenance.md#upgrades) for version compatibility.

### Privileged Containers

**cAdvisor runs as privileged** (requires host-level metrics):
```yaml
services:
  docker-metrics:
    privileged: true
```

**Security risk:** Privileged containers can escape to host.

**Mitigation:**
- cAdvisor is on isolated `obs` network
- No external port exposure
- Official Google-maintained image

**If not needed:** Remove cAdvisor service from compose file.

## Network Security

### Docker Network: `obs`

All services run on isolated bridge network `obs`.

**Verify network isolation:**
```bash
docker network inspect obs --format '{{json .Containers}}' | jq
```

**Expected:** Only observability containers (no other app containers).

**Security benefit:** Log data stays within isolated network, not exposed to other Docker networks.

### Cross-Container Communication

Services communicate over `obs` network using DNS:
- Alloy → Loki: `http://loki:3100`
- Grafana → Loki: `http://loki:3100`
- Grafana → Prometheus: `http://prometheus:9090`

**No TLS** (internal network, trusted environment).

**If TLS required:**
1. Generate self-signed certs
2. Mount certs in containers
3. Update configs to use `https://` endpoints

## Security Checklist

Before deploying to shared/production environment:

- [ ] `.env` file permissions are 600
- [ ] Grafana admin password is strong (12+ chars, unique)
- [ ] Grafana secret key is random (32+ chars)
- [ ] All services bound to 127.0.0.1 (not 0.0.0.0)
- [ ] Loki has no exposed ports (internal-only)
- [ ] Docker socket mount is read-only
- [ ] All images are from official sources
- [ ] Evidence files are gitignored (in `temp/`)
- [ ] No secrets in git history
- [ ] UFW rules allow only trusted IPs (if network access needed)
- [ ] SSH tunnel used for remote access (not direct port binding)

## Incident Response

### Suspected Unauthorized Access

**Steps:**
1. **Rotate secrets immediately:**
   ```bash
   # Generate new password
   NEW_PASS=$(openssl rand -base64 16)

   # Update Grafana
   docker exec -it logging-grafana-1 \
     grafana cli admin reset-admin-password "$NEW_PASS"

   # Update .env
   nano .env
   # Set GRAFANA_ADMIN_PASSWORD="$NEW_PASS"
   ```

2. **Check access logs:**
   ```bash
   docker logs logging-grafana-1 | grep -i login
   ```

3. **Verify network bindings:**
   ```bash
   ss -tln | grep -E ':(9001|9004)'
   # Ensure 127.0.0.1 only (not 0.0.0.0)
   ```

4. **Audit user accounts:**
   - Grafana → Configuration → Users
   - Remove unknown users

### Data Breach

**If logs containing sensitive data are exposed:**
1. **Stop stack immediately:**
   ```bash
   ./scripts/prod/mcp/logging_stack_down.sh
   ```

2. **Rotate all secrets:**
   - Grafana admin password
   - Grafana secret key
   - Any API keys in `.env`

3. **Audit log data:**
   - Export affected time range
   - Determine scope of exposure

4. **Notify stakeholders** (if required by compliance)

5. **Redeploy with hardened config:**
   - Review [Security Checklist](#security-checklist)
   - Ensure all mitigations are in place

## Next Steps

- Review [maintenance.md](maintenance.md) for retention policies
- See [operations.md](operations.md) for operational security
- Check [reference.md](reference.md) for configuration reference
