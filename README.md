# Personal dotfiles

## Usage notes

- [`home/`](home) contains files to be installed into the user home directory,
  keeping those files separate from things needed to maintain and use the
  repository; thus, [`.vscode/`](.vscode) contains Visual Studio Code
  configuration pertinent to maintaining this repository and does _not_ contain
  files to be installed into `~/.config/Code/User/`
- [`install.sh`](install.sh) sets up the home directory
  - rather than symlink entire directories, individual files are symlinked after
    creating their directories, allowing finer control over which files are kept
    in version control
  - for better ergonomics, [`bin` scripts](home/bin) are symlinked without their
    extension; additionally, Python scripts are symlinked in kebab case (which
    is easier to type) rather than the in-repoistory snake case (which is
    `import`able)
- some items assume the presence of other things (e.g. a script might assume
  that certain `.gitconfig` aliases are configured or that another script can be
  called using its installed name), so partial installs might not work without
  also handling dependencies

## References

- [Awesome dotfiles](https://github.com/webpro/awesome-dotfiles) and
  [GitHub does dotfiles](https://dotfiles.github.io/) have various tips for
  `dotfiles` repositories, like alternatives to a bespoke
  [`install.sh`](install.sh)
- [Personalizing Codespaces for your account](https://docs.github.com/github/developing-online-with-codespaces/personalizing-codespaces-for-your-account)
  explains how GitHub handles `dotfiles` repositories
