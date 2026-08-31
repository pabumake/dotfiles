---
layout: default
title: Setup, Updates, and Stow
---

# Setup, updates, and Stow

The bootstrap supports macOS 15.6 or newer on Apple Silicon and Intel. The same
entry point can prepare a new Mac or update an existing dotfiles checkout.

## One-command setup

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pabumake/dotfiles/main/setup/bootstrap.sh)"
```

The command downloads the current bootstrap from the public repository. The
script prints each phase and asks for confirmation before installing Homebrew,
cloning or fast-forwarding the repository, installing packages, or replacing a
conflicting configuration.

## Inspect before running

```bash
bootstrap_file="$(mktemp /tmp/pabu-dotfiles-bootstrap.XXXXXX)"
curl -fsSL https://raw.githubusercontent.com/pabumake/dotfiles/main/setup/bootstrap.sh -o "$bootstrap_file"
less "$bootstrap_file"
/bin/bash "$bootstrap_file"
```

Remove the temporary file afterward when it is no longer needed.

## Command options

| Option | Behavior |
| --- | --- |
| `--dry-run` | Report every phase without changing files, packages, or Git state |
| `--yes` | Accept ordinary prompts after the plan is printed |
| `--upgrade` | Upgrade declared packages after installing missing ones |
| `--no-repo-update` | Use the current checkout without fetching or pulling |
| `--backup-conflicts` | Permit conflict backups when using `--yes` |
| `--trust-third-party` | Approve the required item-level Homebrew trust entries |
| `--with-hushlogin` | Explicitly create `~/.hushlogin` |
| `--menu-bar-manager M` | Select and remember `hiddenbar`, `ice`, or `none` |
| `--switch-bar-manager` | Reopen the interactive provider selector |
| `--profile-personal` | Enable and remember personal AeroSpace app assignments |
| `--profile-default` | Disable personal AeroSpace app assignments |
| `--repo-dir PATH` | Override `~/Documents/dotfiles` |
| `--help` | Print usage and safety rules |

Local examples:

```bash
cd ~/Documents/dotfiles
./setup/bootstrap.sh --dry-run
./setup/bootstrap.sh --upgrade
./setup/bootstrap.sh --yes --trust-third-party --backup-conflicts
./setup/bootstrap.sh --switch-bar-manager
./setup/bootstrap.sh --profile-personal
```

New installations use the portable `default` profile. A profile selected with
`--profile-personal` or `--profile-default` is stored outside the repository and
preserved by later update runs. The personal profile currently assigns Ghostty,
VSCodium, and Zen Browser to fixed AeroSpace workspaces; see the
[AeroSpace guide](aerospace.md#automatic-application-workspaces).

`--yes` does not silently replace existing configs. When conflicts exist it
also requires `--backup-conflicts`; otherwise the run stops safely.
Likewise, adding third-party Homebrew trust requires `--trust-third-party` when
`--yes` is used. Interactive runs show the missing entries and ask once before
changing Homebrew's trust configuration.

## What gets installed

The committed `Brewfile` is the source of truth.

### Taps

```text
nikitabobko/tap
FelixKratz/formulae
mediosz/tap
bjarneo/cliamp
```

### Formulae

```text
git stow starship eza herdr borders yazi bjarneo/cliamp/cliamp mole ffmpeg-full sevenzip jq poppler zoxide resvg imagemagick-full neovim ripgrep fd fzf lazygit tree-sitter node
```

### Casks

```text
ghostty aerospace swipeaerospace font-jetbrains-mono-nerd-font font-symbols-only-nerd-font
```

On Apple Silicon, bootstrap also installs `vorssaint`. Vorssaint does not ship
an Intel build, so Intel systems skip it.

Hidden Bar or Ice is installed separately after the remembered provider choice
is resolved. Ice uses its Tahoe beta cask on macOS 26+ and its stable cask on
macOS 15. Ice is the default first-run choice; the selector or
`--menu-bar-manager` can choose Hidden Bar or None instead.

Normal runs use Homebrew Bundle's install-only mode. Existing packages are not
upgraded unless `--upgrade` is supplied, and `brew bundle cleanup` is never used.
After Vorssaint is installed on Apple Silicon, bootstrap offers to remove the
exact replaced-cask list: Caffeine, Flameshot, and CaskHub. Interactive runs ask
first; `--yes` accepts this ordinary prompt. Intel systems skip the cleanup
because Vorssaint is unavailable there. Menu-bar providers retain their separate
confirmed removal workflow.

On Homebrew versions that enforce tap trust, bootstrap checks the current trust
configuration and asks before adding any missing entries. Trust is limited to
the five required definitions: `felixkratz/formulae/borders`,
`bjarneo/cliamp/cliamp`, `mediosz/tap/swipeaerospace`,
`nikitabobko/tap/aerospace`, and `chattymin/tap/poke-token-bar`. It never trusts
a complete third-party tap.

JankyBorders comes from a third-party tap. On Homebrew versions that enforce
tap trust, the bootstrap explicitly trusts only
`felixkratz/formulae/borders`; it does not trust every formula in the tap.
After Stow links its configuration, bootstrap enables the formula's per-user
Homebrew service. The service starts at login and uses launchd `KeepAlive` to
recover from an unexpected process exit.

SwipeAeroSpace comes from its project's `mediosz/tap` Homebrew tap. Bootstrap
installs the cask, configures its three-finger workspace gesture through the
separate `scripts/trackpad-gestures.sh` helper, and starts it with AeroSpace.
On Homebrew versions that enforce tap trust, bootstrap trusts only
`mediosz/tap/swipeaerospace`, not every cask in the tap.

AeroSpace receives the same item-level treatment: bootstrap trusts only the
`nikitabobko/tap/aerospace` cask.

PokeTokenBar comes from the `chattymin/tap` Homebrew tap. Bootstrap trusts only
the `chattymin/tap/poke-token-bar` cask.

Cliamp comes from the `bjarneo/cliamp` tap. Bootstrap trusts only the
`bjarneo/cliamp/cliamp` formula. Its default Homebrew installation also installs
the formula's runtime dependencies.

Vorssaint comes from Homebrew's official cask catalog, so it does not need a
third-party trust entry. The cask requires Apple Silicon and is skipped on
Intel systems.

### Vorssaint settings

Vorssaint 3.3.2 can export a portable settings plist from **Settings →
Advanced → Export Settings** and restore it through **Import Settings** on
another Mac. Its supported export excludes permissions, clipboard history,
device-specific state, run history, and file access grants. macOS permissions
must therefore be granted separately on every device.

Vorssaint does not provide command-line settings export or import. Bootstrap
must not substitute a raw `defaults import`, which bypasses Vorssaint's key and
type validation and can overwrite local state. Keep an official export at
`vorssaint/settings.plist` only after checking it for scratchpad text, snippets,
saved links, and other personal configuration. Bootstrap validates and reports
that file, but Vorssaint must import it after the app is installed.

The implementation research and upstream source references are in
[Vorssaint settings portability](research/vorssaint-settings-portability.md).

Mole comes from Homebrew's official formula catalog, so it does not need a
third-party tap or trust entry.

`gh-manager` remains config-only. Its Stow package is linked, but the bootstrap
does not install its binary or GitHub CLI.

## Homebrew bootstrap

The script checks `PATH`, `/opt/homebrew/bin/brew`, and
`/usr/local/bin/brew`. If Homebrew is absent, it displays and downloads the
official installer from:

<https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh>

The Homebrew installer may install Apple's Command Line Tools and request
administrator authentication. Afterward, `brew shellenv` configures the current
process. The managed Zsh config supports both Apple Silicon and Intel prefixes.

## Repository update rules

The default checkout is `~/Documents/dotfiles` and fresh installations clone
<https://github.com/pabumake/dotfiles.git>.

| Repository state | Bootstrap behavior |
| --- | --- |
| Missing | Explain and confirm, then clone over HTTPS |
| Clean and current | Continue without changing Git history |
| Clean and behind | Show incoming commits/files, then offer a fast-forward |
| Clean and ahead | Keep local commits and continue |
| Dirty | Show `git status`; never fetch, reset, or stash |
| Diverged | Never merge automatically; offer to use the current checkout |
| Non-`main` branch | Preserve the branch and offer to skip repository update |

Automated runs stop on dirty, divergent, or non-`main` checkouts unless
`--no-repo-update` was explicitly supplied.

## Stow packages

```text
aerospace borders ghostty herdr nvim starship yazi zsh gh-manager
```

Each package repeats the path it creates below the home directory:

```text
~/.aerospace.toml             → aerospace/.aerospace.toml
~/.config/borders/bordersrc   → borders/.config/borders/bordersrc
~/.config/ghostty/            → ghostty/.config/ghostty/
~/.config/herdr/config.toml   → herdr/.config/herdr/config.toml
~/.config/nvim/               → nvim/.config/nvim/
~/.config/starship.toml       → starship/.config/starship.toml
~/.config/yazi/yazi.toml      → yazi/.config/yazi/yazi.toml
~/.config/yazi/theme.toml     → yazi/.config/yazi/theme.toml
```

Herdr runtime logs, sockets, and session state remain ordinary files in
`~/.config/herdr`; Stow manages only `config.toml` there.

The bootstrap inventories targets before running `stow --restow`. Correct links
into this repository are treated as managed. Every run performs a complete
Stow simulation before applying changes.

## Existing config conflicts

Real files and links pointing outside this repository are listed before they
are changed. If backup is approved, the original paths are moved beneath:

```text
~/.local/state/pabu-dotfiles/backups/YYYYMMDD-HHMMSS/
```

The home-relative directory structure is retained and `manifest.txt` records
each source and backup destination. If the post-backup Stow simulation fails,
the bootstrap restores the moved paths automatically.

To restore a backed-up file manually:

```bash
backup_dir="$HOME/.local/state/pabu-dotfiles/backups/YYYYMMDD-HHMMSS"
cp "$backup_dir/.config/example/config.toml" "$HOME/.config/example/config.toml"
```

Review `manifest.txt` first and remove the corresponding Stow link before
restoring a file over it.

## Optional login-message suppression

The bootstrap leaves the macOS last-login message unchanged. To suppress it:

```bash
./setup/bootstrap.sh --with-hushlogin
```

Undo it with:

```bash
rm "$HOME/.hushlogin"
```

## Validation and post-install steps

The bootstrap validates Zsh, JankyBorders, the selected menu-bar manager, and,
when available, the Ghostty, Herdr, and AeroSpace configs. JankyBorders setup is
idempotent: an existing healthy service is retained and refreshed, while an old
unmanaged process is stopped gracefully and replaced by the login service.

Service controls are kept separate from bootstrap for recovery and diagnostics:

```bash
cd ~/Documents/dotfiles
./scripts/borders-service.sh status
./scripts/borders-service.sh restart
./scripts/borders-service.sh disable
./scripts/borders-service.sh enable
```

Disabling the service unregisters it from login but retains the Stow-managed
configuration. Service logs are stored at
`$(brew --prefix)/var/log/borders/`.

After the first installation:

1. Open a new shell.
2. Run `y`, navigate to another directory, and quit with `q` to adopt that directory in the shell.
3. Reload or restart Ghostty.
4. Start Herdr and verify `Control + B`, then `?` opens help.
5. Start AeroSpace and grant **System Settings → Privacy & Security → Accessibility** permission.
6. Grant SwipeAeroSpace Accessibility permission in the same settings panel.
7. Swipe horizontally with three fingers and verify it moves between occupied AeroSpace workspaces.
8. Swipe upward with three fingers and verify neither a SwipeAeroSpace workspace
   overview nor the macOS Mission Control overlay appears.
9. Move focus between windows and verify the focused window receives a subtle blue border.
10. Arrange menu-bar icons around the selected provider with `Command (⌘) + drag`.
11. For Ice, grant Accessibility and enable **Launch at login** in its settings.
12. Start Neovim once so LazyVim can install its pinned plugins.

On a fresh setup, bootstrap imports the selected provider's tracked baseline
only when no preferences exist. Later runs preserve live settings. Switching,
manual exports, imports, and recovery remain separate from Stow; see
[Menu-bar icon management](menubar.md#manual-exports-and-imports).

### Trackpad gesture recovery

Gesture preferences are deliberately managed by a separate helper rather than
Stow. Its interface is:

```bash
cd ~/Documents/dotfiles
./scripts/trackpad-gestures.sh status
./scripts/trackpad-gestures.sh enable --dry-run
./scripts/trackpad-gestures.sh restore --dry-run
```

The first real `enable` records the original values of only the affected
trackpad, Mission Control, and SwipeAeroSpace keys at
`~/.local/state/pabu-dotfiles/backups/trackpad-gestures/original.tsv`. Later
enables never replace that baseline. A real `restore` restores those values,
marks the integration disabled, restarts Dock, and quits SwipeAeroSpace. The
backup is retained so the operation remains auditable and repeatable.

To remove the application after restoring the native preferences:

```bash
brew uninstall --cask swipeaerospace
brew untap mediosz/tap
```

Only untap `mediosz/tap` when no other installed cask uses it. A later bootstrap
will reinstall SwipeAeroSpace because gestures are part of every managed setup.

## Troubleshooting

- **Homebrew:** rerun the official installer or complete the Command Line Tools prompt.
- **Repository:** resolve local changes or divergence manually, then rerun; never reset merely for the bootstrap.
- **Packages:** rerun `brew bundle check --verbose --file=~/Documents/dotfiles/Brewfile`.
- **Stow:** inspect the printed targets and the timestamped conflict manifest.
- **JankyBorders:** run `./scripts/borders-service.sh status`, then `restart`; inspect `$(brew --prefix)/var/log/borders/borders.err.log` if validation still fails.
- **Trackpad gestures:** run `./scripts/trackpad-gestures.sh status`; confirm SwipeAeroSpace has Accessibility permission.
- **Menu-bar manager:** use `--switch-bar-manager` to change providers; backups are recorded before removal.
- **Application validation:** run the commands in the [AeroSpace](aerospace.md) or [terminal](terminal.md) guides.

## Enable GitHub Pages

The repository is configured as a Jekyll site in `/docs`. After pushing:

1. Open the repository on GitHub.
2. Go to **Settings → Pages**.
3. Select **Deploy from a branch**.
4. Select `main` and `/docs`, then save.

The resulting site is <https://pabumake.github.io/dotfiles/>.
