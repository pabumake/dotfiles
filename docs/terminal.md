---
layout: default
title: Ghostty and Herdr
---

# Ghostty and Herdr

Herdr is the primary terminal workspace layer. It owns workspaces, tabs, panes,
navigation, splits, zoom, resize mode, and its sidebar. Ghostty owns only
terminal-host functions that Herdr cannot provide.

## Herdr Stow package

```text
herdr/
└── .config/
    └── herdr/
        └── config.toml
```

This maps to `~/.config/herdr/config.toml` while leaving Herdr's logs, sockets,
and session state untouched.

Install or update the managed link through the repository's single setup entry
point, then reload Herdr:

```bash
cd ~/Documents/dotfiles
./setup/bootstrap.sh --no-repo-update
herdr server reload-config
```

## How the Herdr prefix works

Press `Control (⌃) + B`, release both keys, and then press the command key shown
below. A shortcut written as `Control (⌃) + B`, then `Shift (⇧) + N` is a
sequence, not one simultaneous chord.

### General and workspace commands

| Prefix sequence | Action |
| --- | --- |
| `Control (⌃) + B`, then `?` | Open help |
| `Control (⌃) + B`, then `S` | Open settings |
| `Control (⌃) + B`, then `Q` | Detach from the session |
| `Control (⌃) + B`, then `Shift (⇧) + R` | Reload the Herdr config |
| `Control (⌃) + B`, then `O` | Open the notification target |
| `Control (⌃) + B`, then `W` | Open the workspace picker |
| `Control (⌃) + B`, then `G` | Open goto mode |
| `Control (⌃) + B`, then `Shift (⇧) + N` | Create a workspace |
| `Control (⌃) + B`, then `Shift (⇧) + G` | Create a worktree |
| `Control (⌃) + B`, then `Shift (⇧) + W` | Rename the workspace |
| `Control (⌃) + B`, then `Shift (⇧) + D` | Close the workspace |

### Tab commands

| Prefix sequence | Action |
| --- | --- |
| `Control (⌃) + B`, then `C` | Create a tab |
| `Control (⌃) + B`, then `Shift (⇧) + T` | Rename the tab |
| `Control (⌃) + B`, then `P` | Select the previous tab |
| `Control (⌃) + B`, then `N` | Select the next tab |
| `Control (⌃) + B`, then `1–9` | Select tab 1–9 |
| `Control (⌃) + B`, then `Shift (⇧) + X` | Close the tab |

### Pane commands

| Prefix sequence | Action |
| --- | --- |
| `Control (⌃) + B`, then `H/J/K/L` | Focus left/down/up/right |
| `Control (⌃) + B`, then `Tab (⇥)` | Cycle to the next pane |
| `Control (⌃) + B`, then `Shift (⇧) + Tab (⇥)` | Cycle to the previous pane |
| `Control (⌃) + B`, then `V` | Create a vertical split |
| `Control (⌃) + B`, then `-` | Create a horizontal split |
| `Control (⌃) + B`, then `X` | Close the pane |
| `Control (⌃) + B`, then `Z` | Toggle pane zoom |
| `Control (⌃) + B`, then `R` | Enter resize mode |
| `Control (⌃) + B`, then `Shift (⇧) + P` | Rename the pane |
| `Control (⌃) + B`, then `E` | Edit pane scrollback |
| `Control (⌃) + B`, then `B` | Toggle the sidebar |

Navigate mode uses the arrow keys for workspaces and `H/J/K/L` for panes. In a
remote Herdr client, `Control (⌃) + V` performs remote image paste.

## Ghostty shortcuts retained

Ghostty starts its keybinding section with `keybind = clear`. Any shortcut not
listed here is passed to Herdr or the focused pane application.

| Shortcut | Action |
| --- | --- |
| `Command (⌘) + C` | Copy |
| `Command (⌘) + V` | Paste |
| `Command (⌘) + +` or `Command (⌘) + =` | Increase font size |
| `Command (⌘) + -` | Decrease font size |
| `Command (⌘) + 0` | Reset font size |
| `Command (⌘) + F` | Start search |
| `Command (⌘) + E` | Search selected text |
| `Command (⌘) + G` | Next search result |
| `Command (⌘) + Shift (⇧) + G` | Previous search result |
| `Command (⌘) + Shift (⇧) + F` or `Escape (Esc)` | End search |
| `Command (⌘) + N` | Open a new Ghostty window |
| `Command (⌘) + Enter (↩)` | Toggle Ghostty fullscreen |
| `Command (⌘) + Q` | Quit Ghostty |
| `Command (⌘) + ,` | Open the Ghostty config |
| `Command (⌘) + Shift (⇧) + ,` | Reload the Ghostty config |

Ghostty does not own tabs, splits, surface navigation, split zoom/resize,
scrolling, prompt navigation, or numbered tab switching.

## Validate

```bash
/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config \
  --config-file=~/Documents/dotfiles/ghostty/.config/ghostty/config.ghostty
/Applications/Ghostty.app/Contents/MacOS/ghostty +list-keybinds
herdr config check
herdr server reload-config
```

## Recovery

The repository tag `terminal-pre-herdr-keymap-20260810` marks the known-good
state before keybinding ownership changed.

Restore Ghostty's earlier configuration:

```bash
cd ~/Documents/dotfiles
git restore --source=terminal-pre-herdr-keymap-20260810 -- \
  ghostty/.config/ghostty/config.ghostty
/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config \
  --config-file=ghostty/.config/ghostty/config.ghostty
```

Return Herdr to its built-in defaults by removing only its Stow link:

```bash
cd ~/Documents/dotfiles
stow --delete --target="$HOME" herdr
herdr server reload-config
```

The built-in defaults are provided by Herdr itself and are not duplicated in
this repository.
