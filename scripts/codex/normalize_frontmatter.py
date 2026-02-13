#!/usr/bin/env python3
import sys, re
from pathlib import Path

LEGACY_KEYS = {
    "codex_ready_to_execute",
    "codex_kind",
    "codex_scope",
    "codex_targets",
    "codex_autocommit",
    "codex_move_to_completed",
    "codex_warn_gate",
    "codex_warn_mode",
    "codex_allow_noncritical",
    "codex_reviewed_utc",
    "codex_revision",
    "codex_prompt_sha256",
    "codex_reason",
}

# Maps legacy -> preflight keys when derivable
def map_legacy_to_preflight(k: str, v: str):
    if k == "codex_kind":
        return ("codex_preflight_kind", v)
    if k == "codex_scope":
        # Normalize a few common legacy values
        vv = v.strip()
        if vv in {"single-phase", "single-file"}:
            vv = "single-file"
        return ("codex_preflight_scope", vv)
    if k == "codex_ready_to_execute":
        return ("codex_preflight_ready", "true" if v.strip().lower() in {"yes","true","1"} else "false")
    if k == "codex_revision":
        return ("codex_preflight_revision", v.strip())
    if k == "codex_autocommit":
        return ("codex_preflight_autocommit", "true" if v.strip().lower() in {"yes","true","1"} else "false")
    if k == "codex_move_to_completed":
        return ("codex_preflight_move_to_completed", "true" if v.strip().lower() in {"yes","true","1"} else "false")
    if k == "codex_warn_gate":
        return ("codex_preflight_warn_gate", "true" if v.strip().lower() in {"yes","true","1"} else "false")
    if k == "codex_warn_mode":
        return ("codex_preflight_warn_mode", v.strip())
    if k == "codex_allow_noncritical":
        return ("codex_preflight_allow_noncritical", "true" if v.strip().lower() in {"yes","true","1"} else "false")
    if k == "codex_reason":
        return ("codex_preflight_reason", v.strip())
    return None

def parse_frontmatter(text: str):
    if not text.startswith("---\n"):
        return None
    m = re.search(r"^---\n(.*?)\n---\n", text, flags=re.S)
    if not m:
        return None
    return m.group(1), m.end()

def kv_lines(yaml_block: str):
    # Very small parser: supports key: value and simple lists
    lines = yaml_block.splitlines()
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        # list key:
        if re.match(r"^[A-Za-z0-9_]+:\s*$", line):
            key = line.split(":")[0].strip()
            items = []
            j = i+1
            while j < len(lines) and re.match(r"^\s*-\s+.*$", lines[j]):
                items.append(lines[j].strip()[2:].strip())
                j += 1
            out.append((key, items))
            i = j
            continue
        # key: value
        m = re.match(r"^([A-Za-z0-9_]+):\s*(.*)$", line)
        if m:
            out.append((m.group(1), m.group(2).strip().strip('"')))
        i += 1
    return out

def emit_yaml(preflight: dict, preflight_lists: dict, exec_meta: dict, exec_lists: dict):
    lines = ["---"]
    # Preflight keys (only those present)
    order = [
        "codex_preflight_kind",
        "codex_preflight_scope",
        "codex_preflight_targets_root",
        "codex_preflight_targets",
        "codex_preflight_ready",
        "codex_preflight_revision",
        "codex_preflight_autocommit",
        "codex_preflight_move_to_completed",
        "codex_preflight_warn_gate",
        "codex_preflight_warn_mode",
        "codex_preflight_allow_noncritical",
        "codex_preflight_reason",
    ]
    for k in order:
        if k in preflight_lists:
            lines.append(f"{k}:")
            for it in preflight_lists[k]:
                lines.append(f"  - {it}")
        elif k in preflight:
            v = preflight[k]
            # quote only if needed
            if any(ch in v for ch in [":", "#", "{", "}", "[", "]"]) or v == "":
                lines.append(f'{k}: "{v}"')
            else:
                lines.append(f"{k}: {v}")
    # Exec metadata passthrough (if present)
    for k in sorted(exec_meta.keys()):
        lines.append(f"{k}: {exec_meta[k]}")
    for k in sorted(exec_lists.keys()):
        lines.append(f"{k}:")
        for it in exec_lists[k]:
            lines.append(f"  - {it}")
    lines.append("---")
    return "\n".join(lines) + "\n"

def main():
    if len(sys.argv) != 2:
        print("usage: normalize_frontmatter.py <promptfile>", file=sys.stderr)
        sys.exit(2)
    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")

    parsed = parse_frontmatter(text)
    if not parsed:
        # No frontmatter: do not invent; exit with noncritical warning
        print("NO_FRONTMATTER: skipping", file=sys.stderr)
        sys.exit(0)

    yaml_block, body_start = parsed
    pairs = kv_lines(yaml_block)

    preflight = {}
    preflight_lists = {}
    exec_meta = {}
    exec_lists = {}

    # Preserve existing preflight keys if already present
    for k, v in pairs:
        if k.startswith("codex_exec_"):
            if isinstance(v, list):
                exec_lists[k] = v
            else:
                exec_meta[k] = v
        elif k.startswith("codex_preflight_"):
            if isinstance(v, list):
                preflight_lists[k] = v
            else:
                preflight[k] = v

    # Convert legacy keys -> preflight (only if not already set)
    for k, v in pairs:
        if k in LEGACY_KEYS:
            mapped = map_legacy_to_preflight(k, v if isinstance(v, str) else "")
            if mapped:
                nk, nv = mapped
                if nk not in preflight and nk not in preflight_lists:
                    preflight[nk] = nv

    # Always set targets_root + targets if derivable and missing
    fname = path.name
    if "codex_preflight_targets_root" not in preflight:
        preflight["codex_preflight_targets_root"] = "_build/Sprint-1/Prompts/"
    if "codex_preflight_targets" not in preflight_lists:
        preflight_lists["codex_preflight_targets"] = [fname]

    # Remove legacy keys entirely by re-emitting only preflight + exec
    new_yaml = emit_yaml(preflight, preflight_lists, exec_meta, exec_lists)
    new_text = new_yaml + text[body_start:]
    path.write_text(new_text, encoding="utf-8")
    print("NORMALIZED")

if __name__ == "__main__":
    main()
