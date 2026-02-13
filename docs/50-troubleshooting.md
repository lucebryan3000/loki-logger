# Troubleshooting

Alloy parse errors:
- No '#' comments (use '//' or block comments).
- Avoid invalid nested blocks in Alloy config.
- Force-recreate alloy after config changes.

Empty Loki results:
- Avoid invalid selector {}. Use {env=~".+"} for broad queries.
- Ensure query window end timestamp is current (recompute end per retry).
