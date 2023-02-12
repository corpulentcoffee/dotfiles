# Personal dotfiles

_Everything here is provided "as is" [under an MIT license](LICENSE), without
warranty of any kind._

## Usage notes

- assumes a GNU/Linux-style userland
- [`home/`](home) contains files to be installed into the user home directory,
  separating them from things needed to maintain the repository, e.g. for Visual
  Studio Code configuration:
  - [`home/.config/Code/User/`](home/.config/Code/User) contains the files to
    install into `~/.config/Code/User/`
  - [`.vscode/`](.vscode) contains files specific to working in the `dotfiles`
    repository workspace
- [`install.sh`](install.sh) sets up the home directory
  - rather than symlink entire directories, individual files are symlinked after
    creating their directories, allowing finer control over which files are kept
    in version control
  - for better ergonomics, [`bin` scripts](home/bin) are symlinked without their
    extension; additionally, Python scripts are symlinked in kebab case (which
    is easier to type) rather than the in-repository snake case (which is
    `import`able)
- many environments ship their own `~/.bashrc` with environment-specific items
  and interoperability with those setups is done by not including `home/.bashrc`
  here but rather relying on the fact that most `~/.bashrc` files will source
  `~/.bash_aliases` if it exists, which _is_ included here; the `install.sh`
  setup script can make minor tweaks to environment-provided `~/.bashrc` files
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
