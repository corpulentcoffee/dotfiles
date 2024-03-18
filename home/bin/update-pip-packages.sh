#!/usr/bin/env bash
#
# Do an upgrade of all pip packages using the current environment's `pip3`,
# which may be the system `pip3`, or may be e.g. some `pyenv`-supplied one.

set -euETo pipefail
shopt -s inherit_errexit

isUser=false
if [[ $# -gt 0 ]]; then
  if [[ $# -eq 1 && $1 == --user ]]; then
    isUser=true
  else
    echo "usage: $0 [--user]" >&2
    exit 1
  fi
fi

pip=pip3
pip=$(command -v "$pip")

if [[ -v PYENV_ROOT && -n $PYENV_ROOT && $pip == "$PYENV_ROOT/shims/"* ]]; then
  installVersion=$(pyenv version-name)
  if [[ $installVersion =~ ^3\.[0-9]+\.[0-9]+$ ]]; then
    echo "!! $pip shim to '$installVersion'" >&2
  else
    echo "$0 refusing to use $pip shim to '$installVersion'" >&2
    exit 1
  fi
elif ! [[ $isUser == true ]]; then
  echo "$0 refusing to use system $pip w/o --user" >&2
  exit 1
fi

declare -A outdatedVersions=()
declare -A latestVersions=()

while IFS=' ' read -ra line; do
  if [[ -n "${line[*]}" ]]; then
    test ${#line[@]} == 3
    outdatedVersions[${line[0]}]=${line[1]}
    latestVersions[${line[0]}]=${line[2]}
  fi
done <<<"$(
  (
    set -x
    "$pip" list "$@" --not-required --outdated --format=json
  ) | jq -r '.[] | "\(.name) \(.version) \(.latest_version)"'
)"

if [[ ${#outdatedVersions[@]} -eq 0 ]]; then
  echo '.. nothing needs updating'
  exit 0
fi

for package in "${!outdatedVersions[@]}"; do
  echo "   $package  ${outdatedVersions[$package]}  ->  ${latestVersions[$package]}"
done
read -rp "   OK? "
[[ $REPLY =~ ^[Nn] ]] && exit 0
[[ $REPLY =~ ^[Yy] ]] || exit 1

set -x
exec "$pip" install "$@" --upgrade -- "${!outdatedVersions[@]}"
