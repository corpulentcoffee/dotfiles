#!/usr/bin/env bash
#
# Perform an upgrade ("refresh") of snap-provided packages from Canonical and
# other publishers. Assumes sudo privileges are needed to run `snap refresh`.
#
# Note that this command will undo any in-place revision overrides.

set -euETo pipefail
shopt -s inherit_errexit

readonly snap=snap
readonly sudo=sudo

for command in "$snap" "$sudo"; do
  if ! command -v "$command" >/dev/null; then
    echo "Cannot perform Snap package refresh without $command tool." >&2
    exit 1
  fi
done

exec "$sudo" "$snap" refresh
