#!/usr/bin/env bash

function main() {
  echo "Hello world!"
}

if [ "$0" == "${BASH_SOURCE[0]}" ]; then # we weren't `source`d (for debugging)
  set -euETo pipefail
  shopt -s inherit_errexit

  main
fi
