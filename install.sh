#!/usr/bin/env bash

set -euETo pipefail
shopt -s inherit_errexit
cd "$(dirname "${BASH_SOURCE[0]}")/home"

if [[ ! "$HOME" =~ ^/ ]]; then
  # HOME needs to be absolute given that we just changed directories above.
  echo 'HOME must be set and must be using an absolute path.' >&2
  exit 1
elif [ "$(git rev-parse --is-inside-work-tree)" != 'true' ]; then
  # We need git to be present and working for `git ls-tree`.
  echo 'git must be installed and repository data must be present.' >&2
  exit 1
fi

okayCount=0
failCount=0
copyCount=0
linkCount=0

while IFS='' read -rd '' srcPath; do
  dstPath="$srcPath"                         # symlink most files at same path
  if [[ "$srcPath" == "bin/"* ]]; then       # except bin files are special
    if [[ "$srcPath" == "bin/lib/"* ]]; then # do not symlink common bin modules
      continue
    elif [[ "$srcPath" == "bin/"?*.?* ]]; then # make scripts easier to type
      dstPath="${srcPath%.*}"                  # strip file extension
      dstPath="${dstPath//_/-}"                # switch snake case to kebab case
    else
      echo "unexpected non-script file in bin directory" >&2
      exit 1
    fi
  fi
  dstPath="$HOME/$dstPath"

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
    echo -n "cp "
    cp --verbose "$dstPath" "$srcPath"
    ln --force --relative --symbolic --verbose "$srcPath" "$dstPath"
  else
    ((++linkCount))
    mkdir --parents --verbose "$(dirname "$dstPath")"
    ln --relative --symbolic --verbose "$srcPath" "$dstPath"
  fi
done < <(git ls-tree -rz --name-only HEAD) # only use committed files
echo

if [ "${CODESPACES-false}" == "true" ]; then
  # GitHub Codespaces is still in preview. These tweaks worked and these notes
  # were accurate as of March 2021, but things can still change...
  echo 'Codespaces-specific adjustments:'

  # Today's stock .gitconfig on Codespaces (verified by this md5sum check) just
  # contains a core.editor setting I don't need, so use my .gitconfig instead.
  if [ "$(md5sum <.gitconfig)" == "43ba1caca81a816ae18ac0857ad83b53  -" ]; then
    echo '- discarding Codespaces-provided .gitconfig for dotfiles-provided one'
    git checkout .gitconfig
  fi

  # Visual Studio Code in Codespaces collects its settings from three "scopes":
  #
  # 1. a "/User/settings.json" key stored via the browser's IndexedDB API that
  #    can optionally be synced using Settings Sync, which may be pointing at
  #    either the "VS Code Stable" or "Insiders" servers depending on the setup;
  # 2. a "machine"/"remote" `~/.vscode-remote/data/Machine/settings.json`, which
  #    is actually intended to be used with an in-repo `devcontainer.json`; and
  # 3. the in-repo `.vscode/settings.json`, if any.
  #
  # The desktop-standard `~/.config/Code/User/settings.json` from the dotfiles
  # is not "currently" used.
  #
  # Alternatively, Settings Sync (which itself is still in preview) could be
  # used for these settings, probably still keeping them version-controlled here
  # via regular desktop machines that don't use the IndexedDB API for storage.
  readonly codespacesSettings=~/.vscode-remote/data/Machine
  readonly dotfilesSettings=.config/Code/User
  if [ -d "$codespacesSettings" ] && [ ! -L "$codespacesSettings" ]; then
    if [ -e "$codespacesSettings/settings.json" ]; then
      if [ -f "$codespacesSettings/settings.json" ] &&
        [ ! -L "$codespacesSettings/settings.json" ]; then
        # "machine"/"remote" settings already exist, so merge dotfiles version
        # with the Codespaces version, preferring settings from the latter; this
        # method can propagate dotfiles settings additions, but requires manual
        # intervention to propagate settings *changes*, since the original value
        # will be in the "machine"/"remote" settings file and thus will persist
        echo "- merging machine and dotfiles settings"
        jq --slurp add \
          <(npx --package relaxed-json -- rjson "$dotfilesSettings/settings.json") \
          <(npx --package relaxed-json -- rjson "$codespacesSettings/settings.json") |
          sponge "$codespacesSettings/settings.json"
      fi
    else
      # "machine"/"remote" settings don't already exist, so symlink can just be
      # created from "machine"/"remote" settings location to dotfiles version
      echo -n "- linking machine settings to dotfiles: "
      ln --relative --symbolic --verbose \
        "$dotfilesSettings/settings.json" "$codespacesSettings/settings.json"
    fi
  fi

  # Likewise, Visual Studio Code in Codespaces doesn't read the desktop-standard
  # `~/.config/Code/User/keybindings.json`. Further, it only uses the IndexedDB
  # storage for these, so there's no on-disk location to symlink.
  #
  # Again, using Settings Sync could probably be used for these. When using
  # Settings Sync, keybindings are synchronized by platform by default, but I'm
  # not sure if "web browser on Linux" counts as "linux" or as "web". If keeping
  # to platforms like Linux and Windows, keybindings should be platform-agnostic
  # and the `settingsSync.keybindingsPerPlatform` setting could be disabled.
  # Alternatively, even without fully enabling Settings Sync across all devices,
  # Settings Sync can be enabled just in the Codespaces environment, effectively
  # creating a "'web-platform' keybindings" file.
  echo '- Visual Studio Code keybindings.json cannot be setup here'

  # ~/.profile on Ubuntu will usually handle this, but because Codespaces are
  # durable and ~/bin doesn't exist when the container is setup, there is never
  # an opportunity for ~/.profile to run again. In lieu of ~/.profile, this is
  # the best way to get ~/bin in the PATH that I can think of right now.
  # shellcheck disable=SC2016  # use unexpanded $HOME literally in strings below
  if [[ ! ":$PATH:" == *":$HOME/bin:"* ]] &&
    ! grep --fixed-strings --quiet '$HOME/bin:$PATH' ~/.bashrc; then
    echo '- modifying .bashrc to include ~/bin in the user PATH'
    echo 'PATH="$HOME/bin:$PATH"' >>~/.bashrc
  fi

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
