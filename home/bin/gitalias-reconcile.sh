#!/usr/bin/env bash
#
# Quickly save changes back to the remote, especially in notetaking-style repos.
# Inspired by <https://gitjournal.io/support/#auto-syncing-from-the-desktop>,
# but more conservative, with greater opportunities to confirm or bail out of
# what is happening.
#
# Arguments to this script will be forwarded along after `git commit --patch`,
# e.g. `git reconcile -m <msg>` would become `git commit --patch -m <msg>`. For
# bash completion to work, `git reconcile` should be registered as a
# `commit`-like script:
#
# [alias]
# 	reconcile = !: git commit && gitalias-reconcile

set -euETo pipefail
shopt -s inherit_errexit

repoToplevel="$(git rev-parse --show-toplevel)"
cd "$repoToplevel"

git symbolic-ref HEAD >/dev/null # we want to error out if off-branch
repoStatus="$(git status --porcelain)"

if [ "${#repoStatus}" -ne 0 ]; then # dirty working directory
  mapfile -t newFiles < <(echo "$repoStatus" | grep '^?? ' | cut -d' ' -f2-)
  for newFile in "${newFiles[@]}"; do
    read -rp "Add $newFile? "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      git stage --intent-to-add --verbose -- "$newFile"
    fi
  done

  # Note that `git commit` returns a non-zero status if nothing is commited.
  git commit --patch "$@" || true

  echo
  echo 'Stashing and then rebasing this branch on remote, if needed'
  git pull --autostash --rebase --verbose
else # clean working directory
  echo
  echo 'Rebasing this branch on remote, if needed'
  git pull --rebase --verbose
fi

echo
echo 'Updating remote with local changes'
git push --verbose
