# Personal dotfiles

## Usage notes

- [`home/`](home) contains files to be installed into the user home directory,
  keeping those files separate from things needed to maintain and use the
  repository; thus, [`.vscode/`](.vscode) contains Visual Studio Code
  configuration pertinent to maintaining this repository and does _not_ contain
  files to be installed into `~/.config/Code/User/`
- [`install.sh`](install.sh) creates destination directories and then symlinks
  files _individually_, rather than symlink entire directories, allowing finer
  control over which files are kept in version control

## References

- [GitHub does dotfiles](https://dotfiles.github.io/) has various tips for
  maintaining `dotfiles` repositories on GitHub
- [Personalizing Codespaces for your account](https://docs.github.com/github/developing-online-with-codespaces/personalizing-codespaces-for-your-account)
  explains how GitHub handles `dotfiles` repositories
