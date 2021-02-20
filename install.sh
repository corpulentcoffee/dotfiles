#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit
cd "$(dirname "${BASH_SOURCE[0]}")/home"

if [[ ! "$HOME" =~ ^/ ]]; then
  # HOME needs to be absolute given that we just changed directories above.
  echo 'HOME must be set and must be using an absolute path.' >&2
  exit 1
elif [ "$(git rev-parse --is-inside-work-tree)" != 'true' ]; then
  # We need git to be present and working for `git check-ignore` path checks.
  echo 'git must be installed and repository data must be present.' >&2
  exit 1
fi

okayCount=0
failCount=0
copyCount=0
linkCount=0

while IFS='' read -rd '' srcPath; do
  if git check-ignore "$srcPath" >/dev/null; then
    continue
  fi

  # Install Python and shell script bin files without suffix, and switch Python
  # scripts from importable snake case to ergonomic kebab case.
  if [[ "$srcPath" =~ ^\./bin/[a-z0-9_-]+\.(py|sh)$ ]]; then
    dstPath="${srcPath%.*}"
    if [[ "$srcPath" =~ \.py$ ]]; then
      dstPath="${dstPath//_/-}"
    fi
  else
    dstPath="$srcPath"
  fi
  dstPath="$HOME/${dstPath#./}"

  if [ -L "$dstPath" ]; then
    srcReal="$(realpath "$srcPath")"
    dstLink="$(readlink --canonicalize "$dstPath")"

    if [ "$srcReal" == "$dstLink" ]; then
      ((++okayCount))
    else
      ((++failCount))
      echo "$srcPath: $dstPath already linked to $dstLink instead of $srcReal"
    fi
  elif [ -f "$dstPath" ]; then
    ((++copyCount))
    echo "$srcPath: $dstPath already exists; use version control to reconcile"
    cp --verbose "$dstPath" "$srcPath"
    ln --force --relative --symbolic --verbose "$srcPath" "$dstPath"
  else
    ((++linkCount))
    mkdir --parents --verbose "$(dirname "$dstPath")"
    ln --relative --symbolic --verbose "$srcPath" "$dstPath"
  fi
done < <(find . -type f -print0)

echo
echo "already installed: $okayCount"
echo "failed to install: $failCount"
echo "needs reconciling: $copyCount"
echo "cleanly installed: $linkCount"

test "$failCount" -eq 0 && test "$copyCount" -eq 0
