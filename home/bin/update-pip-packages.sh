#!/usr/bin/env bash
#
# Attempt to upgrade all pip packages using whatever the environment's current
# notion of `pip3` is (e.g. virtualenv-supplied, pyenv-supplied, system).

set -euETo pipefail
shopt -s inherit_errexit

sawAll=false
listCmd=(list --outdated --exclude-editable)
upgrCmd=(install --upgrade)
cliArgs=$(
  getopt --name "$0" \
    --options ha \
    --longoptions help,all,exclude:,user,upgrade-strategy: \
    -- "$@"
)
eval set -- "$cliArgs"
while [[ $# -gt 0 ]]; do
  case "$1" in
  --help | -h)
    echo Usage:
    echo "  $0 [--all] [--exclude=<pkg>] [--user] [--upgrade-strategy=eager]"
    exit 0
    ;;
  --all | -a) sawAll=true ;;
  --exclude) shift && listCmd+=(--exclude "$1") ;;
  --user) listCmd+=(--user) && upgrCmd+=(--user) ;;
  --upgrade-strategy) shift && upgrCmd+=(--upgrade-strategy "$1") ;;
  *) break ;;
  esac
  shift
done
if [[ $* != -- ]]; then
  echo "$0: unexpected trailing arguments" >&2
  echo "$@" >&2
  exit 1
fi
[[ $sawAll == true ]] || listCmd+=(--not-required)

pip=pip3
pip=$(command -v "$pip")

if [[ -v VIRTUAL_ENV ]]; then
  if [[ ${listCmd[*]} =~ ' --user' ]]; then
    echo "$0 is not intended to be used in a virtualenv with --user." >&2
    exit 1
  elif ! [[ $pip == "$VIRTUAL_ENV/bin/"* ]]; then
    echo "we are supposedly using $VIRTUAL_ENV but pip is $pip " >&2
    exit 1
  fi
  listCmd+=(--local)
  upgrCmd+=(--local)
elif [[ -v PYENV_ROOT && -n $PYENV_ROOT && $pip == "$PYENV_ROOT/shims/"* ]]; then
  installVersion=$(pyenv version-name)
  if [[ $installVersion =~ ^3\.[0-9]+\.[0-9]+$ ]]; then
    echo "!! $pip shim to '$installVersion'" >&2
  else
    echo "$0 refusing to use $pip shim to '$installVersion'" >&2
    exit 1
  fi
elif ! [[ ${listCmd[*]} =~ ' --user' ]]; then
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
    "$pip" "${listCmd[@]}" --format=json
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
exec "$pip" "${upgrCmd[@]}" -- "${!outdatedVersions[@]}"
