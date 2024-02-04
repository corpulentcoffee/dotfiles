# shellcheck shell=bash
# Aliases here should be kept simple for maintenance purposes and are best
# suited anyway for things that need to effect a change in the current shell
# and/or that will only be used interactively. Most other things probably belong
# as scripts in the bin/ directory.

alias cd-dotfiles='cd "$(whereis-dotfiles)"'

# Like Ubuntu's `ll`, except order directories first.
alias ll='ls -alF --group-directories-first'

# Avoid installing and running random npm packages if a typo or other mistake is
# made. Instead, explicitly use `--install` (e.g. `npx --install -- eslint ...`)
# or `--package=xxx` (e.g. `npx --package=eslint -- eslint ...`) explicitly to
# download and execute a package. Alternatively, `\npx` or `nvm exec npx` can
# also be used to bypass this alias.
#
# As of npm/npx v7, npx will print a "Need to install the following packages"
# prompt before installing anything. npm/npx v7 ship with node v15+, so once
# that is widespread, this alias can likely be eliminated.
alias npx='npx --no-install'

# Avails `xdg-open` as `open` with some added functionality:
# - `open` without any argument tells `xdg-open` to open the current working
#   directory in the default file browser
# - `open` with more than one argument runs `xdg-open` multiple times, once for
#   each argument, to allow opening multiple files (or URLs) simultaneously
function open() {
  local opener=xdg-open

  if [ $# -eq 0 ]; then
    "$opener" .
  else
    local arg
    for arg in "$@"; do
      "$opener" "$arg"
    done
  fi
}

# Open new terminal at given location(s); particularly useful from integrated
# terminals (e.g. Visual Studio Code) to get to a full-sized windowed terminal.
function open-terminal() {
  local arg
  for arg in "$@"; do
    if [[ ! -d "$arg" ]]; then
      echo "usage: ${FUNCNAME[0]} [directory [directory2 ...]]" >&2
      return 1
    fi
  done

  if [[ $# -eq 0 ]]; then (
    x-terminal-emulator &
    disown
  ); else
    for arg in "$@"; do (
      cd "$arg" && x-terminal-emulator &
      disown
    ); done
  fi
}

# Sets (or unsets) and then exports all variations of proxy-related environment
# variables to try to maximize interoperability with different tools; see the
# examples given in <https://unix.stackexchange.com/questions/212894> on why.
#
# `sudo` resets environment variables by default, so if proxy needs to be used
# for `sudo` commands (e.g. for apt package management), then `/etc/sudoers` can
# be modified (via `visudo`) to have an `env_keep` setting, e.g.:
#
#     Defaults env_keep = "http_proxy https_proxy ftp_proxy"
#
# Alternatively, `sudo -E` or `sudo --preserve-env` can accomplish similar.
function set-proxy-environ() {
  if [ $# -gt 2 ]; then
    echo "usage: ${FUNCNAME[0]} [proxy-url [no-proxy-hostname,no-proxy-hostname2,...]]" >&2
    return 1
  fi

  if [ $# -gt 1 ]; then
    export no_proxy="$2"
    export NO_PROXY="$2"
  else
    unset no_proxy NO_PROXY
  fi

  if [ $# -gt 0 ]; then
    export all_proxy="$1"
    export ftp_proxy="$1"
    export http_proxy="$1"
    export https_proxy="$1"
    export rsync_proxy="$1"
    export ALL_PROXY="$1"
    export FTP_PROXY="$1"
    export HTTP_PROXY="$1"
    export HTTPS_PROXY="$1"
    export RSYNC_PROXY="$1"
  else
    unset all_proxy ftp_proxy http_proxy https_proxy rsync_proxy
    unset ALL_PROXY FTP_PROXY HTTP_PROXY HTTPS_PROXY RSYNC_PROXY
  fi
}

# Inspect proxy variables, like those set by `set-proxy-environ`, from various
# sources, with, by default, masking applied to URLs using basic password auth.
alias show-docker-proxy-config='< ~/.docker/config.json sift-proxy-vars'
alias show-docker-proxy-config-unmasked='< ~/.docker/config.json sift-proxy-vars-unmasked'
alias show-docker-proxy-environ='docker run --rm alpine printenv | sift-proxy-vars'
alias show-docker-proxy-environ-unmasked='docker run --rm alpine printenv | sift-proxy-vars-unmasked'
alias show-local-proxy-environ='printenv | sift-proxy-vars'
alias show-local-proxy-environ-unmasked='printenv | sift-proxy-vars-unmasked'
alias sift-proxy-vars="sift-proxy-vars-unmasked | sed --regexp-extended 's/:[^:@]+@/:***@/'"
alias sift-proxy-vars-unmasked="grep --color=never --extended-regexp --ignore-case '\b(all|ftp|https?|no|rsync)_?proxy\b'"

# A standard Ubuntu `~/.bashrc` comes from `/etc/skel/.bashrc`, and will source
# `~/.bash_aliases` if it exists and if the shell is interactive. Because it's
# sourced, technically anything can be included here to affect the initializing
# shell. Under some environments, like GitHub Codespaces, `~/.bashrc` is like
# `/etc/skel/.bashrc`, but has additional stuff at the end (like NVS), so having
# a dotfiles with `.bashrc` is inconvenient. However, these places still source
# `~/.bash_aliases`, so this is an entry point to customize whatever want.
#
# shellcheck source=./home/.bash_behavior
source ~/.bash_behavior
