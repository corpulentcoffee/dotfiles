#!/usr/bin/env bash
#
# Run the Trino CLI with Docker (to avoid installing a JVM on host machine).
# Use a subdirectory in home directory on host to persist readline history.

set -euETo pipefail
shopt -s inherit_errexit

readonly hostTrinoHome=~/.trino-cli # holds readline history, cache
readonly guestTrinoHome=/home/trino
readonly containerImage=trinodb/trino
readonly entrypointBin=trino

if [ ! -d "$hostTrinoHome" ]; then
  mkdir --verbose "$hostTrinoHome"
fi

set -x

docker run \
  --interactive \
  --mount "type=bind,source=${hostTrinoHome},destination=${guestTrinoHome}" \
  --rm \
  --tty \
  "$containerImage" "$entrypointBin" "$@"
