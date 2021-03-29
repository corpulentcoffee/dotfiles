# A standard Ubuntu ~/.bashrc will source this file if it exists. Because it's
# sourced, technically anything could go here to affect the initializing shell.
# Running `shellcheck --shell bash` on this file can check its syntax.
#
# Aliases here should be kept simple for maintenance purposes and are best
# suited anyway for things that need to effect a change in the current shell and
# will be used interactively. Most other things probably belong as scripts in
# the bin/ directory.

alias cd-dotfiles='cd "$(whereis-dotfiles)"'
