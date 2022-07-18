#!/usr/bin/env bash
#
# Query the `dns.toys` service with one or more "FQDNs" and then display
# answer(s) in columns, for example:
#
#     $ dnstoys {los-angeles,phoenix,denver,chicago,new-york}/us.time
#     dig -t TXT @dns.toys +noall +answer los-angeles/us.time phoenix/us.time denver/us.time chicago/us.time new-york/us.time
#
#     Los Angeles (America/Los_Angeles, US)  Mon, 18 Jul 2022 05:30:05 -0700
#     Phoenix (America/Phoenix, US)          Mon, 18 Jul 2022 05:30:05 -0700
#     Denver (America/Denver, US)            Mon, 18 Jul 2022 06:30:05 -0600
#     Chicago (America/Chicago, US)          Mon, 18 Jul 2022 07:30:05 -0500
#     New York (America/New_York, US)        Mon, 18 Jul 2022 08:30:05 -0400
#
# See <https://www.dns.toys/> and <https://github.com/knadh/dns.toys> for more
# information and examples.

set -euETo pipefail
shopt -s inherit_errexit

command=(dig -t TXT @dns.toys +noall +answer "$@")
if [ $# -eq 0 ]; then
  command+=(help)
fi
readonly command

echo "${command[@]}" >&2
echo >&2

"${command[@]}" |
  cut --delimiter '"' --fields 2- |
  sed \
    --expression 's/" "/|/g' \
    --expression 's/"$//' |
  column -ts'|'
