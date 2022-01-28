#!/usr/bin/env bash
#
# Display log output with a colored graph in the left gutter.
#
# Arguments to this script will be forwarded to `git log`, For bash completion
# to work, `git graph` should be registered as a `log`-like script:
#
# [alias]
# 	graph = !: git log && gitalias-graph

set -euETo pipefail
shopt -s inherit_errexit

readonly commitHash='%C(yellow)%h%C(reset)'
readonly authorDate='%C(bold green)%ar%C(reset)'
readonly subject='%C(white)%s%C(reset)'
readonly authorName='%C(dim white)%an%C(reset)'
readonly refNames='%C(bold red)%D%C(reset)'

exec git log \
  --format="$commitHash $authorDate $subject $authorName $refNames" \
  --graph \
  "$@"
