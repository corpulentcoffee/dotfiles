#!/usr/bin/env bash
#
# The tests in this file inspect aliases and shell functions, so it's intended
# to be run inside an interactive shell (e.g. `bash -i test-interactive.sh`);
# the shebang above is just so tools recognize that this is a bash shell script.

set -euETo pipefail
shopt -s inherit_errexit

case $- in
*i*) ;;
*)
  echo 'test-interactive.sh must be run as if an interactive shell.' >&2
  exit 1
  ;;
esac

set -x

# Verify everything in bin is executable and we aren't accidentally conflicting
# with a system-wide bin command, an alias, or some shell built-in.
for path in ~/bin/*; do
  test -x "$path" # will also fail on a dangling symlink

  command=$(basename "$path")

  # If the user path contains ~/bin multiple times, then `type -a` will also
  # output multiple times, so `sort --unique` is used here to de-duplicate.
  test "$(type -ap "$command" | sort --unique)" == "$HOME/bin/$command"
  test "$(type -at "$command" | sort --unique)" == 'file'
done
