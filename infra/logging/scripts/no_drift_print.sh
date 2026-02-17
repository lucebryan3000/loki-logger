#!/usr/bin/env bash
set -euo pipefail

msg="$*"

tok_one="$(printf '%s%s' '@' 'filename')"
tok_two="$(printf '%s %s %s' 'Write' 'tests' 'for')"
tok_three="$(printf '%s for %s' '?' 'shortcuts')"

if [[ "$msg" == *"$tok_one"* || "$msg" == *"$tok_two"* || "$msg" == *"$tok_three"* ]]; then
  echo "DRIFT_GUARD_BLOCKED" >&2
  exit 99
fi

echo "$msg"
