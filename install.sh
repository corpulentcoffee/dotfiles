#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit
cd "$(dirname "${BASH_SOURCE[0]}")/home"

if [[ ! "$HOME" =~ ^/ ]]; then
  # HOME needs to be absolute given that we just changed directories above.
  echo 'HOME must be set and must be using an absolute path.' >&2
  exit 1
elif [ "$(git rev-parse --is-inside-work-tree)" != 'true' ]; then
  # We need git to be present and working for `git check-ignore` path checks.
  echo 'git must be installed and repository data must be present.' >&2
  exit 1
fi

okayCount=0
failCount=0
copyCount=0
linkCount=0

while IFS='' read -rd '' srcPath; do
  if git check-ignore "$srcPath" >/dev/null; then
    continue
  fi

  # Install Python and shell script bin files without suffix, and switch Python
  # scripts from importable snake case to ergonomic kebab case.
  if [[ "$srcPath" =~ ^\./bin/[a-z0-9_-]+\.(py|sh)$ ]]; then
    dstPath="${srcPath%.*}"
    if [[ "$srcPath" =~ \.py$ ]]; then
      dstPath="${dstPath//_/-}"
    fi
  else
    dstPath="$srcPath"
  fi
  dstPath="$HOME/${dstPath#./}"

  if [ -L "$dstPath" ]; then
    srcReal="$(realpath "$srcPath")"
    dstLink="$(readlink --canonicalize "$dstPath")"

    if [ "$srcReal" == "$dstLink" ]; then
      ((++okayCount))
    else
      ((++failCount))
      echo "$srcPath: $dstPath already linked to $dstLink instead of $srcReal"
    fi
  elif [ -f "$dstPath" ]; then
    ((++copyCount))
    echo "$srcPath: $dstPath already exists; use version control to reconcile"
    cp --verbose "$dstPath" "$srcPath"
    ln --force --relative --symbolic --verbose "$srcPath" "$dstPath"
  else
    ((++linkCount))
    mkdir --parents --verbose "$(dirname "$dstPath")"
    ln --relative --symbolic --verbose "$srcPath" "$dstPath"
  fi
done < <(find . -path ./bin/lib -prune -o -type f -print0)
echo

if [ "${CODESPACES-false}" == "true" ]; then
  # GitHub Codespaces is still in preview. These tweaks work as of March 2021,
  # but things can still change...
  echo 'Making Codespaces-specific adjustments...'

  # Today's stock .gitconfig on Codespaces (verified by this md5sum check) just
  # contains a core.editor setting I don't need, so use my .gitconfig instead.
  if [ "$(md5sum <.gitconfig)" == "43ba1caca81a816ae18ac0857ad83b53  -" ]; then
    git checkout .gitconfig
  fi

  # Visual Studio Code in Codespaces uses Settings Sync, a "machine"/"remote"
  # `settings.json`, and in-repo `.vscode/settings.json`. It does NOT read from
  # the desktop-standard `~/.config/Code/User/settings.json`. Because the
  # "machine"/"remote" one doesn't exist initially, it can just be replaced with
  # a symlink to the dotfiles version. ALTERNATIVELY, Settings Sync could be
  # used for these settings, possibly(?) still keeping them version-controlled.
  readonly codespacesSettings=~/.vscode-remote/data/Machine
  if [ -d "$codespacesSettings" ] && [ ! -L "$codespacesSettings" ] &&
    [ ! -e "$codespacesSettings/settings.json" ]; then
    ln --relative --symbolic --verbose \
      .config/Code/User/settings.json "$codespacesSettings/settings.json"
  fi

  # ~/.profile on Ubuntu will usually handle this, but because Codespaces are
  # durable and ~/bin doesn't exist when the container is setup, there is never
  # an opportunity for ~/.profile to run again. In lieu of ~/.profile, this is
  # the best way to get ~/bin in the PATH that I can think of right now.
  # shellcheck disable=SC2016  # use unexpanded $HOME literally in strings below
  if [[ ! ":$PATH:" == *":$HOME/bin:"* ]] &&
    ! grep --fixed-strings --quiet '$HOME/bin:$PATH' ~/.bashrc; then
    echo 'Modifying .bashrc to include ~/bin in the user PATH...'
    echo 'PATH="$HOME/bin:$PATH"' >>~/.bashrc
  fi

  echo '...done'
  echo
fi

cat <<EOF
Summary
- already installed: $okayCount
- failed to install: $failCount
- needs reconciling: $copyCount
- cleanly installed: $linkCount

Hints
- if this is a new/newish install, a logout/login cycle might be helpful
  (e.g. for ~/.profile to see ~/bin and add it to the PATH)
- you can run update-bash-completion for common tools that might be installed
- you can run ./test.sh as a sanity check of the installation
EOF
