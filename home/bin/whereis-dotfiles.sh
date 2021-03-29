#!/usr/bin/env bash
#
# Output the location of the dotfiles repository based on the assumption that
# this script is a symlink into it.

set -euETo pipefail
shopt -s inherit_errexit

if [[ -n "$0" && "$0" == "${BASH_SOURCE[0]}" && -L "$0" ]]; then
  realSelf=$(realpath --relative-to . "$0")
  realBin=$(dirname "$realSelf")
  realHome=$(dirname "$realBin")
  realRepo=$(dirname "$realHome")
  echo "$realRepo"
else
  echo 'Cannot determine dotfiles target via own link.'
  exit 1
fi
