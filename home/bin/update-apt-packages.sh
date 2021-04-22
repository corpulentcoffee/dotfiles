#!/usr/bin/env bash
#
# Perform an upgrade of apt-provided packages like those from Canonical, Google,
# and Microsoft after updating package information from configured sources.
# Assumes sudo privileges are needed to run `apt` commands.

set -euETo pipefail
shopt -s inherit_errexit

readonly apt=apt
readonly sudo=sudo

for command in "$apt" "$sudo"; do
  if ! command -v "$command" >/dev/null; then
    echo "Cannot perform Apt package upgrade without $command tool." >&2
    exit 1
  fi
done

"$sudo" "$apt" update
"$sudo" "$apt" upgrade
