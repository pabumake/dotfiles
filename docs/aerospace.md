---
layout: default
title: AeroSpace
---

# AeroSpace workflow and keybinding cheat sheet


The AeroSpace config uses numbered workspaces, Vim-style navigation, and fixed
8px gaps. AeroSpace starts JankyBorders for focused-window highlighting. It
does not start SketchyBar, dynamic gap scripts, or tmux.

The `alt` modifier in the AeroSpace config is the macOS **Option (⌥)** key.
Every modifier is written explicitly below; there is no implied `Mod` key.

### Main mode: focus and window movement

| Shortcut | Action |
| --- | --- |
| `Option (⌥) + H` | Focus the window to the left |
| `Option (⌥) + J` | Focus the window below |
| `Option (⌥) + K` | Focus the window above |
| `Option (⌥) + L` | Focus the window to the right |
| `Option (⌥) + Shift (⇧) + H` | Move the focused window left |
| `Option (⌥) + Shift (⇧) + J` | Move the focused window down |
| `Option (⌥) + Shift (⇧) + K` | Move the focused window up |
| `Option (⌥) + Shift (⇧) + L` | Move the focused window right |
| `Option (⌥) + -` | Shrink the focused window by 50 pixels |
| `Option (⌥) + =` | Grow the focused window by 50 pixels |

### Main mode: layouts and windows

| Shortcut | Action |
| --- | --- |
| `Option (⌥) + /` | Cycle tiled layout orientation |
| `Option (⌥) + ,` | Cycle accordion layout orientation |
| `Option (⌥) + Shift (⇧) + Space` | Toggle floating/tiling |
| `Option (⌥) + F` | Toggle native macOS fullscreen |
| `Option (⌥) + Q` | Close the focused window |
| `Option (⌥) + Enter (↩)` | Open Ghostty and start or attach Herdr |
| `Command (⌘) + H` | Disabled to prevent accidental application hiding |
| `Command (⌘) + Option (⌥) + H` | Disabled to prevent hiding other applications |

### Main mode: workspaces and monitors

| Shortcut | Action |
| --- | --- |
| `Option (⌥) + 1–9` | Switch to workspace 1–9 |
| `Option (⌥) + Shift (⇧) + 1–9` | Move the focused window to workspace 1–9 |
| `Option (⌥) + Tab (⇥)` | Switch to the previous workspace |
| `Option (⌥) + Shift (⇧) + Tab (⇥)` | Move the current workspace to the next monitor |

### Resize mode

Enter resize mode with `Option (⌥) + R`. Keys within this mode do not use a
modifier unless one is shown.

| Shortcut | Action |
| --- | --- |
| `H` | Reduce width by 50 pixels |
| `J` | Increase height by 50 pixels |
| `K` | Reduce height by 50 pixels |
| `L` | Increase width by 50 pixels |
| `-` | Smart resize down by 50 pixels |
| `=` | Smart resize up by 50 pixels |
| `Enter (↩)` or `Escape (Esc)` | Return to main mode |

### Service mode

Enter service mode with `Option (⌥) + Shift (⇧) + Semicolon (;)`. Every listed
action automatically returns to main mode.

| Shortcut | Action |
| --- | --- |
| `Escape (Esc)` | Reload the AeroSpace config and return to main mode |
| `R` | Flatten/reset the current workspace tree |
| `F` | Toggle floating/tiling |
| `Backspace (⌫)` | Close every window in the workspace except the focused one |
| `Option (⌥) + Shift (⇧) + H` | Join with the container to the left |
| `Option (⌥) + Shift (⇧) + J` | Join with the container below |
| `Option (⌥) + Shift (⇧) + K` | Join with the container above |
| `Option (⌥) + Shift (⇧) + L` | Join with the container to the right |

### Focused-window highlighting

[JankyBorders](https://github.com/FelixKratz/JankyBorders) draws a rounded,
4-point Catppuccin Mocha Blue border around only the focused window. The blue
uses 80% opacity (`0xcc89b4fa`); inactive borders are transparent. Retina
rendering remains enabled, and no glow effect is used.

AeroSpace starts `borders` at login. Its appearance is managed from
`~/.config/borders/bordersrc`. To apply appearance changes without restarting
AeroSpace:

```bash
~/.config/borders/bordersrc
```

JankyBorders is not a Homebrew service and does not require Accessibility
permission. If it is not running, restart AeroSpace or run `borders`.

### Validate and reload

```bash
aerospace reload-config --dry-run --warnings-as-errors
aerospace reload-config
```

### Remove focused-window highlighting

The checkpoint tag `aerospace-pre-jankyborders-20260810` marks the repository
before JankyBorders was added. To stop highlighting without changing the
repository:

```bash
pkill borders
cd ~/Documents/dotfiles
stow --delete --target="$HOME" borders
```

To prepare a complete repository rollback, restore the changed managed files
from the checkpoint, remove the new Stow package, and optionally uninstall the
formula:

```bash
cd ~/Documents/dotfiles
git restore --source=aerospace-pre-jankyborders-20260810 -- \
  Brewfile README.md aerospace/.aerospace.toml setup/bootstrap.sh \
  docs/aerospace.md docs/index.md docs/setup.md
git rm -r borders
brew uninstall borders
```

Only run `brew untap FelixKratz/formulae` if no other installed formula uses
that tap.

### Restore the pre-Omachy configuration

The repository checkpoint `aerospace-pre-omachy-20260810` contains the exact
known-good configuration from before the Omachy-inspired workflow was added.

```bash
cd ~/Documents/dotfiles
git restore --source=aerospace-pre-omachy-20260810 -- aerospace/.aerospace.toml
aerospace reload-config --dry-run --warnings-as-errors
aerospace reload-config
```

To recover the current committed config after rehearsing a restore:

```bash
git restore aerospace/.aerospace.toml
aerospace reload-config --dry-run --warnings-as-errors
aerospace reload-config
```
