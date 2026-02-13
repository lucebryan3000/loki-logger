# Troubleshooting

# Alloy Parse Errors
- Use valid Alloy comments (`//` or `/* ... */`), not `#`.
- Recreate Alloy container after config changes.

# Loki Query Returns No Results
- Ensure query window is current.
- Use valid selector syntax and avoid empty selectors.

# Old Timestamp Rejection
- Check `reject_old_samples` settings.
- Restart Alloy after truncating tailed files.

# Prometheus Rules Missing
- Verify rule mounts and `/api/v1/rules` output on port 9004.

Evidence:
- `/home/luce/apps/loki-logging/temp/codex/evidence/Loki-prompt-20/20260213T040316Z/local-capture`
