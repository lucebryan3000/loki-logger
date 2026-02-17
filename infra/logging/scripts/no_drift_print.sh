#!/usr/bin/env bash
set -euo pipefail
msg="$*"
case "$msg" in
  *"@filename"*|*"Write tests for"*|*"? for shortcuts"*)
    # never print; log to stderr and exit nonzero
    echo "DRIFT_GUARD_BLOCKED" >&2
    exit 99
    ;;
esac
# safe: print
echo "$msg"
