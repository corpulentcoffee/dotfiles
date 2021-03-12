#!/usr/bin/env bash
#
# Delete all local branches that
#
# - have been merged to HEAD
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

readonly listFormat='%(upstream:track):%(push:track):%(HEAD):%(refname:strip=2)'
readonly isEligible='^\[gone\]:\[gone\]: :'
readonly branchField=4

git branch --list --merged HEAD --format "$listFormat" "$@" |
  grep "$isEligible" |
  cut --delimiter ':' --fields "${branchField}-" |
  while read -r branch; do
    git branch --delete "$branch"
  done
