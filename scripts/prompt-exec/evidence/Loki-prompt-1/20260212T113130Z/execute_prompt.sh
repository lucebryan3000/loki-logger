#!/usr/bin/env bash
set -euo pipefail

RUN_DIR='/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T113130Z'
source "$RUN_DIR/env.sh"
PROMPT_PATH_EFFECTIVE="$PROMPT_PATH"

CODEX_EXIT_STATUS_OVERRIDE=""
CODEX_RUN_FAILED_BLOCK=""
CODEX_RUN_LAST_OK_BLOCK=""
CODEX_RUN_MOVE_STATUS="skipped"
CODEX_RUN_MOVED_TO=""
CODEX_RUN_PROMPT_SHA256="$(sha256sum "$RUN_DIR/prompt.md" | awk '{print $1}')"

GIT_HEAD="<none>"
if [ -n "${REPO_ROOT:-}" ]; then
  GIT_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo '<none>')"
fi

MOVE_TO_COMPLETED="${PROMPT_EXEC_MOVE_TO_COMPLETED:-1}"
AUTOCOMMIT="${PROMPT_EXEC_AUTOCOMMIT:-1}"
WARN_GATE="${PROMPT_EXEC_WARN_GATE:-1}"
WARN_MODE="${PROMPT_EXEC_WARN_MODE:-ask}"

if sed -n '1,200p' "$PROMPT_PATH" | grep -nE '^codex_move_to_completed:[[:space:]]*"?no"?[[:space:]]*$' >/dev/null 2>&1; then
  MOVE_TO_COMPLETED="0"
fi
if sed -n '1,200p' "$PROMPT_PATH" | grep -nE '^codex_autocommit:[[:space:]]*"?no"?[[:space:]]*$' >/dev/null 2>&1; then
  AUTOCOMMIT="0"
fi
if sed -n '1,200p' "$PROMPT_PATH" | grep -nE '^codex_warn_gate:[[:space:]]*"?no"?[[:space:]]*$' >/dev/null 2>&1; then
  WARN_GATE="0"
fi
warn_mode_fm="$(sed -n '1,200p' "$PROMPT_PATH" | grep -E '^codex_warn_mode:' | tail -n 1 | awk -F: '{print $2}' | tr -d ' "\r\n\t' || true)"
if [ -n "${warn_mode_fm:-}" ]; then
  WARN_MODE="$warn_mode_fm"
fi

WARNINGS="$RUN_DIR/warnings.txt"
CODEX_RUN_WARN_COUNT="$(wc -l < "$WARNINGS" 2>/dev/null | tr -d ' ' || echo 0)"
CODEX_RUN_WARN_TYPES=""
if [ -s "$WARNINGS" ]; then
  if grep -qE 'rm -rf|mkfs|dd[[:space:]]+if=|parted|wipefs' "$WARNINGS" 2>/dev/null; then
    CODEX_RUN_WARN_TYPES="${CODEX_RUN_WARN_TYPES} DESTRUCTIVE_FS"
  fi
  if grep -qE 'iptables|\bufw\b' "$WARNINGS" 2>/dev/null; then
    CODEX_RUN_WARN_TYPES="${CODEX_RUN_WARN_TYPES} NETWORK_FIREWALL"
  fi
  if grep -qE 'systemctl[[:space:]]+stop|docker[[:space:]]+system[[:space:]]+prune' "$WARNINGS" 2>/dev/null; then
    CODEX_RUN_WARN_TYPES="${CODEX_RUN_WARN_TYPES} SERVICE_DOWN"
  fi
  if grep -qE 'git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean[[:space:]]+-fdx' "$WARNINGS" 2>/dev/null; then
    CODEX_RUN_WARN_TYPES="${CODEX_RUN_WARN_TYPES} DESTRUCTIVE_GIT"
  fi
  if grep -qE '/(etc|usr|var|bin|sbin)/' "$WARNINGS" 2>/dev/null; then
    CODEX_RUN_WARN_TYPES="${CODEX_RUN_WARN_TYPES} WRITE_SENSITIVE_ROOT"
  fi
fi
CODEX_RUN_WARN_TYPES="$(printf '%s' "$CODEX_RUN_WARN_TYPES" | tr -s ' ' | sed 's/^ //;s/ $//')"

stamp_prompt_frontmatter_best_effort() {
  status="$1"
  commit_sha="${2:-}"

  PROMPT_PATH="$PROMPT_PATH" \
  PROMPT_PATH_EFFECTIVE="$PROMPT_PATH_EFFECTIVE" \
  RUN_DIR="$RUN_DIR" \
  RUN_UTC="$RUN_UTC" \
  GIT_HEAD="$GIT_HEAD" \
  CODEX_RUN_STATUS="$status" \
  CODEX_RUN_COMMIT="$commit_sha" \
  CODEX_RUN_WARN_COUNT="${CODEX_RUN_WARN_COUNT:-}" \
  CODEX_RUN_WARN_TYPES="${CODEX_RUN_WARN_TYPES:-}" \
  CODEX_RUN_FAILED_BLOCK="${CODEX_RUN_FAILED_BLOCK:-}" \
  CODEX_RUN_LAST_OK_BLOCK="${CODEX_RUN_LAST_OK_BLOCK:-}" \
  CODEX_RUN_MOVE_STATUS="${CODEX_RUN_MOVE_STATUS:-}" \
  CODEX_RUN_MOVED_TO="${CODEX_RUN_MOVED_TO:-}" \
  CODEX_RUN_PROMPT_SHA256="${CODEX_RUN_PROMPT_SHA256:-}" \
  python3 - <<'PY'
import os, pathlib, re

prompt_path = pathlib.Path(os.environ.get("PROMPT_PATH_EFFECTIVE") or os.environ["PROMPT_PATH"])
run_dir = os.environ.get("RUN_DIR", "")
git_head = os.environ.get("GIT_HEAD", "")
run_utc = os.environ.get("RUN_UTC", "")
status = os.environ.get("CODEX_RUN_STATUS", "unknown")
commit_sha = os.environ.get("CODEX_RUN_COMMIT", "").strip()
warn_count = os.environ.get("CODEX_RUN_WARN_COUNT", "").strip()
warn_types = os.environ.get("CODEX_RUN_WARN_TYPES", "").strip()
failed_block = os.environ.get("CODEX_RUN_FAILED_BLOCK", "").strip()
last_ok_block = os.environ.get("CODEX_RUN_LAST_OK_BLOCK", "").strip()
move_status = os.environ.get("CODEX_RUN_MOVE_STATUS", "").strip()
moved_to = os.environ.get("CODEX_RUN_MOVED_TO", "").strip()
prompt_sha = os.environ.get("CODEX_RUN_PROMPT_SHA256", "").strip()

text = prompt_path.read_text(encoding="utf-8")

def upsert_frontmatter(src: str, kv: dict) -> str:
    m = re.match(r"\A---\n(.*?)\n---\n", src, flags=re.S)
    if not m:
        fm_lines = ["---"]
        for k, v in kv.items():
            fm_lines.append(f"{k}: {v!r}")
        fm_lines.append("---")
        return "\n".join(fm_lines) + "\n\n" + src

    fm = m.group(1).splitlines()
    body = src[m.end():]

    new_out = []
    for line in fm:
        k = line.split(":", 1)[0].strip() if ":" in line else None
        if k in kv and re.match(r"^[A-Za-z0-9_]+:", line):
            continue
        new_out.append(line)

    for k, v in kv.items():
        new_out.append(f"{k}: {v!r}")

    return "---\n" + "\n".join(new_out).rstrip() + "\n---\n" + body

kv = {}
if run_utc:
    kv["codex_last_run_utc"] = run_utc
if run_dir:
    kv["codex_last_run_dir"] = run_dir
if status:
    kv["codex_last_run_status"] = status
if git_head and git_head != "<none>":
    kv["codex_last_run_git_head"] = git_head
if commit_sha:
    kv["codex_last_run_commit"] = commit_sha
if warn_count:
    kv["codex_last_run_warning_count"] = warn_count
if warn_types:
    kv["codex_last_run_warning_types"] = warn_types
if failed_block:
    kv["codex_last_run_failed_block"] = failed_block
if last_ok_block:
    kv["codex_last_run_last_ok_block"] = last_ok_block
if move_status:
    kv["codex_last_run_move_status"] = move_status
if moved_to:
    kv["codex_last_run_moved_to"] = moved_to
if prompt_sha:
    kv["codex_last_run_prompt_sha256"] = prompt_sha

prompt_path.write_text(upsert_frontmatter(text, kv), encoding="utf-8")
PY
}

if ! sed -n '1,200p' "$PROMPT_PATH" | grep -nE '^codex_ready_to_execute:[[:space:]]*"?yes"?[[:space:]]*$' >/dev/null 2>&1; then
  CODEX_EXIT_STATUS_OVERRIDE="blocked"
  stamp_prompt_frontmatter_best_effort "blocked" || true
  exit 2
fi

if [ -s "$WARNINGS" ] && [ "$WARN_MODE" = "halt" ]; then
  CODEX_EXIT_STATUS_OVERRIDE="blocked"
  stamp_prompt_frontmatter_best_effort "blocked" || true
  exit 2
fi

awk -v outdir="$RUN_DIR/blocks" -v envfile="$RUN_DIR/env.sh" '
  BEGIN { in_block=0; idx=0; }
  $0 ~ /^```[[:space:]]*(bash|sh|zsh|shell)[[:space:]]*$/ {
    in_block=1; idx++;
    file=sprintf("%s/block%03d.sh", outdir, idx);
    print "#!/usr/bin/env bash" > file;
    print "set -euo pipefail" >> file;
    print "umask 022" >> file;
    print "source \"" envfile "\"" >> file;
    print "if [ -n \"${REPO_ROOT:-}\" ]; then cd \"$REPO_ROOT\"; else cd \"$PROMPT_DIR\"; fi" >> file;
    next;
  }
  in_block && $0 ~ /^```[[:space:]]*$/ { in_block=0; close(file); next; }
  in_block { print $0 >> file; }
' "$RUN_DIR/prompt.md"

ls -la "$RUN_DIR/blocks" > "$RUN_DIR/blocks.index.txt"

set +e
on_exit_stamp_failed() {
  rc="$?"
  if [ "$rc" -ne 0 ]; then
    if [ -z "${CODEX_EXIT_STATUS_OVERRIDE:-}" ]; then
      stamp_prompt_frontmatter_best_effort "failed" || true
    fi
  fi
}
trap on_exit_stamp_failed EXIT

maybe_remediate_and_retry_once() {
  block_path="$1"
  out_path="$2"
  rules="/home/luce/.codex/skills/prompt-exec/scripts/remediation_rules.yaml"
  planner="/home/luce/.codex/skills/prompt-exec/scripts/remediate_from_output.py"
  if [ -f "$planner" ] && command -v python3 >/dev/null 2>&1; then
    while IFS= read -r line; do
      case "$line" in
        INSTALL_PKG=*)
          pkg="${line#INSTALL_PKG=}"
          if [ -n "$pkg" ]; then
            if command -v apt-get >/dev/null 2>&1; then
              sudo -n apt-get update -y || true
              sudo -n apt-get install -y "$pkg" || true
            elif command -v dnf >/dev/null 2>&1; then
              sudo -n dnf install -y "$pkg" || true
            elif command -v yum >/dev/null 2>&1; then
              sudo -n yum install -y "$pkg" || true
            elif command -v pacman >/dev/null 2>&1; then
              sudo -n pacman -S --noconfirm "$pkg" || true
            elif command -v brew >/dev/null 2>&1; then
              brew install "$pkg" || true
            fi
          fi
          ;;
        BACKOFF_SEC=*)
          sec="${line#BACKOFF_SEC=}"
          if echo "$sec" | grep -qE '^[0-9]+$'; then
            sleep "$sec"
          fi
          ;;
      esac
    done < <(python3 "$planner" --rules "$rules" --output "$out_path" 2>/dev/null || true)
  else
    if grep -qE 'Could not resolve host|Connection timed out|Operation timed out|TLS handshake timeout' "$out_path" 2>/dev/null; then
      sleep 2
    fi
  fi

  bash -lc "$block_path" >"$out_path" 2>&1
  return $?
}

FAILED=""
LAST_OK=0
RESUME_FROM="${PROMPT_EXEC_RESUME_FROM:-1}"

for f in "$RUN_DIR/blocks"/block*.sh; do
  [ -e "$f" ] || { echo "No executable blocks found." | tee -a "$RUN_DIR/manifest.txt"; CODEX_EXIT_STATUS_OVERRIDE="blocked"; stamp_prompt_frontmatter_best_effort "blocked" || true; exit 2; }

  b="$(basename "$f" .sh)"
  bnum="$(echo "$b" | sed -nE 's/^block0*([0-9]+)$/\1/p')"
  if [ -n "$bnum" ] && [ "$bnum" -lt "$RESUME_FROM" ]; then
    continue
  fi

  out="$RUN_DIR/out/${b}.out.txt"
  chmod +x "$f"
  start_s="$(date -u +%s)"
  echo "==> Running $f" | tee -a "$RUN_DIR/manifest.txt"
  bash -lc "$f" >"$out" 2>&1
  rc=$?
  end_s="$(date -u +%s)"
  dur_s="$((end_s - start_s))"

  echo "exit_code[$b]=$rc" >> "$RUN_DIR/manifest.txt"
  echo "ran_block=$b" >> "$RUN_DIR/manifest.txt"
  echo "duration_s[$b]=$dur_s" >> "$RUN_DIR/manifest.txt"

  if [ $rc -ne 0 ]; then
    if head -n 5 "$f" | grep -qE '^# codex: noncritical$' 2>/dev/null; then
      echo "NONCRITICAL_FAIL: $b (rc=$rc). Output: $out" | tee -a "$RUN_DIR/manifest.txt"
      continue
    fi
    echo "RETRYING_ONCE: $b (rc=$rc). Output: $out" | tee -a "$RUN_DIR/manifest.txt"
    maybe_remediate_and_retry_once "$f" "$out"
    rc2=$?
    echo "exit_code_retry[$b]=$rc2" >> "$RUN_DIR/manifest.txt"
    if [ $rc2 -ne 0 ]; then
      FAILED="$b"
      echo "FAILED: $b (rc=$rc2). Output: $out" | tee -a "$RUN_DIR/manifest.txt"
      break
    fi
  fi

  if [ "$b" = "block001" ] && ! grep -q '^export EVID=' "$RUN_DIR/env.sh" 2>/dev/null; then
    latest_evid="$(ls -1dt /home/luce/apps/loki-logging/.artifacts/prism/evidence/* 2>/dev/null | head -n 1 || true)"
    if [ -n "$latest_evid" ]; then
      printf 'export EVID=%q\n' "$latest_evid" >> "$RUN_DIR/env.sh"
      echo "derived_evid=$latest_evid" >> "$RUN_DIR/manifest.txt"
    fi
  fi

  LAST_OK="$bnum"
  echo "last_successful_block=$LAST_OK" >> "$RUN_DIR/manifest.txt"
done

if [ -n "$FAILED" ]; then
  CODEX_RUN_FAILED_BLOCK="$FAILED"
  CODEX_RUN_LAST_OK_BLOCK="$LAST_OK"
  exit 1
fi

stamp_prompt_frontmatter_best_effort "success"

PROMPT_DIR_REAL="$(cd "$(dirname "$PROMPT_PATH")" && pwd -P)"
PROMPT_BASE="$(basename "$PROMPT_PATH")"
PROMPT_STEM_LOCAL="${PROMPT_BASE%.md}"

if [ "$MOVE_TO_COMPLETED" != "0" ]; then
  COMPLETED_DIR="$PROMPT_DIR_REAL/completed"
  mkdir -p "$COMPLETED_DIR"
  DEST="$COMPLETED_DIR/$PROMPT_BASE"
  if [ -e "$DEST" ]; then
    DEST="$COMPLETED_DIR/$PROMPT_STEM_LOCAL.$RUN_UTC.md"
  fi

  if mv "$PROMPT_PATH" "$DEST" 2>/dev/null; then
    CODEX_RUN_MOVE_STATUS="success"
  else
    if cp "$PROMPT_PATH" "$DEST" 2>/dev/null; then
      src_sha="$(sha256sum "$PROMPT_PATH" 2>/dev/null | awk '{print $1}')"
      dst_sha="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"
      if [ -n "$src_sha" ] && [ "$src_sha" = "$dst_sha" ]; then
        rm -f "$PROMPT_PATH" 2>/dev/null || true
        CODEX_RUN_MOVE_STATUS="success"
      else
        CODEX_RUN_MOVE_STATUS="failed"
      fi
    else
      CODEX_RUN_MOVE_STATUS="failed"
    fi
  fi

  if [ "$CODEX_RUN_MOVE_STATUS" = "success" ]; then
    PROMPT_PATH_EFFECTIVE="$DEST"
    CODEX_RUN_MOVED_TO="$DEST"
    echo "moved_prompt_to=$DEST" >> "$RUN_DIR/manifest.txt"
  else
    echo "move_prompt_failed_to=$DEST" >> "$RUN_DIR/manifest.txt"
  fi
fi

stamp_prompt_frontmatter_best_effort "success" || true

if [ -n "${REPO_ROOT:-}" ] && [ "$AUTOCOMMIT" != "0" ]; then
  cd "$REPO_ROOT"
  if sed -n '1,200p' "$PROMPT_PATH_EFFECTIVE" | grep -nE '^codex_autocommit:[[:space:]]*"?no"?[[:space:]]*$' >/dev/null 2>&1; then
    echo "Autocommit disabled by codex_autocommit: no" | tee -a "$RUN_DIR/manifest.txt"
  else
    git add -A
    if git diff --cached --quiet; then
      echo "No staged changes to commit." | tee -a "$RUN_DIR/manifest.txt"
    else
      git diff --cached --name-status > "$RUN_DIR/git.diff.cached.namestatus.txt" 2>&1 || true
      COMMIT_MSG="prompt-exec: $PROMPT_STEM $RUN_UTC"
      if ! git commit -m "$COMMIT_MSG"; then
        echo "commit_failed=1" >> "$RUN_DIR/manifest.txt"
        echo "commit_failed_msg=git commit returned non-zero" >> "$RUN_DIR/manifest.txt"
      else
        COMMIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo '<unknown>')"
        echo "commit=$COMMIT_SHA" >> "$RUN_DIR/manifest.txt"
        echo "codex_last_run_commit=$COMMIT_SHA" >> "$RUN_DIR/manifest.txt"
        git show --name-status --stat --oneline -1 > "$RUN_DIR/git.commit.summary.txt" 2>&1 || true
        stamp_prompt_frontmatter_best_effort "success" "$COMMIT_SHA" || true
      fi
    fi
  fi
fi

CODEX_EXIT_STATUS_OVERRIDE="success"
exit 0
