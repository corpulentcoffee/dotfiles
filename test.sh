#!/usr/bin/env bash
#
# Test if the user home directory appears to be setup correctly by running some
# checks. Each command here is printed (`set -x`) and the script will exit
# if something goes wrong (`set -euETo pipefail`, `shopt -s inherit_errexit`).

set -euxETo pipefail
shopt -s inherit_errexit

trap on_error ERR
on_error() {
  echo 'Test suite failed; manually check your installation.' >&2
}

test -d ~/bin
test ! -e ~/bin/lib # `install.sh` should have skipped `home/bin/lib` directory

# Verify everything in bin is executable and we aren't accidentally conflicting
# with a system-wide bin command, an alias, or some shell built-in.
for path in ~/bin/*; do
  test -x "$path"

  command=$(basename "$path")
  test "$(type -ap "$command" | wc --lines)" -eq 1
  test "$(type -at "$command")" == 'file'
done

aws-as-profile -h | grep -q '^usage: aws-as-profile '
gh-super-linter --help | grep -q '^usage: gh-super-linter '

test "$(git whoami | grep -cF dave@corpulent)" -eq 2

echo 'Everything looks okay!'
