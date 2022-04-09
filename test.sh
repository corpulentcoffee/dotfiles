#!/usr/bin/env bash
#
# Test if the user home directory appears to be setup correctly by running some
# checks. Each command here is printed (`set -x`) and the script will exit
# if something goes wrong (`set -euETo pipefail`, `shopt -s inherit_errexit`).

case "$BASH_VERSION" in # see also same check in `install.sh`
5.*) ;;
*)
  echo "expecting bash 5.x but got '${BASH_VERSION}'; cautiously exiting" >&2
  exit 1
  ;;
esac

set -euETo pipefail
shopt -s inherit_errexit

trap on_error ERR
on_error() {
  echo 'Test suite failed; manually check your installation.' >&2
}
set -x

[[ ":$PATH:" == *":$HOME/bin:"* ]] # see hints in `install.sh`
test -d ~/bin
test ! -e ~/bin/lib # `install.sh` should have skipped `home/bin/lib` directory
bash -i test-interactive.sh

aws-as-profile -h | grep -q '^usage: aws-as-profile '
gh-super-linter --help | grep -q '^usage: gh-super-linter '
git whoami | grep --quiet --fixed-strings dave@corpulent

(
  # This relies on `aws_completer` ignoring user aliases. If that changes (which
  # would be great!), then this test won't work anymore as written.
  set +x
  if ! type aws_completer; then
    echo 'warning: skipping AWS CLI alias shadowing test' >&2
    exit
  fi
  echo 'checking that AWS CLI aliases do not shadow built-in commands...'

  aliases=$(grep --perl-regexp '^\s*[\w-]+\s*=' ~/.aws/cli/alias | cut -d'=' -f1)
  builtins=$(COMMAND_LINE='aws ' aws_completer)
  readonly aliases builtins

  test "$(echo "$aliases" | wc --lines)" -gt 1
  test "$(echo "$builtins" | wc --lines)" -gt 250
  for alias in $aliases; do
    echo -n "$alias: "
    if echo "$builtins" | grep "\b${alias}\b"; then
      exit 1
    fi
    echo "OK"
  done
)

echo 'Everything looks okay!'
