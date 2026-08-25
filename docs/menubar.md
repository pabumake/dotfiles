---
layout: default
title: Menu-Bar Icons
---

# Menu-bar icon management

Bootstrap manages one native menu-bar provider at a time:

| Choice | Package | Notes |
| --- | --- | --- |
| Hidden Bar | `hiddenbar` | Simple divider-based hiding; no special permissions |
| Ice | `jordanbaird-ice@beta` on macOS 26+, stable on macOS 15 | Richer layout controls; Accessibility required |
| None | — | Backs up and removes both managed providers |

[Hidden Bar](https://github.com/dwarvesf/hidden) is MIT licensed. [Ice](https://github.com/jordanbaird/Ice)
is GPL-3.0 licensed. The dotfiles bootstrap requires macOS 15.6 or newer. It
uses the Tahoe beta on macOS 26 because that release contains the project's
Tahoe compatibility work.

## Choose or switch provider

The first bootstrap uses `fzf` for an Up/Down + Enter selector, with Ice
preselected and a numbered fallback where pressing Enter also chooses Ice. On a
noninteractive first run, Ice is selected automatically. The successful choice
is stored outside the repository at
`~/.local/state/pabu-dotfiles/menu-bar-manager/selection` and reused by updates.

Choose explicitly, including for unattended setup:

```bash
./setup/bootstrap.sh --menu-bar-manager hiddenbar
./setup/bootstrap.sh --menu-bar-manager ice
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
and [`ice/preferences.plist`](https://github.com/pabumake/dotfiles/blob/main/ice/preferences.plist)
are imported only when their corresponding preference domain is absent. Later
bootstrap runs preserve changes made in either application.

Both profiles reveal hidden icons on click, rehide them after 10 seconds, keep
the always-hidden section and global hotkeys disabled, and retain the native
menu-bar appearance. Ice additionally disables hover, scroll reveal, Ice Bar,
item-spacing changes, and application-menu hiding. No managed Ice hotkeys
overlap with AeroSpace, Ghostty, or Herdr.

Ice needs **System Settings → Privacy & Security → Accessibility** permission to
inspect and arrange menu-bar items. Screen Recording is optional and is not
needed for the managed native-appearance profile. Enable **Launch at login** in
Ice's General settings; that service registration is not stored in its plist.

## Arrange and reveal icons

Hold `Command (⌘)` while dragging a menu-bar icon. Place an icon on the visible
or hidden side of the selected manager's divider, then use its control icon to
reveal or collapse the hidden section. Ice also offers a visual layout editor.

Other applications own their icon positions, so those positions remain
device-specific. If arranging icons fails while the system menu bar hides
automatically, temporarily set **System Settings → Control Center → Automatically
hide and show the menu bar** to **Never**, arrange them, then restore the setting.

## Manual exports and imports

Provider helpers share the same guarded export/import implementation:

```bash
cd ~/Documents/dotfiles
./scripts/hiddenbar-settings.sh export
./scripts/ice-settings.sh export
```

Default exports live under `~/.local/state/pabu-dotfiles/backups`. Explicit
destinations must be absolute and outside the repository:

```bash
./scripts/ice-settings.sh export \
  --output "$HOME/Desktop/ice-preferences.plist"
```

Restore an export with the matching helper:

```bash
./scripts/hiddenbar-settings.sh import /path/to/preferences.plist
./scripts/ice-settings.sh import /path/to/preferences.plist
```

Imports validate the source, make a recovery export, preserve the app's running
state, and roll back automatically on failure. Add `--yes` only after reviewing
the source, or `--dry-run` to print the operations.

## Recovery and removal

The manager state directory records the last validated backup for each provider.
Homebrew removal deliberately omits `--zap`, so application preferences also
remain available for a later switch back. Selecting None uses the same backup
workflow before uninstalling both providers.

The checkpoint tag `menubar-pre-hiddenbar-20260810` predates menu-bar management.
For a complete repository rollback:

```bash
cd ~/Documents/dotfiles
git restore --source=menubar-pre-hiddenbar-20260810 -- \
  Brewfile README.md setup/bootstrap.sh docs/index.md docs/setup.md
git rm docs/menubar.md scripts/app-settings.sh \
  scripts/hiddenbar-settings.sh scripts/ice-settings.sh \
  hiddenbar/preferences.plist ice/preferences.plist
```
