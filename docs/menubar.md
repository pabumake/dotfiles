---
layout: default
title: Menu-Bar Icons
---

# Menu-bar icon management

[Hidden Bar](https://github.com/dwarvesf/hidden) manages native macOS menu-bar
icons without replacing the menu bar. It is open source under the MIT license
and does not require Accessibility or Screen Recording permission.

## Managed first-run defaults

The bootstrap installs Hidden Bar and applies these defaults only when the app
has no existing preferences:

- start at login;
- reveal hidden icons by clicking the arrow;
- collapse automatically after 10 seconds;
- keep the regular hidden section only;
- leave the always-hidden section and global hotkey disabled;
- leave the native menu-bar appearance unchanged.

Later bootstrap runs preserve changes made in Hidden Bar's preferences.

## Arrange and reveal icons

Hold `Command (⌘)` while dragging a menu-bar icon:

- place it to the right of Hidden Bar's separator to keep it visible;
- place it to the left of the separator to hide it when collapsed.

Click Hidden Bar's arrow to expand or collapse the hidden section. Right-click
the arrow or click the separator to open its menu and preferences.

macOS inserts new menu-bar icons at the far-left position, which may be inside
the hidden section. If a newly installed or updated app appears missing, expand
Hidden Bar and `Command (⌘) + drag` its icon to the visible side once.

Icon positions belong to macOS and are device-specific, so they are not stored
in this repository. If the system menu bar is configured to hide automatically
and arranging icons fails, temporarily set **System Settings → Control Center →
Automatically hide and show the menu bar** to **Never**, arrange the icons, and
then restore the preferred system setting.

## Back up and restore preferences

Store preference exports outside the repository:

```bash
backup_dir="$HOME/.local/state/pabu-dotfiles/backups/hiddenbar-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
defaults export com.dwarvesv.minimalbar "$backup_dir/preferences.plist"
```

Restore an export after quitting Hidden Bar:

```bash
osascript -e 'quit app "Hidden Bar"'
defaults import com.dwarvesv.minimalbar \
  "$HOME/.local/state/pabu-dotfiles/backups/hiddenbar-TIMESTAMP/preferences.plist"
open -a "Hidden Bar"
```

The plist contains preferences, not portable positions for other applications'
menu-bar icons.

## Remove Hidden Bar

The checkpoint tag `menubar-pre-hiddenbar-20260810` marks the repository before
Hidden Bar was added. First disable Hidden Bar under **System Settings → General
→ Login Items**, then quit and uninstall it:

```bash
osascript -e 'quit app "Hidden Bar"'
brew uninstall --cask hiddenbar
```

To remove its saved preferences as well:

```bash
defaults delete com.dwarvesv.minimalbar
```

For a complete repository rollback, restore the changed tracked files from the
checkpoint and remove this new guide before committing the rollback:

```bash
cd ~/Documents/dotfiles
git restore --source=menubar-pre-hiddenbar-20260810 -- \
  Brewfile README.md setup/bootstrap.sh docs/index.md docs/setup.md
git rm docs/menubar.md
```
