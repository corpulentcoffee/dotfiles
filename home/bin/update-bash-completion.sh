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
# Note that some user-installed tools come with pre-baked bash completion files
# with their packaging or code but might not correctly install themselves; these
# can just be symlinked while in the user completion directory, e.g.:
#
# - `ln -s $NVM_DIR/bash_completion nvm` for the Node Version Manager
# - `ln -s ~/.local/etc/bash_completion.d/xxx.bash-completion xxx` for some
#   pip-packaged `--user` installed CLI tools

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

      local completionContent
      if completionContent=$("$@") && [ -n "$completionContent" ]; then
        echo "$completionContent" >"$userFile"
      else
        echo "  ... that didn't work; not writing to $userFile" >&2
      fi
    fi
  else
    echo "$1 is not installed"
  fi
}

# Presenting certain environ variables can dissuade some tools (e.g. Flutter)
# from doing unwanted things (e.g. upgrade checks) while generating completion
# output.
export CI=true

installUserCompletion aws bash-completion # ../.aws/cli/alias avails this
installUserCompletion flutter bash-completion --no-version-check
installUserCompletion gh completion -s bash
installUserCompletion kubectl completion bash
installUserCompletion minikube completion bash

(
  if [ -n "${NVM_DIR:-}" ]; then # use completions from latest Node.js LTS
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh" # nvm available until end of subshell
    set +u
    nvm use --lts || nvm install --lts # environ altered until end of subshell
    set -u
  fi
  installUserCompletion node --completion-bash
  installUserCompletion npm completion
)

installUserCompletion pip3 completion --bash
