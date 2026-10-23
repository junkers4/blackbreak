#!/usr/bin/env bash
# Print the CHANGELOG.md section for a version: tools/release-notes.sh X.Y.Z
set -eu
v="${1:?usage: release-notes.sh X.Y.Z}"
root="$(cd "$(dirname "$0")/.." && pwd)"
notes="$(awk -v v="$v" '
  index($0, "## [" v "]") == 1 { on = 1; next }
  /^## \[/ { on = 0 }
  on { print }
' "$root/CHANGELOG.md" | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}' | sed '/./,$!d')"
if [ -z "$notes" ]; then
  echo "no CHANGELOG entry for $v" >&2
  exit 1
fi
printf '%s\n' "$notes"
