#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit
cd "$(dirname "${BASH_SOURCE[0]}")/home"

okayCount=0
failCount=0
copyCount=0
linkCount=0

while IFS='' read -rd '' srcPath; do
  srcDir="$(dirname "$srcPath")"
  dstDir="$HOME/$srcDir"
  dstPath="$HOME/$srcPath"

  # Special case: install Python and shell script bin files without suffix.
  if [[ "$srcDir" == './bin' && "$srcPath" =~ \.(py|sh)$ ]]; then
    dstPath="${dstPath%.*}"
  fi

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
    mkdir --parents --verbose "$dstDir"
    ln --relative --symbolic --verbose "$srcPath" "$dstPath"
  fi
done < <(find . -type f -print0)

echo
echo "already installed: $okayCount"
echo "failed to install: $failCount"
echo "needs reconciling: $copyCount"
echo "cleanly installed: $linkCount"

test "$failCount" -eq 0 && test "$copyCount" -eq 0
