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

```bash
cd ~/Documents/dotfiles
stow --target="$HOME" aerospace ghostty herdr starship zsh
```

Preview changes before linking a package:

```bash
stow --simulate --verbose --target="$HOME" herdr
```

## Documentation

- [Setup and Stow usage](docs/setup.md)
- [AeroSpace workflow and keybindings](docs/aerospace.md)
- [Ghostty and Herdr keybindings](docs/terminal.md)
- [GitHub Pages documentation site](https://pabumake.github.io/dotfiles/)

The longer guides live in `/docs` so this README stays useful as a quick entry
point. The site is prepared for publishing from `main` and `/docs`.
