#!/usr/bin/env bash
#
# Quickly save changes back to the remote, especially in notetaking-style repos.
# Inspired by <https://gitjournal.io/support/#auto-syncing-from-the-desktop>,
# but more conservative, with greater opportunities to confirm or bail out of
# what is happening.
#
# Arguments to this script will be forwarded along after `git commit`, e.g.
# `git reconcile -pm <msg>` would become `git commit -pm <msg>`. For bash
# completion to work, `git reconcile` should be registered as a `commit`-like
# script:
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
  # Hacky (should parse arguments for real), but, if an interactive commit or
  # adding all files, then there is probably interest in adding untracked files.
  if [[ "$*" =~ (^| )(-[a-zA-Z]*[ap]|--(all|interactive|patch)) ]]; then
    mapfile -t newFiles < <(echo "$repoStatus" | grep '^?? ' | cut -d' ' -f2-)
    for newFile in "${newFiles[@]}"; do
      read -rp "Add $newFile? "
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stage --intent-to-add --verbose -- "$newFile"
      fi
    done
  fi

  # Note that `git commit` returns a non-zero status if nothing is commited.
  echo
  git commit "$@" || echo 'continuing without new commit'
fi

echo
if git push --verbose; then
  exit 0
fi

echo
echo 'Stashing and then rebasing this branch on remote'
git pull --autostash --rebase --verbose

echo
echo 'Trying again to update remote'
git push --verbose
