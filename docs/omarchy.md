---
layout: default
title: Omarchy bootstrap
---

# Omarchy bootstrap

Run from an existing checkout on an installed Omarchy desktop as your normal
user. Python 3, pacman, and the Omarchy CLI are prerequisites. The bootstrap
uses this checkout without fetching, pulling, or changing branches.

```bash
cd ~/src/dotfiles
./setup/bootstrap-omarchy.sh --dry-run
./setup/bootstrap-omarchy.sh
```

For unattended setup, explicitly allow replacements of conflicting configs:

```bash
./setup/bootstrap-omarchy.sh --yes --backup-conflicts
```

| Option | Behavior |
| --- | --- |
| `--dry-run` | Report missing and retired packages, conflicts, Bash changes, and desktop integration without applying them |
| `--yes` | Accept installation, retired-package removal, and Bash integration |
| `--backup-conflicts` | Back up conflicting Stow targets before replacing them; required with `--yes` when conflicts exist |
| `--skip-bash` | Link the Bash overlay without editing `.bashrc` |
| `--gaming` | Also install Steam, Input Remapper, and WowUp-CF and configure their integration |
| `--include-trials` | Include trial package lists for this run; currently empty on Omarchy |
| `--help` | List all options |

Package changes can still require a sudo password. Unlike the macOS bootstrap,
this entry point does not update the checkout or provide an upgrade flag.

## Shared configuration and packages

Stow links `herdr`, `nvim`, `starship`, `yazi`, `gh-manager`, `omarchy-bash`,
`omarchy-desktop`, and `omarchy-handy` below your home directory, with directory
folding disabled. Configuration lives under `~/.config`; the Handy adapters
also create links under `~/.local/bin`. Existing unrelated files remain in
place. Custom `XDG_CONFIG_HOME` locations and a symlinked `~/.config` are
rejected rather than redirected unexpectedly.

Missing terminal dependencies are installed using `omarchy pkg add`: Git, Stow, Herdr,
Starship, eza, Yazi, Neovim, ripgrep, fd, fzf, lazygit, FFmpeg, 7zip,
jq, Poppler, zoxide, resvg, ImageMagick, the Tree-sitter CLI, and JetBrains
Mono Nerd Font. Node.js and npm are added only if `node` is absent from PATH,
preserving an available mise runtime. Herdr is available from the
Omarchy package repository.
Packages already installed are not explicitly upgraded. If package mirrors
are stale, complete the normal Omarchy system update before retrying.

Cliamp is retired. If installed, bootstrap removes it with
`sudo pacman -R --noconfirm cliamp` after setup approval. It retains dependencies
and user data. `--dry-run` reports the removal without running it; later runs
skip removal once Cliamp is absent.

`--include-trials` opts into the `TRIAL_DEPENDENCIES` and `TRIAL_AUR_PACKAGES`
lists in `setup/omarchy_bootstrap.py` for that run. Both lists are currently
empty. Orion is configured only in the separate macOS `Brewfile.trials`.
Without the flag, trial packages are left installed and are not upgraded.

`gh-manager` is configuration-only; its binary is not installed. Neovim installs
plugins on first launch. The bootstrap checks Herdr's config before replacing
files, but does not restart running Herdr sessions.

## Desktop applications and defaults

| Application | Installation when missing | Default |
| --- | --- | --- |
| Keeper Password Manager | `omarchy pkg aur add keeper-password-manager` | `keeper://` links |
| Zen Browser | `omarchy pkg aur add zen-browser-bin` | Browser, HTTP/HTTPS links, HTML/XHTML files |
| Steam (gaming) | `omarchy install gaming steam` | `steam://` and `steamlink://` links |
| Ghostty | `omarchy install terminal ghostty` | Omarchy terminal launcher |
| Handy | `omarchy pkg aur add handy-bin` | Offline speech-to-text, Omarchy dictation backend |
| Input Remapper (gaming) | `omarchy pkg aur add input-remapper-git` | Graphical device-specific key remapping |
| WowUp-CF (gaming) | `omarchy pkg aur add wowup-cf-bin` | WoW addon manager with CurseForge support |

Rows marked *gaming* are installed only on request: add `--gaming` to the
bootstrap (`./setup/bootstrap-omarchy.sh --gaming`). Without it, Steam, Input
Remapper, WowUp-CF, the Steam URI handlers, and the `input-remapper.service`
enablement are skipped entirely; the dry run reports "Gaming setup: skipped".
Rerun with `--gaming` at any time to add them. Later runs without the flag leave
installed gaming apps, associations, and the service in place. The AUR
applications require Omarchy's `yay` helper. Steam's Omarchy installer also
selects the system's 32-bit graphics libraries and launches Steam after a new
installation. Sign in to Keeper, Steam, and browser services yourself; vaults,
credentials, browser profiles, and games are not copied into the repository.
Keeper's browser extension is not installed automatically.

### WoW addons (WowUp-CF)

CurseForge publishes no Linux app, so addons are managed with
[WowUp-CF](https://github.com/WowUp/WowUp.CF), a native addon manager that uses
CurseForge as a source. The AUR package `wowup-cf-bin` unpacks the official
AppImage into `/opt/wowup-cf` and installs the `wowup-cf` launcher and menu entry.

Launch **WowUp-CF**, then set each client's install folder (Retail, Classic,
Classic Era) to the game directory containing its `_retail_`, `_classic_`, or
`_classic_era_` folder. Use *Get Addons* to search and install; auto-updates
are optional in its settings. The Windows CurseForge app is not used.

Its settings, the WoW install, and addons are local state and are not tracked
in this repository. Pair it with the Orbweaver preset below for MMO keybinds.

### Handy dictation

[Handy](https://handy.computer/) provides offline speech-to-text. This repository
integrates it through Omarchy's dictation-backend system. The
`omarchy-handy` Stow package links `omarchy-dictation-handy` and
`omarchy-install-dictation-handy` into `~/.local/bin` and `handy/shortcuts.lua`
into `~/.config`, which starts Handy hidden at login. Omarchy's own dictation
keys then drive it: **Alt + Space** toggles and **Alt + Right Alt** is
push-to-talk. The tracked backend installer also installs `wtype` and
`wl-clipboard`, selects Handy, reloads Hyprland, and shows the dictation keys:

```bash
omarchy-install-dictation-handy
```

Bootstrap selects Handy with `omarchy-dictation-use handy` only when no
dictation backend is configured; an existing Voxtype or Superwhisper choice is
kept (switch with `omarchy-dictation-use handy`, or Setup > Defaults >
Dictation). Handy has no start/stop/status command on Wayland, so the adapter
tracks recording state in `$XDG_RUNTIME_DIR` to keep push-to-talk balanced.
Toggling from Handy's own window or tray can desync it, and `stop` with nothing
recording does nothing. Choose the speech model in Handy's settings on first
launch; models and settings are local state.

### Orbweaver key remapping

With `--gaming`, bootstrap installs [Input Remapper](https://github.com/sezanzeb/input-remapper)
from the AUR and enables `input-remapper.service` at boot. It supports Wayland
and remaps Linux input events, so no OpenRazer driver or lighting plugin is needed.
An already enabled, running service is left alone.

Launch **Input Remapper** from the application menu (`input-remapper-gtk`), select
**Razer Razer Orbweaver Chroma**, and create a preset. Record a keypad button,
choose its output key or combination, and click **Apply**. Enable the preset's
autoload option to restore it when the device connects. Select the Orbweaver
rather than a regular keyboard so the remapping applies only to the keypad.
Click **Stop** before recording changes to an active mapping.

Presets and autoload preferences remain local in `~/.config/input-remapper-2/`;
bootstrap does not replace GUI edits or impose a key layout. These are software
mappings on this Linux installation rather than profiles saved into the keypad.
Service checks and a recovery command:

```bash
systemctl status input-remapper.service
input-remapper-control --command hello
sudo systemctl stop input-remapper.service
```

The `omarchy-razer-control` plugin is not installed: it has no Orbweaver-specific
support and does not provide key remapping.

The optional [Orbweaver MMO preset](https://github.com/pabumake/dotfiles/blob/main/input-remapper/README.md) uses thumb-pad
movement and Shift/Ctrl layers on the main grid. Install and apply it with
`python3 setup/orbweaver-mmo.py --apply` from the repository root. It leaves
autoload preferences alone; game action bindings must be configured in-game.

### Desktop associations

Defaults use `xdg-settings`, `xdg-mime`, and Omarchy's terminal installer.
The desktop IDs are `zen.desktop`, `keeperpasswordmanager.desktop`,
`steam.desktop`, and `com.mitchellh.ghostty.desktop`; Steam associations are
managed only with `--gaming`. The script removes the
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
| `input.lua` | US International layout using `kb_layout = "us"` and `kb_variant = "intl"` |
| `plugins.json` | Plugin list with Git URLs, IDs, bar sections, and optional placement anchors |
| `dock-settings.json` | Tracked hover, autohide, appearance, and widget settings |
| `dock-pinned.json` | Pinned apps and folders; initially `{"pinned": []}` |

Stow exposes these files under `~/.config/pabu-dotfiles/omarchy/`. Small marked
`dofile(...)` blocks at the end of `~/.config/hypr/bindings.lua`,
`monitors.lua`, and `input.lua` load the Lua overlays. Existing unrelated user
configuration stays in place; setup migrates the known dock binding and
DP-2/DP-3 rules with backups.
The same monitor layout applies on every Omarchy machine. Other outputs use the
preferred-mode, automatic-position fallback at scale 1.25.

The input overlay sets US International on every managed Omarchy machine.
Quotes act as dead keys; type `"` followed by `a`, `o`, or `u` for umlauts.
The input-language widget remains available for switching layouts. Edit the
tracked `input.lua` to change the managed layout.

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

Configured plugins are installed only when absent. Existing installations must have
the expected IDs and Git origins. Setup does not update them or vendor their code. A fresh
installation uses the upstream version available then; update explicitly with:

```bash
omarchy plugin update rosakodu.dock
omarchy plugin update n0d3x.input-language
omarchy plugin update air.workspaces
```

`plugins.json` contains a `plugins` array. Each entry specifies `id`, `url`,
`section` (`left`, `center`, or `right`), and optionally `before` (another widget
ID in that section). A `cargo_binary` field requests a local release build
using Cargo.lock before enablement. Setup manages `rosakodu.dock` in the center and
[`n0d3x.input-language`](https://github.com/n0d3xt-max/n0d3x.input-language)
at the end of the right section, plus
[`air.workspaces`](https://github.com/airenare/omarchy-workspaces-by-monitor)
on the left (Omarchy replaces its stock workspace widget automatically), and
[`ozdil.security-sentinel`](https://github.com/ozdil/omarchy-security-sentinel)
on the right before the input-language widget.
Add future bar plugins to this list and rerun
bootstrap or desktop apply.

Security Sentinel requires a locally built `sentinel-engine`. Bootstrap installs
Rust when Cargo is unavailable and the engine needs building; it also ensures
libnotify, NetworkManager, Zenity, and pacman-contrib are installed. Setup builds
with `cargo build --release --locked` and installs the resulting executable into
the plugin directory before enabling it. An existing executable is reused on
later runs. Standalone desktop apply asks you to run bootstrap if Cargo is missing.
The engine and its build output remain outside dotfiles.

After explicitly updating Security Sentinel, rebuild its engine before restarting
the shell (ordinary setup does not upgrade plugins or rebuild existing engines):

```bash
omarchy plugin update ozdil.security-sentinel
cargo build --release --locked --manifest-path "$HOME/.config/omarchy/plugins/ozdil.security-sentinel/Cargo.toml"
install -m 755 "$HOME/.config/omarchy/plugins/ozdil.security-sentinel/target/release/sentinel-engine" "$HOME/.config/omarchy/plugins/ozdil.security-sentinel/sentinel-engine"
omarchy restart shell
```

The input-language widget lets you choose layouts from its flyout and manage
available languages with its gear button. Its preferences stay local in
`~/.local/state/omarchy/plugins/n0d3x.input-language/config.json`; `capture-dock`
captures only dock files. Existing keyboard widgets and shortcuts are preserved.

The workspace widget's gear menu configures monitor groups, colors, and workspace
assignments. Setup adds the plugin's `air.workspaces` marker pair to the local
`~/.config/hypr/monitors.lua`, allowing the plugin to save workspace pins and
reload Hyprland. Rerunning setup preserves those generated rules. Groups are
stored in the widget's `shell.json` entry and remain local, as do generated pins;
`capture-dock` does not capture them. No workspace assignments are imposed by setup.

After an Omarchy config reset, rerun desktop apply to restore hooks. There is no
post-update hook. Additional Lua customization modules can be loaded with
`dofile` from the tracked bindings, monitors, or input file. Never edit packaged files
under `/usr/share/omarchy/` for personal settings.

To undo desktop apply, remove the three marked hook blocks before unlinking the
Stow package, or restore the backed-up Hyprland files. Restore desired dock JSON
and shell settings from the printed backup directory. If a dock JSON file was
originally absent, remove the generated file to restore that state. Plugins
remain installed; disable them individually with `omarchy plugin disable ID`.
Capture also backs up repository files before replacing their contents.

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
blocks from `bindings.lua`, `monitors.lua`, and `input.lua`. Otherwise Hyprland
will try to load missing Lua files. Before unlinking `omarchy-handy`, select
another installed dictation backend through **Setup → Defaults → Dictation**.

To undo links from this bootstrap:

```bash
stow --delete --dir="$HOME/src/dotfiles" --target="$HOME" \
  herdr nvim starship yazi gh-manager omarchy-bash omarchy-desktop omarchy-handy
```

Then restore the desired files and desktop preferences from the printed backup directory. Restore
the backed-up `.bashrc`, or remove its overlay source line if you have since
made other edits. Installed packages remain installed.

## Validation

```bash
python3 -m unittest discover -s setup -p 'test_omarchy_*.py'
```

Tests use temporary home directories, real GNU Stow, and stubbed package
installers. On macOS, the fixtures emulate the Linux platform for bootstrap
tests. The MIME association test uses real `xdg-mime` and is skipped when it is
unavailable; the Stow integration tests are skipped when GNU Stow is absent.
Tests do not install packages or change your live defaults. To include macOS
package and skills-setup tests, use `-p 'test_*.py'` instead.
