#!/usr/bin/env bash
#
# Do an upgrade of all pip packages that were directly installed (i.e. not as a
# dependency) in "user-site" (i.e. with `--user`; on typical Ubuntu installs,
# these are libraries installed to `~/.local/lib/python3.x/site-packages/`,
# command-line tools installed to `~/.local/bin`, and less commonly, ancillary
# files placed into `~/.local/etc`).

set -euETo pipefail
shopt -s inherit_errexit

readonly pip=pip3
readonly expectedPip=/usr/bin/$pip

if ! actualPip=$(command -v "$pip") >/dev/null; then
  echo "The $pip tool is not installed here." >&2
  exit 1
fi
readonly actualPip

if ! [ "$actualPip" == "$expectedPip" ]; then
  echo "The current $pip tool is $actualPip rather than $expectedPip." >&2
  echo "If inside of a virtualenv, deactivate it before running $0." >&2
  exit 1
fi

mapfile -t packages \
  < <("$pip" list --user --not-required --format=freeze | sed 's/==.*$//')

if ! [ "${#packages[@]}" -gt 0 ]; then
  echo "There does not seem to be any user packages installed via $pip." >&2
  exit 1
fi

exec "$pip" install --user --upgrade -- "${packages[@]}"
