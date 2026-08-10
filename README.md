# Pabu's dotfiles

This is a work in progress.

## Understanding the Stow layout

```bash
dotfile location -------------------> GNU Stow package

Each package repeats the path that should be created below the target directory.

~/.config/nvim     -----------------> nvim/.config/nvim
~/.config/ghostty  -----------------> ghostty/.config/ghostty
~/.aerospace.toml  -----------------> aerospace/.aerospace.toml
```

## Moving an existing config into a package

```bash
mv ~/.config/nvim ~/Documents/dotfiles/nvim/.config/nvim
```

## Enable Stow linking

Run Stow from the repository root and explicitly target the home directory:

```bash
cd ~/Documents/dotfiles
stow --target="$HOME" nvim
stow --target="$HOME" aerospace
```

Restart or reload the relevant application after linking its configuration.

## Remove Stow links

```bash
cd ~/Documents/dotfiles
stow --delete --target="$HOME" aerospace
```

The package files remain in the repository; only the generated links are removed.

## Restoring on a new device

```bash
cd ~/Documents/dotfiles
stow --target="$HOME" starship
stow --target="$HOME" aerospace
```

## AeroSpace workflow

The AeroSpace config uses numbered workspaces, Vim-style navigation, and fixed
8px gaps. It does not start SketchyBar, borders, dynamic gap scripts, or tmux.

| Shortcut | Action |
| --- | --- |
| `Alt+H/J/K/L` | Focus left/down/up/right |
| `Alt+Shift+H/J/K/L` | Move the focused window |
| `Alt+1–9` | Switch workspace |
| `Alt+Shift+1–9` | Move the focused window to a workspace |
| `Alt+Shift+Space` | Toggle floating/tiling |
| `Alt+F` | Toggle native fullscreen |
| `Alt+Q` | Close the focused window |
| `Alt+Enter` | Open Ghostty and start or attach Herdr |
| `Alt+R` | Enter resize mode; exit with `Enter` or `Esc` |
| `Alt+Shift+;` | Enter service mode |

### Validate and reload

```bash
aerospace reload-config --dry-run --warnings-as-errors
aerospace reload-config
```

### Restore the pre-Omachy configuration

The exact known-good configuration is stored in
`backups/aerospace/pre-omachy-20260810.toml` and the full repository checkpoint
is tagged `aerospace-pre-omachy-20260810`.

```bash
cd ~/Documents/dotfiles
cp backups/aerospace/pre-omachy-20260810.toml aerospace/.aerospace.toml
aerospace reload-config --dry-run --warnings-as-errors
aerospace reload-config
```

To recover the current committed config after rehearsing a restore:

```bash
git restore aerospace/.aerospace.toml
aerospace reload-config --dry-run --warnings-as-errors
aerospace reload-config
```
