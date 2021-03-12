#!/usr/bin/env bash
#
# Delete all local branches that
#
# - have been merged to HEAD but aren't the current HEAD branch itself
#   *and*
# - used to have an upstream (pull) remote that is now gone
#   *and*
# - used to have a push remote that is now gone.
#
# Arguments to this script will be forwarded after `git branch --list` (e.g. to
# allow further limiting of which branches are eligible for deletion). For bash
# completion to work, `git delete-merged-orphans` should be registered as a
# `branch`-like script:
#
# [alias]
# 	delete-merged-orphans = !: git branch && gitalias-delete-merged-orphans
#
# This script returns a non-zero status if there are no branches eligible to
# delete (because of `grep` in the pipeline combined with `set -o pipefail`).
# If changing this behavior, see `gitalias-sync.sh`, which checks the status.

set -euETo pipefail
shopt -s inherit_errexit

# It's also possible to use `%(refname:strip=2)` instead of `cut`ting out the
# local part of the full `%(refname)`, but being more explicit here could
# prevent some future accident where `isEligible` isn't so strict (like not
# checking for `[gone]` anymore) and something weird (like `--all`) is passed
# into this script and thus into `git branch`.
readonly listFormat='%(upstream:track):%(push:track):%(HEAD):%(refname)'
readonly isEligible='^\[gone\]:\[gone\]: :refs/heads/.'
readonly refField=4
readonly localSegment=3

git branch --list --merged HEAD --format "$listFormat" "$@" |
  grep "$isEligible" |
  cut --delimiter ':' --fields "${refField}-" |
  cut --delimiter '/' --fields "${localSegment}-" |
  while read -r branch; do
    git branch --delete "$branch"
  done
