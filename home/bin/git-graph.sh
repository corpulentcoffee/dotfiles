#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit

readonly commitHash='%C(yellow)%h%C(reset)'
readonly authorDate='%C(bold green)%ar%C(reset)'
readonly subject='%C(white)%s%C(reset)'
readonly authorName='%C(dim white)%an%C(reset)'
readonly refNames='%C(bold red)%D%C(reset)'

git log \
  --format="$commitHash $authorDate $subject $authorName $refNames" \
  --graph \
  "$@"
