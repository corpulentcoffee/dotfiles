#!/usr/bin/env bash
#
# Test if the user home directory appears to be setup correctly by running some
# checks. Each command here is printed (`set -x`) and the script will exit
# if something goes wrong (`set -euETo pipefail`, `shopt -s inherit_errexit`).

set -euETo pipefail
shopt -s inherit_errexit

if ! [[ ":$PATH:" == *":$HOME/bin:"* ]]; then
  echo "$HOME/bin is absent from the user PATH, which is currently:" >&2
  echo "$PATH" >&2
  echo >&2
  echo 'A logout/login cycle might be needed for ~/.profile to add it' >&2
  exit 1
fi

trap on_error ERR
on_error() {
  echo 'Test suite failed; manually check your installation.' >&2
}
set -x

test -d ~/bin
test ! -e ~/bin/lib # `install.sh` should have skipped `home/bin/lib` directory

# Verify everything in bin is executable and we aren't accidentally conflicting
# with a system-wide bin command, an alias, or some shell built-in.
for path in ~/bin/*; do
  test -x "$path"

  command=$(basename "$path")
  test "$(type -ap "$command")" == "$HOME/bin/$command"
  test "$(type -at "$command")" == 'file'
done

aws-as-profile -h | grep -q '^usage: aws-as-profile '
gh-super-linter --help | grep -q '^usage: gh-super-linter '

test "$(git whoami | grep -cF dave@corpulent)" -eq 2

echo 'Everything looks okay!'
