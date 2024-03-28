#!/usr/bin/env bash
#
# TODO: This is *mostly* like `update-nvm-install`; refactor out common bits.

set -euETo pipefail
shopt -s inherit_errexit

if ! [[ -v PYENV_ROOT && -d "$PYENV_ROOT" && -d "$PYENV_ROOT/.git" ]]; then
  echo 'pyenv does not seem to be installed here.' >&2
  echo '(Expecting PYENV_ROOT to be set to a checked-out git repository.)' >&2
  exit 1
fi

cd "$PYENV_ROOT"

active=$(git describe --tags) # n.b. pyenv project uses LIGHT-WEIGHT tags
if ! [[ "$active" == v*.*.* ]]; then
  echo "Got '$active' for current HEAD of $PYENV_ROOT instead of version tag." >&2
  exit 1
fi

git fetch --tags --prune --prune-tags
latest=$(git tag --list 'v*.*.*' --sort version:refname | tail --lines=1)

if [ -z "$latest" ]; then
  echo 'Cannot determine the latest version.' >&2
  exit 1
elif [ "$active" == "$latest" ]; then
  git status
  echo
  echo "$active is already the latest version of pyenv."
else
  echo
  echo "Switching pyenv from $active to $latest..."
  echo
  git checkout "$latest"
  echo
  git status
fi
