#!/usr/bin/env bash
#
# Output the content for an `aws` bash completion file, after checking the user
# environment.

set -euETo pipefail
shopt -s inherit_errexit

if ! command -v aws >/dev/null; then
  echo 'aws command itself is not installed?' >&2
  exit 1
fi

# Alternatively, if `aws` is a symlink to an unzipped v2 install, it might be
# possible to find `aws_completer` as "$(readlink $(which aws))_completer" and
# then just check that what we find exists, is executable, and returns sensible
# things (e.g. "$(COMMAND_LINE='aws lambd' aws_completer)" == "lambda").
completerPath=$(command -v aws_completer)
if [ -z "$completerPath" ]; then
  echo 'aws_completer must be on the user PATH to be discoverable.' >&2
  exit 1
fi

echo "complete -C '$completerPath' aws"
