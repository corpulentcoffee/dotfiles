#!/usr/bin/env bash
#
# Switch some local git repository to its latest tag after fetching from remote.

set -euETo pipefail
shopt -s inherit_errexit

if [[ $# -eq 0 ]]; then
  directory=.
elif [[ $# -eq 1 ]]; then
  directory=$1
else
  echo "usage: $0 [<path-to-git-repository-directory>]" >&2
  exit 1
fi

if ! [[ -d $directory/.git ]]; then
  echo "$directory is not a git repository" >&2
  exit 1
fi
cd "$directory"

display=${PWD##*/}
display=${display#.}
[[ -n $display ]] || display=$directory

active=$(git describe --tags HEAD)
if ! [[ $active == v*.*.* ]]; then
  echo "Active tag '$active' for $display doesn't look like a version" >&2
  exit 1
fi

echo "Fetching tags for $display..."
git fetch --tags --prune --prune-tags
latest=$(git tag --list 'v*.*.*' --sort version:refname | tail -1)
echo

if ! [[ $latest == v*.*.* ]]; then
  echo "Latest tag '$latest' for $display doesn't look like a version" >&2
  exit 1
elif [[ $active == "$latest" ]]; then
  git status
  echo
  echo "$active is already the latest version tag for $display"
else
  echo "Switching $display from $active to $latest..."
  echo
  git checkout "$latest"
  echo
  git status
fi
