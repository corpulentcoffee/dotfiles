#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit

# Quickly save changes back to the remote, especially in notetaking-style repos.
# Inspired by <https://gitjournal.io/support/#auto-syncing-from-the-desktop>,
# but more conservative, with greater opportunities to confirm or bail out of
# what is happening.

repoToplevel="$(git rev-parse --show-toplevel)"
cd "$repoToplevel"

repoBranch="$(git symbolic-ref HEAD)" # and we want to error out if off-branch
repoStatus="$(git status --porcelain)"

if [ "${#repoStatus}" -ne 0 ]; then # dirty working directory
  mapfile -t newFiles < <(echo "$repoStatus" | grep '^?? ' | cut -d' ' -f2-)
  for newFile in "${newFiles[@]}"; do
    read -rp "Add $newFile? "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      git stage --intent-to-add "$newFile"
    fi
  done

  # Additional arguments can optionally be passed here (e.g.`-m <msg>`, path),
  # so completion for this script can follow `git commit` (see `.gitconfig`).
  # Note that `git commit` returns a non-zero status if nothing is commited.
  git commit --patch "$@" || true

  git pull --autostash --rebase
else # clean working directory
  git pull --rebase
fi

git push --verbose

# Special but not totally uncommon case: secondary remote for the trunk branch.
# This sort of thing could alternatively be handled by a local in-repo alias
# that overrides the global `alias.sync` configuration.
readonly backupRemote=backups
if [[ $repoBranch =~ ^refs/heads/ma(in|ster)$ ]] &&
  [ -n "$(git branch --remotes --list "$backupRemote/${repoBranch##*/}")" ]; then
  git push --verbose "$backupRemote" "${repoBranch##*/}"
fi

# Discover other changes on remote(s) unrelated to current branch
git up
