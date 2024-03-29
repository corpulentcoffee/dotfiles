#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit

if [[ -v PYENV_ROOT ]]; then
  update-git-checkout "$PYENV_ROOT"
else
  echo 'pyenv does not seem to be installed here (expecting PYENV_ROOT)' >&2
  exit 1
fi
