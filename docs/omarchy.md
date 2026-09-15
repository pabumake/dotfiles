---
layout: default
title: Omarchy bootstrap
---

# Omarchy bootstrap

Run from an existing checkout on an installed Omarchy desktop as your normal
user. Python 3, pacman, and the Omarchy CLI are prerequisites. The bootstrap
uses this checkout without fetching, pulling, or changing branches.

```bash
cd ~/Documents/dotfiles
./setup/bootstrap-omarchy.sh --dry-run
./setup/bootstrap-omarchy.sh
```

For unattended setup, explicitly allow replacements of conflicting configs:

```bash
./setup/bootstrap-omarchy.sh --yes --backup-conflicts
```

`--dry-run` only inspects the system and reports missing packages, conflicting
files, Bash changes, desktop hooks, and dock changes. `--yes` accepts installation and Bash integration;
it requires `--backup-conflicts` if existing Stow targets need replacement.
`--skip-bash` links the Bash overlay but leaves `.bashrc` alone. `--help` lists
all options. Package installation can still require a sudo password.

## Shared configuration and packages

Stow links `herdr`, `nvim`, `starship`, `yazi`, `gh-manager`, `omarchy-bash`, and `omarchy-desktop`
into `~/.config`, with directory folding disabled. Existing unrelated files
remain in place. Custom `XDG_CONFIG_HOME` locations and a symlinked `~/.config`
are rejected rather than redirected unexpectedly.

Missing terminal dependencies are installed using `omarchy pkg add`: Git, Stow, Herdr,
Starship, eza, Yazi, Neovim, ripgrep, fd, fzf, lazygit, Cliamp, FFmpeg, 7zip,
jq, Poppler, zoxide, resvg, ImageMagick, the Tree-sitter CLI, and JetBrains
Mono Nerd Font. Node.js and npm are added only if `node` is absent from PATH,
preserving an available mise runtime. Herdr and Cliamp are available from the
Omarchy package repository.
Packages already installed are not explicitly upgraded. If package mirrors
are stale, complete the normal Omarchy system update before retrying.

`gh-manager` is configuration-only; its binary is not installed. Neovim installs
plugins on first launch. The bootstrap checks Herdr's config before replacing
files, but does not restart running Herdr sessions.

## Desktop applications and defaults

| Application | Installation when missing | Default |
| --- | --- | --- |
| Keeper Password Manager | `omarchy pkg aur add keeper-password-manager` | `keeper://` links |
| Zen Browser | `omarchy pkg aur add zen-browser-bin` | Browser, HTTP/HTTPS links, HTML/XHTML files |
| Steam | `omarchy install gaming steam` | `steam://` and `steamlink://` links |
| Ghostty | `omarchy install terminal ghostty` | Omarchy terminal launcher |

Keeper and Zen require Omarchy's `yay` helper. Steam's Omarchy installer also
selects the system's 32-bit graphics libraries and launches Steam after a new
installation. Sign in to Keeper, Steam, and browser services yourself; vaults,
credentials, browser profiles, and games are not copied into the repository.
Keeper's browser extension is not installed automatically.

Defaults use `xdg-settings`, `xdg-mime`, and Omarchy's terminal installer.
The desktop IDs are `zen.desktop`, `keeperpasswordmanager.desktop`,
`steam.desktop`, and `com.mitchellh.ghostty.desktop`. The script removes the
shell's `BROWSER` variable only from the default-setting subprocess environment
so it cannot block `xdg-settings`. Unrelated associations such as mail and PDFs
are preserved. Keeper is registered for its own URI scheme; this does not
configure browser autofill.

Existing MIME preference files and the terminal preference list are backed up
before changes. Defaults are checked after setting them and skipped on later
runs when already correct. Symlinked preference files that need edits are
rejected before installation. Changing the default terminal uses Omarchy's
single-terminal preference list, replacing any previous fallback order; the
original list is backed up.

Ghostty is excluded from Stow on Omarchy, preserving its shortcuts, dynamic
theme, and Linux settings. If its configuration directory is absent, Omarchy's
terminal installer supplies its stock configuration. Hyprland uses the desktop overlay
described below. The shell configuration stays local; only the dock entry is managed.
macOS-only packages are excluded. The macOS bootstrap and its Stow selection are unchanged.

## Desktop overlay

Edit `omarchy-desktop/.config/pabu-dotfiles/omarchy/` in this checkout:

| File | Purpose |
| --- | --- |
| `bindings.lua` | Personal shortcuts; Super+Shift+D replaces Docker with the dock |
| `monitors.lua` | Shared DP-2/DP-3 layout, 1.25 scale, and GDK_SCALE=1 |
| `plugins.json` | Dock repository, ID, and placement in the center before system update |
| `dock-settings.json` | Dock preferences; `{}` initially uses plugin defaults |
| `dock-pinned.json` | Pinned apps and folders; initially empty |

Stow exposes these files under `~/.config/pabu-dotfiles/omarchy/`. Small marked
`dofile(...)` blocks at the end of `~/.config/hypr/bindings.lua` and
`monitors.lua` load the Lua overlays. Existing unrelated user configuration stays
in place; setup migrates the known dock binding and DP-2/DP-3 rules with backups.
The same monitor layout applies on every Omarchy machine. Other outputs use the
preferred-mode, automatic-position fallback at scale 1.25.

Run these commands from the repository root:

```bash
# Inspect or apply only desktop integration (also repairs missing hooks).
python3 setup/omarchy-desktop.py apply --dry-run
python3 setup/omarchy-desktop.py apply --yes --backup-conflicts

# After editing Lua files, explicitly reload and check the configuration.
hyprctl reload
hyprctl configerrors

# Save changes made through the dock UI back into dotfiles.
python3 setup/omarchy-desktop.py capture-dock --dry-run
python3 setup/omarchy-desktop.py capture-dock
git diff -- omarchy-desktop
```

Apply requires a running Hyprland and Omarchy shell session and checks both before
changing files. Dry runs and capture do not require a running session. Bootstrap
runs the same desktop integration automatically. Changed runtime files are backed
up; unchanged files and correctly enabled plugins are skipped on subsequent runs.
Apply overwrites local dock preferences and pins with the repository versions, so
capture UI changes first if you want to keep them. Missing capture inputs leave
the repository unchanged. JSON must be valid; unknown fields are preserved.

Dock runtime JSON remains regular files: the plugin uses atomic writes, so direct
symlinks could be replaced by UI saves. Preferences hot-reload when applied.
The shell has no include mechanism; setup uses Omarchy's plugin CLI to manage its
dock entry and preserves unrelated shell settings. If the system-update widget
is absent, the dock goes at the end of the center section.

The dock is installed only when absent. An existing installation must have the
expected ID and Git origin. Setup does not update it or vendor its code. A fresh
installation uses the upstream version available then; update explicitly with:

```bash
omarchy plugin update rosakodu.dock
```

After an Omarchy config reset, rerun desktop apply to restore hooks. There is no
post-update hook. Additional Lua customization modules can be loaded with
`dofile` from the tracked bindings or monitors file. Never edit packaged files
under `/usr/share/omarchy/` for personal settings.

To undo desktop apply, remove the two marked hook blocks before unlinking the
Stow package, or restore the backed-up Hyprland files. Restore desired dock JSON
and shell settings from the printed backup directory. On this machine the initial
dock JSON files were absent; remove those generated files to return to that state.
The plugin remains installed; disable it with `omarchy plugin disable rosakodu.dock`
if desired. Capture also backs up repository files before replacing their contents.

## Bash integration

Omarchy's `.bashrc` loads its environment even for noninteractive shells, then
loads aliases, functions, completions, mise, zoxide, and Starship for interactive
shells. The old `bash/.bashrc` in this repository is a SUSE configuration and is
not installed on Omarchy.

The bootstrap keeps your current `.bashrc` and appends this line once, after
the existing content:

```bash
[[ -r "$HOME/.config/pabu-dotfiles/bash.sh" ]] && source "$HOME/.config/pabu-dotfiles/bash.sh"
```

The overlay adds `cls`, `ll`, and `y` (Yazi with directory changes on exit).
Omarchy keeps ownership of `ls`, `h` (Herdr), the editor, PATH, and tool
initialization. The shared Starship file changes the prompt's appearance
without initializing Starship a second time. Open a new Bash shell to apply.

If `.bashrc` is absent, the bootstrap starts with the installed Omarchy template.
If it is a symlink or does not reference Omarchy's Bash defaults, setup stops
before installation. Review its owner, add the source line after the defaults
yourself, and use `--skip-bash` for that arrangement.

## Backups and recovery

Conflicting Stow targets are moved under
`${XDG_STATE_HOME:-~/.local/state}/pabu-dotfiles/backups/omarchy-<unique-id>/`,
preserving their paths relative to your home directory. The bootstrap prints
the exact backup directory. `.bashrc` is copied there before an edit.

A failed Stow simulation restores moved conflicts. If applying Stow fails,
backups are retained for manual recovery because some links may already exist.
Successful reruns recognize managed links and the Bash source line, so they
do not create repeat backups for unchanged files.

Before removing desktop overlay links, restore the backed-up Hyprland files or
remove their marked `BEGIN pabu-dotfiles omarchy` / `END pabu-dotfiles omarchy`
blocks. Otherwise Hyprland will try to load missing Lua files.

To undo links from this bootstrap:

```bash
stow --delete --dir="$HOME/Documents/dotfiles" --target="$HOME" \
  herdr nvim starship yazi gh-manager omarchy-bash omarchy-desktop
```

Then restore the desired files and desktop preferences from the printed backup directory. Restore
the backed-up `.bashrc`, or remove its overlay source line if you have since
made other edits. Installed packages remain installed.

## Validation

```bash
python3 -m unittest discover -s setup -p 'test_omarchy_*.py'
```

Tests use temporary home directories, real GNU Stow and `xdg-mime`, and stubbed
package installers. They do not install packages or change your live defaults.
