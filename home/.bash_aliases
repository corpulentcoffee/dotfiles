# A standard Ubuntu ~/.bashrc will source this file if it exists. Because it's
# sourced, technically anything could go here to affect the initializing shell.
#
# shellcheck shell=bash
#
# Aliases here should be kept simple for maintenance purposes and are best
# suited anyway for things that need to effect a change in the current shell
# and/or that will only be used interactively. Most other things probably belong
# as scripts in the bin/ directory.

alias cd-dotfiles='cd "$(whereis-dotfiles)"'

# Avails `xdg-open` as `open` with some added functionality:
# - `open` without any argument tells `xdg-open` to open the current working
#   directory in the default file browser
# - `open` with more than one argument runs `xdg-open` multiple times, once for
#   each argument, to allow opening multiple files (or URLs) simultaneously
function open() {
  if [ $# -eq 0 ]; then
    xdg-open .
  else
    for arg in "$@"; do
      xdg-open "$arg"
    done
  fi
}

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

# Sets (or unsets) and then exports all variations of proxy-related environment
# variables to try to maximize interoperability with different tools; see the
# examples given in <https://unix.stackexchange.com/questions/212894> on why.
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
