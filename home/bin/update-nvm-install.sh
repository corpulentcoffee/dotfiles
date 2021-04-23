#!/usr/bin/env bash
#
# Fetch remote tags for the checked-out nvm repository as specified by NVM_DIR
# and then switch to the latest version tag.

set -euETo pipefail
shopt -s inherit_errexit

if ! [[ -v NVM_DIR && -d "$NVM_DIR" && -d "$NVM_DIR/.git" ]]; then
  echo 'nvm does not seem to be installed here.' >&2
  echo '(Expecting NVM_DIR to be set to a checked-out git repository.)' >&2
  exit 1
fi

cd "$NVM_DIR"

active=$(git describe --exact-match) # n.b. nvm project uses annotated tags
if ! [[ "$active" == v*.*.* ]]; then
  echo "Got '$active' for current HEAD of $NVM_DIR instead of version tag." >&2
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
  echo "$active is already the latest version of nvm."
else
  echo
  echo "Switching nvm from $active to $latest..."
  echo
  git checkout "$latest"
  echo
  git status
fi
