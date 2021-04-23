#!/usr/bin/env bash
#
# Perform an upgrade of LVFS-provided firmware, like that from Dell, after
# refreshing metadata from the remote server. Assumes sudo privileges are needed
# to run `fwupdmgr` commands.

set -euETo pipefail
shopt -s inherit_errexit

readonly fwupdmgr=fwupdmgr
readonly sudo=sudo

for command in "$fwupdmgr" "$sudo"; do
  if ! command -v "$command" >/dev/null; then
    echo "Cannot perform LVFS firmware upgrades without $command tool." >&2
    exit 1
  fi
done

if ! output=$("$sudo" "$fwupdmgr" refresh 2>&1); then
  if [[ "$output" == *"metadata last refresh"*"--force to refresh"* ]]; then
    echo "$output" # we're handling this error, so send to stdout
    "$sudo" "$fwupdmgr" refresh --force
  else # send any other unrecognized message to stderr and bail out
    echo "$output" >&2
    exit 1
  fi
fi

"$sudo" "$fwupdmgr" upgrade
