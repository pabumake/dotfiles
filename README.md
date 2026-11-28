# Pabu's dotfiles

Personal macOS and Omarchy configuration managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Stow package | Platform | Purpose |
| --- | --- | --- |
| `aerospace` | macOS | Omachy-inspired tiling and workspace management |
| `borders` | macOS | Supervised Catppuccin Mocha focused-window highlighting |
| `ghostty` | macOS | Terminal appearance and host-level shortcuts |
| `zsh` | macOS | Shell configuration and aliases |
| `herdr` | Both | Terminal workspaces, tabs, panes, and navigation |
| `nvim` | Both | Neovim configuration |
| `starship` | Both | Shell prompt |
| `yazi` | Both | Terminal file management with rich previews |
| `gh-manager` | Both | GitHub Manager configuration; binary installed separately |
| `omarchy-bash` | Omarchy | Bash overlay loaded after Omarchy defaults |
| `omarchy-desktop` | Omarchy | Hyprland bindings, monitors, keyboard layout, and shell plugins |
| `omarchy-handy` | Omarchy | Handy dictation adapters and startup configuration |

The bootstraps select the packages for their platform. Omarchy keeps its own
Ghostty configuration. The legacy `bash/.bashrc` is not installed by either
bootstrap. Menu-bar preferences and the optional Input Remapper preset use
separate helpers rather than Stow.

On macOS, bootstrap offers [Hidden Bar](https://github.com/dwarvesf/hidden),
[Thaw](https://github.com/thaw-app/Thaw), or no menu-bar manager. The choice is
remembered locally and can be changed safely with `--switch-bar-manager`. Thaw is
the default on supported macOS versions unless another choice is selected.
Provider preferences have tracked first-run baselines and guarded backup helpers;
other applications' icon positions remain device-specific macOS state.

[SwipeAeroSpace](https://github.com/MediosZ/SwipeAeroSpace) provides universal
three-finger horizontal workspace navigation. The native three-finger-up
Mission Control gesture and SwipeAeroSpace's workspace overview are disabled,
so vertical swipes do not display an overlay.

## Quick start

### macOS

Bootstrap a new Mac or update an existing checkout with the same command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pabumake/dotfiles/main/setup/bootstrap.sh)"
```

The bootstrap always prints its plan. By default it installs only missing
packages, fast-forwards only clean Git checkouts, and asks before backing up any
existing config that conflicts with Stow. Package upgrades require `--upgrade`.
It requires macOS 15.6 or newer and is the macOS installation and update entry point.
JankyBorders is registered as a per-user Homebrew service so it starts at login
and automatically recovers if its process exits.
Bootstrap also installs the native ZMK Studio app for keyboard configuration.
For a standalone install, run `./scripts/install-zmk-studio.sh`.

From an existing checkout, preview or apply without updating the repository:

```bash
cd ~/src/dotfiles
./setup/bootstrap.sh --dry-run --no-repo-update
./setup/bootstrap.sh --no-repo-update
```

Both bootstraps remove an installed Cliamp on the next run. To try optional
macOS apps, including Kagi's Orion browser, run from the checkout:

```bash
./setup/bootstrap.sh --include-trials
```

Trials live in `Brewfile.trials`, separate from the standard `Brewfile`.
The flag applies to that run only. Later runs without it leave trial apps installed.

When OpenCode or Hermes is installed, the macOS bootstrap also runs the
[shared skills setup](docs/setup.md#agent-skills). It reuses an existing skills
checkout or clones `pabumake/skills` to `~/src/skills`.

To inspect the script before running it:

```bash
bootstrap_file="$(mktemp /tmp/pabu-dotfiles-bootstrap.XXXXXX)"
curl -fsSL https://raw.githubusercontent.com/pabumake/dotfiles/main/setup/bootstrap.sh -o "$bootstrap_file"
less "$bootstrap_file"
/bin/bash "$bootstrap_file"
```

### Omarchy

For an existing Omarchy installation, run from this checkout:

```bash
./setup/bootstrap-omarchy.sh --dry-run
./setup/bootstrap-omarchy.sh
# Optional Steam, Input Remapper, and WowUp-CF setup:
./setup/bootstrap-omarchy.sh --gaming
```

The default setup installs Keeper, Zen, Ghostty, and Handy, and manages the
dock, keybindings, monitors, and US International keyboard layout. Gaming is
opt-in on each run. The [Orbweaver MMO preset](input-remapper/README.md) is
copied and applied separately; bootstrap preserves local presets.

The [Omarchy bootstrap guide](docs/omarchy.md) covers shared terminal configs,
application defaults, dictation, gaming, desktop editing, Bash integration, and
backups. Omarchy accepts `--include-trials`, but its trial package lists are
currently empty; Orion is a macOS trial.

## Documentation

- [Windows setup proposal and tool coverage](docs/research/windows-tool-coverage.md), research on the Windows feature branch; no Windows bootstrap is available yet.
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
- [Code archive offload](https://pabumake.github.io/dotfiles/migrate-stale-projects.html)

The longer guides live in `/docs` so this README stays useful as a quick entry
point. Configure GitHub Pages to publish from `main` and `/docs` as described
in the [setup guide](docs/setup.md#enable-github-pages).

## Validation

Run the bootstrap tests from the repository root:

```bash
python3 -m unittest discover -s setup -p 'test_*.py'
```

Tests use temporary directories and stubbed package managers. GNU Stow is
required for the Omarchy integration tests; the MIME association test also
requires `xdg-mime`. Missing tools cause those tests to be skipped. The tests
do not install applications or change live desktop preferences.

## Thanks

This setup is built on excellent open-source work. Thank you to the maintainers
and contributors of the projects directly installed, configured, or used as
inspiration here:

- **Desktop and workflow:** [AeroSpace](https://github.com/nikitabobko/AeroSpace),
  [JankyBorders](https://github.com/FelixKratz/JankyBorders),
  [Ghostty](https://github.com/ghostty-org/ghostty),
  [Herdr](https://github.com/herdrdev/herdr),
  [Vorssaint](https://github.com/vorssaintapp/vorssaint-utils),
  [SwipeAeroSpace](https://github.com/MediosZ/SwipeAeroSpace),
  [Thaw](https://github.com/thaw-app/Thaw), and
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
  [rsync](https://rsync.samba.org/),
  [Mole](https://github.com/tw93/Mole),
  [Tree-sitter](https://github.com/tree-sitter/tree-sitter), and
  [Node.js](https://github.com/nodejs/node)
- **Foundations and design:** [Homebrew](https://github.com/Homebrew/brew),
  [GNU Stow](https://github.com/aspiers/stow),
  [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts),
  [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono), and
  [Catppuccin](https://github.com/catppuccin/catppuccin)
- **Inspiration and documentation:** [Omachy](https://github.com/dough654/omachy),
  [Jekyll](https://github.com/jekyll/jekyll), and the
  [Hacker theme](https://github.com/pages-themes/hacker)

The Neovim lockfile contains the complete pinned plugin list; those projects and
their contributors are appreciated as well.
