---
layout: default
title: Menu-Bar Icons
---

# Menu-bar icon management

Bootstrap manages one native menu-bar provider at a time:

| Choice | Package | Notes |
| --- | --- | --- |
| Thaw | `thaw` | Richer layout controls; Accessibility required; macOS 26+ |
| Hidden Bar | `hiddenbar` | Simple divider-based hiding; no special permissions |
| None | — | Backs up and removes all managed providers |

[Thaw](https://github.com/thaw-app/Thaw) is the successor to Ice.
[Hidden Bar](https://github.com/dwarvesf/hidden) is MIT licensed. The dotfiles
bootstrap requires macOS 15.6 or newer. Thaw requires macOS 26 or newer.

## Choose or switch provider

The first bootstrap uses `fzf` for an Up/Down + Enter selector, with Thaw
preselected and a numbered fallback where pressing Enter also chooses Thaw. On a
noninteractive first run, Thaw is selected automatically if it is available.
If Ice is already installed, bootstrap detects it and prompts to switch to Thaw
before presenting the full selector. The successful choice is stored outside the
repository at `~/.local/state/pabu-dotfiles/menu-bar-manager/selection` and
reused by updates.

Choose explicitly, including for unattended setup:

```bash
./setup/bootstrap.sh --menu-bar-manager thaw
./setup/bootstrap.sh --menu-bar-manager hiddenbar
./setup/bootstrap.sh --menu-bar-manager none
```

Show the selector again at any time:

```bash
./setup/bootstrap.sh --switch-bar-manager
```

Before removing a provider, bootstrap exports and validates its preferences.
It uninstalls without `--zap`, installs the new provider, restores its last
recorded backup when needed, and otherwise imports its tracked baseline. The
saved choice changes only after the complete switch succeeds. A failed switch
reinstalls and restores the previous provider.

## Tracked first-run preferences

The tracked [`hiddenbar/preferences.plist`](https://github.com/pabumake/dotfiles/blob/main/hiddenbar/preferences.plist)
and [`thaw/preferences.plist`](https://github.com/pabumake/dotfiles/blob/main/thaw/preferences.plist)
are imported only when their corresponding preference domain is absent. Later
bootstrap runs preserve changes made in either application.

Both profiles reveal hidden icons on click, rehide them after 10 seconds, and
retain the native menu-bar appearance. Thaw additionally needs **System Settings
→ Privacy & Security → Accessibility** permission to inspect and arrange
menu-bar items. Enable **Launch at login** in Thaw's settings; that service
registration is not stored in its plist.

## Arrange and reveal icons

Hold `Command (⌘)` while dragging a menu-bar icon. Place an icon on the visible
or hidden side of the selected manager's divider, then use its control icon to
reveal or collapse the hidden section.

Other applications own their icon positions, so those positions remain
device-specific. If arranging icons fails while the system menu bar hides
automatically, temporarily set **System Settings → Control Center → Automatically
hide and show the menu bar** to **Never**, arrange them, then restore the setting.

## Manual exports and imports

Provider helpers share the same guarded export/import implementation:

```bash
cd ~/Documents/dotfiles
./scripts/thaw-settings.sh export
./scripts/hiddenbar-settings.sh export
```

Default exports live under `~/.local/state/pabu-dotfiles/backups`. Explicit
destinations must be absolute and outside the repository:

```bash
./scripts/thaw-settings.sh export \
  --output "$HOME/Desktop/thaw-preferences.plist"
```

Restore an export with the matching helper:

```bash
./scripts/thaw-settings.sh import /path/to/preferences.plist
./scripts/hiddenbar-settings.sh import /path/to/preferences.plist
```

Imports validate the source, make a recovery export, preserve the app's running
state, and roll back automatically on failure. Add `--yes` only after reviewing
the source, or `--dry-run` to print the operations.

## Recovery and removal

The manager state directory records the last validated backup for each provider.
Homebrew removal deliberately omits `--zap`, so application preferences also
remain available for a later switch back. Selecting None uses the same backup
workflow before uninstalling all providers.

The checkpoint tag `menubar-pre-hiddenbar-20260810` predates menu-bar management.
For a complete repository rollback:

```bash
cd ~/Documents/dotfiles
git restore --source=menubar-pre-hiddenbar-20260810 -- \
  Brewfile README.md setup/bootstrap.sh docs/index.md docs/setup.md
git rm docs/menubar.md scripts/app-settings.sh \
  scripts/hiddenbar-settings.sh scripts/thaw-settings.sh \
  hiddenbar/preferences.plist thaw/preferences.plist
```
