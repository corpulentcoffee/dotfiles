#!/usr/bin/env bash
#
# Sets (or unsets) proxies in `~/.docker/config.json`.
#
# Try something like `docker run --rm alpine printenv` to test.

set -euETo pipefail
shopt -s inherit_errexit

if [ $# -gt 2 ]; then
  echo "usage: $0 [proxy-url [no-proxy-hostname,no-proxy-hostname2,...]]" >&2
  exit 1
fi

readonly configFile=~/.docker/config.json
if [ ! -f "$configFile" ]; then
  echo "file $configFile does not exist" >&2
  exit 1
fi

if [ $# -gt 0 ]; then
  readonly proxyUrl=$1
else
  readonly proxyUrl=''
fi

if [ $# -gt 1 ]; then
  readonly noProxy=$2
else
  readonly noProxy=''
fi

newConfig=$(
  if [[ -n "$proxyUrl" || -n "$noProxy" ]]; then
    jq --slurp add \
      "$configFile" \
      <(jo proxies="$(jo default="$(
        jo -- \
          -s ftpProxy="$proxyUrl" \
          -s httpProxy="$proxyUrl" \
          -s httpsProxy="$proxyUrl" \
          -s noProxy="$noProxy"
      )")")
  else
    jq 'del(.proxies)' "$configFile"
  fi
)
readonly newConfig

echo "$newConfig" >"$configFile"
