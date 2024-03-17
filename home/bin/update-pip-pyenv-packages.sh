#!/usr/bin/env bash
#
# Do an upgrade of all pip packages that were directly installed (i.e. not as a
# dependency) inside of some `pyenv`-supplied installation.

set -euETo pipefail
shopt -s inherit_errexit

if [[ ! -v PYENV_ROOT || -z "$PYENV_ROOT" ]]; then
  echo "$0 refusing to run w/o PYENV_ROOT" >&2
  exit 1
fi

if ! command -v pyenv; then
  [[ ":$PATH:" == *":$$PYENV_ROOT/bin:"* ]] || PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

declare -a installedVersions=()
while read -r installedVersion; do
  if [[ -n "$installedVersion" ]]; then
    if [[ $installedVersion =~ ^3\.[0-9]+\.[0-9]+$ ]]; then
      installedVersions+=("$installedVersion")
    else
      echo "unexpected pyenv install version $installedVersion" >&2
      exit 1
    fi
  fi
done <<<"$(pyenv versions --skip-aliases --skip-envs --bare)"

if [[ ${#installedVersions[@]} -eq 0 ]]; then
  echo 'no pyenv installs detected' >&2
  exit 1
fi

for version in "${installedVersions[@]}"; do
  echo "+ pyenv shell $version && update-pip-packages" >&2
  (pyenv shell "$version" && update-pip-packages)
done
