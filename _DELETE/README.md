# _DELETE Folder

Build artifacts and transient state files that are no longer actively used.

**Safe to delete entirely** — contains only:
- Inspection dump logs (snapshot_*.txt, *_tail.txt, *_scan.txt)
- Runtime state files (TRACKING.md, runtime.log, *.pid, *.buffer)
- Batch execution state (queue.json, memory.json, state_report_*.json)
- Old phase output (Sprint-1, Sprint-3/reference/* directories)
- Grafana/dashboard audit artifacts (audit*.json, dashboard_*.json)

**Preserved elsewhere:**
- All ADR documentation → `/docs/` and `/_build/Sprint-4/claude/adr*.md`
- Prompts and specs → `/_build/Sprint-4/`
- Operational guides → `/docs/`

**Cleanup timeline:**
- Created: 2026-02-19 during production readiness pass
- This folder can be deleted anytime without impacting the codebase
