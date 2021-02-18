#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit

# Quickly save changes back to the remote, especially in notetaking-style repos.
# Inspired by <https://gitjournal.io/support/#auto-syncing-from-the-desktop>,
# but more conservative, with greater opportunities to confirm or bail out of
# what is happening.

function msg() {
  echo
  echo "$*..."
}

repoToplevel="$(git rev-parse --show-toplevel)"
cd "$repoToplevel"

repoBranch="$(git symbolic-ref HEAD)" # and we want to error out if off-branch
repoStatus="$(git status --porcelain)"

if [ "${#repoStatus}" -ne 0 ]; then # dirty working directory
  mapfile -t newFiles < <(echo "$repoStatus" | grep '^?? ' | cut -d' ' -f2-)
  for newFile in "${newFiles[@]}"; do
    read -rp "Add $newFile? "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      git stage --intent-to-add --verbose -- "$newFile"
    fi
  done

  # Additional arguments can optionally be passed here (e.g.`-m <msg>`, path),
  # so completion for this script can follow `git commit` (see `.gitconfig`).
  # Note that `git commit` returns a non-zero status if nothing is commited.
  git commit --patch "$@" || true

  msg 'Stashing and then rebasing this branch on remote, if needed'
  git pull --autostash --rebase --verbose
else # clean working directory
  msg 'Rebasing this branch on remote, if needed'
  git pull --rebase --verbose
fi

msg 'Updating remote with local changes'
git push --verbose

# Special but not totally uncommon case: secondary remote for the trunk branch.
# This sort of thing could alternatively be handled by a local in-repo alias
# that overrides the global `alias.sync` configuration.
readonly backupRemote=backups
if [[ $repoBranch =~ ^refs/heads/ma(in|ster)$ ]] &&
  [ -n "$(git branch --remotes --list "$backupRemote/${repoBranch##*/}")" ]; then
  msg "Updating $backupRemote remote"
  git push --verbose -- "$backupRemote" "${repoBranch##*/}"
fi

# Discover other changes on remote(s) unrelated to current branch.
msg 'Discovering other changes on remotes'
git up
