#!/usr/bin/env bash
#
# Run several updaters in succession and then summarize the results.

set -euETo pipefail
shopt -s inherit_errexit

declare -ar commands=(
  # sudo-based updates go together to avoid sudo window timing out
  update-apt-packages
  update-snap-packages
  update-lvfs-firmware

  # updates done within user home directory that do not require sudo
  update-awscli2-install
  update-nvm-install
  update-pyenv-install
  update-pip-pyenv-packages
  update-pip-user-packages

  # prior updates might affect completion output, so that goes last
  update-bash-completion
)

banner() {
  local columns
  columns=$(tput cols)
  printf "%${columns}s\n" | tr ' ' '='
  echo "$*"
  printf "%${columns}s\n" | tr ' ' '='
}

declare -A outcomes

for command in "${commands[@]}"; do
  banner "$command"
  if "$command"; then
    outcomes[$command]=OK
  else
    outcomes[$command]=$?
  fi
  echo
done

banner 'Summary'
for command in "${commands[@]}"; do
  outcome=${outcomes[$command]}
  if [ "$outcome" == "OK" ]; then
    echo "✓ $command"
  else
    echo "✗ $command returned exit status $outcome"
  fi
done
