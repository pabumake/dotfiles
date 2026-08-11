# Pabu's dotfiles

Personal macOS and terminal configuration managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Purpose |
| --- | --- |
| `aerospace` | Omachy-inspired macOS tiling and workspace management |
| `borders` | Supervised Catppuccin Mocha focused-window highlighting |
| `ghostty` | Terminal appearance and host-level shortcuts |
| `herdr` | Terminal workspaces, tabs, panes, and navigation |
| `nvim` | Neovim configuration |
| `starship` | Shell prompt |
| `yazi` | Terminal file management with rich previews |
| `zsh` | Shell configuration and aliases |
| `gh-manager` | GitHub Manager configuration |

Bootstrap offers [Hidden Bar](https://github.com/dwarvesf/hidden),
[Ice](https://github.com/jordanbaird/Ice), or no menu-bar manager. The choice is
remembered locally and can be changed safely with `--switch-bar-manager`. Ice is
the default on supported macOS versions unless another choice is selected.
Provider preferences have tracked first-run baselines and guarded backup helpers;
other applications' icon positions remain device-specific macOS state.

[SwipeAeroSpace](https://github.com/MediosZ/SwipeAeroSpace) provides universal
three-finger horizontal workspace navigation. The native three-finger-up
Mission Control gesture and SwipeAeroSpace's workspace overview are disabled,
so vertical swipes do not display an overlay.

## Quick start

Bootstrap a new Mac or update an existing checkout with the same command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pabumake/dotfiles/main/setup/bootstrap.sh)"
```

The bootstrap always prints its plan. By default it installs only missing
packages, fast-forwards only clean Git checkouts, and asks before backing up any
existing config that conflicts with Stow. Package upgrades require `--upgrade`.
It is the repository's only supported installation and update entry point.
JankyBorders is registered as a per-user Homebrew service so it starts at login
and automatically recovers if its process exits.

Fresh installations use the portable `default` profile. Run bootstrap with
`--profile-personal` to enable the personal AeroSpace app assignments; later
updates remember that choice. Use `--profile-default` to disable them again.

To inspect the script before running it:

```bash
bootstrap_file="$(mktemp /tmp/pabu-dotfiles-bootstrap.XXXXXX)"
curl -fsSL https://raw.githubusercontent.com/pabumake/dotfiles/main/setup/bootstrap.sh -o "$bootstrap_file"
less "$bootstrap_file"
/bin/bash "$bootstrap_file"
```

## Documentation

- [Documentation home](https://pabumake.github.io/dotfiles/)
- [Bootstrap, updates, and Stow usage](https://pabumake.github.io/dotfiles/setup.html)
- [AeroSpace workflow and keybindings](https://pabumake.github.io/dotfiles/aerospace.html)
- [Ghostty and Herdr keybindings](https://pabumake.github.io/dotfiles/terminal.html)
- [Complete dotfiles shortcut overview](https://pabumake.github.io/dotfiles/assets/dotfiles-shortcuts-overview.png)
- Visual shortcut cards: [AeroSpace windows](https://pabumake.github.io/dotfiles/assets/aerospace-windows-shortcuts.png),
  [AeroSpace workspaces](https://pabumake.github.io/dotfiles/assets/aerospace-workspaces-shortcuts.png),
  [Herdr terminal](https://pabumake.github.io/dotfiles/assets/herdr-terminal-shortcuts.png), and
  [Yazi file manager](https://pabumake.github.io/dotfiles/assets/yazi-shortcuts.png)
- [Shortcut-card SVG template and regeneration](docs/assets/shortcut-cards/README.md)
- [Menu-bar icon management](https://pabumake.github.io/dotfiles/menubar.html)

The longer guides live in `/docs` so this README stays useful as a quick entry
point. GitHub Pages publishes the site from `main` and `/docs`.

## Thanks

This setup is built on excellent open-source work. Thank you to the maintainers
and contributors of the projects directly installed, configured, or used as
inspiration here:

- **Desktop and workflow:** [AeroSpace](https://github.com/nikitabobko/AeroSpace),
  [JankyBorders](https://github.com/FelixKratz/JankyBorders),
  [Ghostty](https://github.com/ghostty-org/ghostty),
  [Herdr](https://github.com/herdrdev/herdr),
  [SwipeAeroSpace](https://github.com/MediosZ/SwipeAeroSpace),
  [Ice](https://github.com/jordanbaird/Ice), and
  [Hidden Bar](https://github.com/dwarvesf/hidden)
- **Shell and editor:** [Zsh](https://github.com/zsh-users/zsh),
  [Starship](https://github.com/starship/starship),
  [Yazi](https://github.com/sxyazi/yazi),
  [Neovim](https://github.com/neovim/neovim),
  [LazyVim](https://github.com/LazyVim/LazyVim),
  [lazy.nvim](https://github.com/folke/lazy.nvim), and
  [gh-manager](https://github.com/pabumake/gh-manager)
- **Command-line tooling:** [Git](https://github.com/git/git),
  [eza](https://github.com/eza-community/eza),
  [ripgrep](https://github.com/BurntSushi/ripgrep),
  [fd](https://github.com/sharkdp/fd), [fzf](https://github.com/junegunn/fzf),
  [lazygit](https://github.com/jesseduffield/lazygit),
  [Tree-sitter](https://github.com/tree-sitter/tree-sitter), and
  [Node.js](https://github.com/nodejs/node)
- **Foundations and design:** [Homebrew](https://github.com/Homebrew/brew),
  [GNU Stow](https://github.com/aspiers/stow),
  [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts),
  [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono), and
  [Catppuccin](https://github.com/catppuccin/catppuccin)
- **Inspiration and documentation:** [Omachy](https://github.com/dough654/omachy),
  [Jekyll](https://github.com/jekyll/jekyll), and the
  [Minimal theme](https://github.com/pages-themes/minimal)

The Neovim lockfile contains the complete pinned plugin list; those projects and
their contributors are appreciated as well.
