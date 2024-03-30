#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit

if [[ -v NVM_DIR ]]; then
  update-git-checkout "$NVM_DIR"
else
  echo 'nvm does not seem to be installed here (expecting NVM_DIR)' >&2
  exit 1
fi
