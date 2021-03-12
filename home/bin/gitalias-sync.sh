#!/usr/bin/env bash
#
# This is a convenience script doing four actions in succession:
#
# 1. `git reconcile`, see `gitalias-reconcile.sh`
# 2. update a "backups" remote if it exists and if currently on trunk
# 3. `git up`, see `../.gitconfig`
# 4. `git delete-merged-orphans`, see `gitalias-delete-merged-orphans.sh`
#
# Arguments to this script will be forwarded to `git reconcile`, which itself
# forwards those arguments to `git commit`, so `git sync` should be registered
# as a `commit`-like script:
#
# [alias]
# 	sync = !: git commit && gitalias-sync

set -euETo pipefail
shopt -s inherit_errexit

repoBranch="$(git symbolic-ref HEAD)" # and we want to error out if off-branch
readonly repoBranch

git reconcile "$@"

# Special but not totally uncommon case: secondary remote for the trunk branch.
# This sort of thing could alternatively be handled by a local in-repo alias
# that overrides the global `alias.sync` configuration. However, one would have
# to be mindful of argument handling (which are appended after alias expansion),
# like by wrapping it with an immediately-called shell function:
#
# [alias]
# 	sync = "!f() { : git commit && gitalias-sync \"$@\" && git push backups master; }; f"
readonly backupRemote=backups
if [[ $repoBranch =~ ^refs/heads/ma(in|ster)$ ]] &&
  [ -n "$(git branch --remotes --list "$backupRemote/${repoBranch##*/}")" ]; then
  echo
  echo "Updating $backupRemote remote"
  git push --verbose -- "$backupRemote" "${repoBranch##*/}"
fi

# Discover other changes on remote(s) unrelated to current branch.
echo
echo 'Discovering other changes on remotes'
git up

echo
echo 'Deleting local merged branches that have been orphaned from their remote'
git delete-merged-orphans || echo 'Nothing to delete'
