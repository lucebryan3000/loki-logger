# Build and Cleanup Documentation

This document summarizes one-time restructuring and cleanup work performed on the repository.

## Scripts Reorganization (2026-02-13)

### Migration: scripts/ → scripts/prod/

Consolidated all production runtime scripts into a unified `scripts/prod/` directory structure.

**Moved 8 production scripts:**
- `scripts/prod/mcp/` — Stack control/management (6 scripts)
  - `logging_stack_up.sh` — Start Docker Compose observability stack
  - `logging_stack_down.sh` — Stop stack cleanly
  - `logging_stack_health.sh` — Health check validation
  - `logging_stack_audit.sh` — Audit/validation script
  - `validate_env.sh` — Environment configuration validation
  - `logging_bootstrap_upstream_refs.sh` — Pin upstream Git references
- `scripts/prod/prism/` — Evidence/proof generation (1 script)
  - `evidence.sh` — Evidence framework for sprint execution
- `scripts/prod/telemetry/` — Telemetry generation (1 script)
  - `telemetry_writer.py` — Background telemetry stream generation

**Deleted (build-time only):**
- `scripts/docs/generate_docs.py` — No runtime use, auto-generates docs from evidence (build-time only)

**Updates:**
- Updated all references in README.md, docs/*.md, _build/Sprint files
- Updated relative paths in mcp/*.sh scripts (cd paths, internal references)
- Updated temp/codex validation snapshots

### Directory Structure Before/After

**Before:**
```
scripts/
├── mcp/                  (6 files)
├── prism/                (1 file)
├── docs/                 (1 file - deleted)
├── telemetry/            (1 file)
└── codex*/               (build-time scripts)
```

**After:**
```
scripts/
├── prod/                 (production scripts)
│   ├── mcp/              (6 files)
│   ├── prism/            (1 file)
│   └── telemetry/        (1 file)
└── codex*/               (build-time scripts)
```

---

## Root Directory Cleanup (2026-02-13)

**Deleted garbage files:**
- `=3.1` (819 bytes) — pip install output log (accidental)
- `=4.0` (819 bytes) — pip install output log (accidental)

**Kept:**
- README.md, CHANGELOG.md, AGENTS.md, QUICK-ACCESS.md — Documentation
- .env, .env.example — Configuration
- .editorconfig, .gitignore, .claudeignore — Settings

---

## Rationale

### Why scripts/prod/?
1. **Organization:** Groups production-ready runtime scripts under one logical parent
2. **Clarity:** Signals distinction from build/development scripts (scripts/codex-*)
3. **Maintainability:** Easier to locate and update production infrastructure code
4. **Naming consistency:** Aligns with kebab-case directory conventions

### Why delete generate_docs.py?
- **Build-time only** — Invoked only during codex-sprint evidence generation
- **No production use** — Not called by any runtime operations or automation
- **Redundant** — Auto-generates docs from evidence; docs/ already exist and are static
- **Should live in codex** — If needed for builds, belongs in scripts/codex-sprint/

---

## Testing

**Scripts verified for syntax:**
- ✅ logging_stack_health.sh
- ✅ logging_stack_up.sh
- ✅ logging_stack_down.sh

All path references tested and confirmed working.

---

## References

Related analysis documents (if needed for audit):
- temp/temp-cleanup-analysis.md — temp/ directory assessment
- (Previous: migration-summary.md, root-cleanup-analysis.md, scripts-analysis.md)
