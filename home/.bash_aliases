# A standard Ubuntu ~/.bashrc will source this file if it exists. Because it's
# sourced, technically anything could go here to affect the initializing shell.
# Running `shellcheck --shell bash` on this file can check its syntax.
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
