#!/usr/bin/env bash
#
# Test if the user home directory appears to be setup correctly by running some
# checks. Each command here is printed (`set -x`) and the script will exit
# if something goes wrong (`set -euETo pipefail`, `shopt -s inherit_errexit`).

set -euxETo pipefail
shopt -s inherit_errexit

test ! -e ~/bin/lib # `install.sh` should have skipped `home/bin/lib` directory
aws-as-profile -h | grep -q '^usage: aws-as-profile '
gh-super-linter --help | grep -q '^usage: gh-super-linter '

test "$(git whoami | grep -cF dave@corpulent)" -eq 2
