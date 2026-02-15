# Troubleshooting

## Symptom: `install.sh` fails with "Build artifacts not found"

**Diagnosis:** Forgot to run `build-configs.sh` first

**Fix:**
```bash
./scripts/build-configs.sh
sudo ./scripts/install.sh
```

---

## Symptom: logrotate syntax error

**Diagnosis:** Invalid value in `retention.conf` (e.g., `MAX_SIZE=25` instead of `25M`)

**Fix:**
1. Check syntax: `./scripts/validate.sh`
2. Edit `config/retention.conf` (ensure sizes have `M` or `G` suffix)
3. Rebuild: `./scripts/build-configs.sh`
4. Reinstall: `sudo ./scripts/install.sh`

**Example:**
```bash
# BAD
TOOL_SINK_MAX_SIZE=25

# GOOD
TOOL_SINK_MAX_SIZE=25M
```

---

## Symptom: Rotation not happening

**Diagnosis:** logrotate.timer not running or files below size threshold

**Fix:**
1. Check timer: `systemctl status logrotate.timer`
2. Check last run: `sudo cat /var/lib/logrotate/status | grep loki-sources`
3. Force rotation: `sudo ./scripts/test-rotation.sh`
4. Check file sizes: `ls -lh /home/luce/_logs/`

**Note:** Rotation only happens if:
- File size > `maxsize` threshold OR
- Time interval elapsed (daily/weekly) AND file not empty

---

## Symptom: Permission denied errors in logrotate

**Diagnosis:** Files owned by different user than specified in `su` directive

**Fix:**
1. Check file ownership: `ls -la /home/luce/_logs/`
2. Update `retention.conf`:
   ```bash
   LOG_OWNER_USER=actual_owner
   LOG_OWNER_GROUP=actual_group
   ```
3. Rebuild and reinstall:
   ```bash
   ./scripts/build-configs.sh
   sudo ./scripts/install.sh
   ```

---

## Symptom: journald size not decreasing

**Diagnosis:** Journal vacuum not applied or files still in use

**Fix:**
1. Check current size: `journalctl --disk-usage`
2. Force vacuum: `sudo journalctl --vacuum-size=1G`
3. Restart journald: `sudo systemctl restart systemd-journald`
4. Verify config: `cat /etc/systemd/journald.conf.d/99-loki-retention.conf`

**Note:** Vacuum only removes archived journals, not active journal files

---

## Symptom: `.gz` files not created during test rotation

**Diagnosis:** Log files are empty or below rotation threshold

**Fix:**
1. Check if files exist and have content:
   ```bash
   ls -lh /home/luce/_logs/
   ```
2. If empty, write test data:
   ```bash
   echo "test log entry" >> /home/luce/_logs/test.log
   ```
3. Force rotation:
   ```bash
   sudo ./scripts/test-rotation.sh
   ```

---

## Symptom: Config changes not taking effect

**Diagnosis:** Forgot to rebuild and reinstall after editing `retention.conf`

**Fix:**
```bash
# 1. Edit config
nano config/retention.conf

# 2. Rebuild
./scripts/build-configs.sh

# 3. Reinstall
sudo ./scripts/install.sh
```

**Remember:** Config changes require full rebuild → reinstall cycle

---

## Symptom: Samba config not installed

**Diagnosis:** `SAMBA_ENABLED=false` in config

**Fix:**
1. Edit `config/retention.conf`:
   ```bash
   SAMBA_ENABLED=true
   ```
2. Rebuild and reinstall:
   ```bash
   ./scripts/build-configs.sh
   sudo ./scripts/install.sh
   ```

---

## Symptom: Disk usage not decreasing after rotation

**Diagnosis:** Old compressed files still present or rotation not covering all sources

**Fix:**
1. Check for old `.gz` files:
   ```bash
   find /home/luce/_logs -name "*.gz" -mtime +7
   ```
2. Manually remove if needed:
   ```bash
   find /home/luce/_logs -name "*.gz" -mtime +7 -delete
   ```
3. Verify all paths in `retention.conf` are correct
4. Check status: `./scripts/status.sh`

---

## Debugging Commands

```bash
# Test logrotate config without rotating
sudo logrotate -d /etc/logrotate.d/loki-sources

# Force verbose rotation
sudo logrotate -fv /etc/logrotate.d/loki-sources

# Check logrotate service logs
sudo journalctl -u logrotate.service --since "1 day ago"

# Show journal disk usage breakdown
journalctl --disk-usage
sudo du -sh /var/log/journal/*

# List all logrotate configs
ls -la /etc/logrotate.d/

# Show logrotate timer schedule
systemctl list-timers logrotate.timer
```

---

## Testing Strategy

**Approach:**
1. **Unit test each script** (Phase 2) before integration test
2. **Dry-run validation**: Use `logrotate -d` to validate syntax before deploying
3. **Staged rollout**: Install on dev/sandbox first, observe 7 days, then prod (if applicable)

---

## Integration Testing

### Test Plan: `test/integration-test.sh`

**Purpose:** End-to-end test on live system

**Phases:**
1. **Baseline** — Capture disk usage before install
2. **Install** — Deploy configs
3. **Validation** — Verify configs deployed correctly
4. **Force Rotation** — Test rotation works
5. **Wait & Monitor** — Wait 24h for scheduled rotation
6. **Verification** — Confirm disk usage decreased
7. **Uninstall** — Clean removal test

**Validation Criteria:**
- [ ] Configs deployed correctly
- [ ] Force rotation creates `.gz` files
- [ ] Journal size reduced to <1GB (after 24h)
- [ ] All scripts run without errors

---

## Validation Checklist

- [ ] At least 5 common issues covered
- [ ] Symptom → diagnosis → fix format followed throughout
- [ ] Debugging command reference provided
- [ ] Integration testing strategy documented
