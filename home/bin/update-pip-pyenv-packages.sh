#!/usr/bin/env bash
#
# Do an upgrade of all pip packages visible from `pyenv`-supplied installs. This
# is usually `$PYENV_ROOT/versions/3.XX.X/lib/python3.XX/site-packages`, but
# *can* be `--user`-installed things in `~/.local/lib/python3.XX/site-packages`,
# notably for when the `python3.XX` version is not the "system" Python.
#
# This doesn't do anything to random project-specific `virtualenv` dependencies.

set -euETo pipefail
shopt -s inherit_errexit

if [[ -v VIRTUAL_ENV ]]; then
  echo "$0 is not intended to be used in a virtualenv." >&2
  exit 1
elif ! [[ -v PYENV_ROOT && -n $PYENV_ROOT && -x $PYENV_ROOT/bin/pyenv ]]; then
  echo "Refusing to run $0 without valid PYENV_ROOT" >&2
  exit 1
fi

if ! [[ ":$PATH:" == *":$PYENV_ROOT/bin:"* ]]; then
  echo "Adding $PYENV_ROOT/bin to PATH for update" >&2
  PATH="$PYENV_ROOT/bin:$PATH"
fi
if [[ $(type -t pyenv) == file ]]; then
  echo 'Initializing pyenv shell integration for update' >&2
  eval "$(pyenv init -)"
fi

declare -a installedVersions=()
while read -r installedVersion; do
  if [[ -n "$installedVersion" ]]; then
    if [[ $installedVersion =~ ^3\.[0-9]+\.[0-9]+$ ]]; then
      installedVersions+=("$installedVersion")
    else
      echo "Unexpected pyenv install version $installedVersion" >&2
      exit 1
    fi
  fi
done <<<"$(pyenv versions --skip-aliases --skip-envs --bare)"

if [[ ${#installedVersions[@]} -eq 0 ]]; then
  echo 'There are no pyenv-supplied installs detected right now' >&2
  exit 0
fi

for version in "${installedVersions[@]}"; do
  echo "+ pyenv shell $version && update-pip-packages" >&2
  (pyenv shell "$version" && update-pip-packages)
done
