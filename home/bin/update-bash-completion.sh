#!/usr/bin/env bash
#
# While `apt`-installed tools generally neatly setup bash completion by dropping
# a managed file into `/usr/share/bash-completion/completions`, user-installed
# tools usually aren't so nice.
#
# Some such user-installed tools recommend enabling their bash completion by
# `source`/`.`/`eval`ing the output of one of their commands during shell
# initialization in `.bashrc`. Some tools are slow, though, and executing them
# to get their bash completion output takes time, even if the tool won't be used
# in a particular bash session.
#
# This script intends to allow the bash completion output of such tools to be
# obtained ahead of time and placed in the user completion directory so they do
# not need to take initialization time unless actually used. Then, it can be run
# at any time to freshen those bash completion files as new versions of tools
# are released.
#
# What this script does not handle, however, and shouldn't need to handle:
#
# - Tools which are `complete`-compatible, which do not slow down shell
#   initialization and can go into `.bashrc`, e.g. the AWS CLI (`aws`) has a
#   `aws_completer` setup something like this: `complete -C ~/aws_completer aws`
# - Tools that come with a pre-baked bash completion file as part of their code;
#   these can just be symlinked into the user bash completion directory, e.g.
#   `ln -s $NVM_DIR/bash_completion nvm` while in the user completion directory

set -euETo pipefail
shopt -s inherit_errexit

# On at least Ubuntu 20.04, `/usr/share/bash-completion/bash_completion` is
# capable of picking up user completions in two different places:
#
# - a directory called `~/.local/share/bash-completion/completions` (or
#   `$XDG_DATA_HOME/bash-completion/completions` if `$XDG_DATA_HOME` is set),
#   with each individual file named after the command needing completion,
#   similar to the system-wide `/usr/share/bash-completion/completions`
# - a file called `~/.bash_completion`
#
# The former is wrapped up in a function called `__load_completion` which does
# lazy loading based on the command being used, so I think that it's the better
# method, whereas `~/.bash_completion` is sourced in its entirety every time.
readonly systemDirectory=/usr/share/bash-completion/completions
readonly userDirectory="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"

if [ ! -d "$systemDirectory" ] ||
  [ "$(find "$systemDirectory" -maxdepth 1 -type f | wc --lines)" -lt 50 ]; then
  echo "system completions do not seem to live in $systemDirectory" >&2
  exit 1
fi
mkdir --parents --verbose "$userDirectory"

installUserCompletion() {
  if command -v "$1" >/dev/null; then
    local systemFile="$systemDirectory/$1"
    local userFile="$userDirectory/$1"

    if [ -e "$systemFile" ]; then
      echo "$1 already provided by system-wide $systemFile"
      if [ -e "$userFile" ]; then
        echo "warning: $systemFile and $userFile both exist" >&2
      fi
    elif [ -L "$userFile" ]; then
      echo "warning: refusing to overwrite $userFile symlink" >&2
    else
      echo "$* >$userFile"
      "$@" >"$userFile"
    fi
  else
    echo "$1 is not installed"
  fi
}

installUserCompletion flutter bash-completion
installUserCompletion gh completion -s bash
installUserCompletion kubectl completion bash
installUserCompletion minikube completion bash
installUserCompletion pip3 completion --bash
