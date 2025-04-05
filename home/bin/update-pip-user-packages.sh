#!/usr/bin/env bash
#
# Do an upgrade of all pip packages that were directly installed (i.e. not as a
# dependency) via system `pip3`/`python3` in "user-site" (i.e. with `--user`).
#
# On older Ubuntu installs, these are
#
# - libraries installed to `~/.local/lib/python3.x/site-packages/`,
# - command-line tools installed to `~/.local/bin`, and,
# - less commonly, ancillary files (e.g. completion) placed into `~/.local/etc`.
#
# Newer Ubuntus follow PEP 668 w/ a `/usr/lib/python3.x/EXTERNALLY-MANAGED` file
# that _discourages_ user-site packages, making this script less relevant.

set -euETo pipefail
shopt -s inherit_errexit

if [[ -v VIRTUAL_ENV ]]; then
  echo "$0 is not intended to be used in a virtualenv." >&2
  exit 1
fi

readonly pip=pip3
readonly expectedPip=/usr/bin/$pip

if ! actualPip=$(command -v "$pip") >/dev/null; then
  echo "The $pip tool is not installed here." >&2
  exit 1
fi
readonly actualPip

if ! [ "$actualPip" == "$expectedPip" ]; then
  echo "The current $pip tool is $actualPip rather than $expectedPip." >&2
  echo "If using pyenv or similar, deactivate before running $0." >&2
  exit 1
fi

update-pip-packages --user
