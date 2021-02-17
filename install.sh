#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit
cd "$(dirname "${BASH_SOURCE[0]}")/home"

skipCount=0

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

    if [ "$srcReal" != "$dstLink" ]; then
      ((++skipCount))
      echo "$srcPath: $dstPath already linked to $dstLink instead of $srcReal"
    fi
  else
    mkdir --parents --verbose "$dstDir"
    ln --relative --symbolic --verbose "$srcPath" "$dstPath"
  fi
done < <(find . -type f -print0)

if [ "$skipCount" -gt 0 ]; then
  if [ "$skipCount" -eq 1 ]; then
    echo 'One file could not be installed.' >&2
  else
    echo "$skipCount files could not be installed." >&2
  fi
  exit 1
fi
