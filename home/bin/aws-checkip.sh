#!/usr/bin/env bash
#
# Output current public IP based on the `checkip` endpoint at AWS.

set -euETo pipefail
shopt -s inherit_errexit

readonly endpoint='https://checkip.amazonaws.com/'

if ! curl --fail --silent "$endpoint"; then
  echo "Unable to query $endpoint" >&2
  exit 1
fi
