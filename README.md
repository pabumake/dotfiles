# Pabu's dotfiles

Personal macOS and terminal configuration managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Purpose |
| --- | --- |
| `aerospace` | Omachy-inspired macOS tiling and workspace management |
| `ghostty` | Terminal appearance and host-level shortcuts |
| `herdr` | Terminal workspaces, tabs, panes, and navigation |
| `nvim` | Neovim configuration |
| `starship` | Shell prompt |
| `zsh` | Shell configuration and aliases |
| `gh-manager` | GitHub Manager configuration |

## Quick start

Bootstrap a new Mac or update an existing checkout with the same command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pabumake/dotfiles/main/setup/bootstrap.sh)"
```

The bootstrap always prints its plan. By default it installs only missing
packages, fast-forwards only clean Git checkouts, and asks before backing up any
existing config that conflicts with Stow. Package upgrades require `--upgrade`.

To inspect the script before running it:

```bash
bootstrap_file="$(mktemp /tmp/pabu-dotfiles-bootstrap.XXXXXX)"
curl -fsSL https://raw.githubusercontent.com/pabumake/dotfiles/main/setup/bootstrap.sh -o "$bootstrap_file"
less "$bootstrap_file"
/bin/bash "$bootstrap_file"
```

## Documentation

- [Bootstrap, updates, and Stow usage](docs/setup.md)
- [AeroSpace workflow and keybindings](docs/aerospace.md)
- [Ghostty and Herdr keybindings](docs/terminal.md)
- [GitHub Pages documentation site](https://pabumake.github.io/dotfiles/)

The longer guides live in `/docs` so this README stays useful as a quick entry
point. The site is prepared for publishing from `main` and `/docs`.
