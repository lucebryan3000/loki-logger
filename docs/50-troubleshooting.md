# Troubleshooting

Alloy parse/load errors
- illegal character '#', block comment not terminated, sys.env missing, initial load failure
- Fix: use // comments, ensure block nesting valid, force reload Alloy, verify mounts via docker inspect.

Loki query returns nothing
- Use selector {env=~".+"}; recompute timestamps; ensure marker written before end.

"entry too far behind"
- Clear stale file backlog and restart Alloy tailer positions; Loki already allows old samples in sandbox.
