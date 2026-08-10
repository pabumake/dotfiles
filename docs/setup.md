---
layout: default
title: Setup, Updates, and Stow
---

# Setup, updates, and Stow

The bootstrap supports macOS on Apple Silicon and Intel. The same entry point
can prepare a new Mac or update an existing dotfiles checkout.

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
| `--with-hushlogin` | Explicitly create `~/.hushlogin` |
| `--repo-dir PATH` | Override `~/Documents/dotfiles` |
| `--help` | Print usage and safety rules |

Local examples:

```bash
cd ~/Documents/dotfiles
./setup/bootstrap.sh --dry-run
./setup/bootstrap.sh --upgrade
./setup/bootstrap.sh --yes --backup-conflicts
```

`--yes` does not silently replace existing configs. When conflicts exist it
also requires `--backup-conflicts`; otherwise the run stops safely.

## What gets installed

The committed `Brewfile` is the source of truth.

### Taps

```text
nikitabobko/tap
FelixKratz/formulae
```

### Formulae

```text
git stow starship eza herdr borders neovim ripgrep fd fzf lazygit tree-sitter node
```

### Casks

```text
ghostty aerospace font-jetbrains-mono-nerd-font
```

Normal runs use Homebrew Bundle's install-only mode. Existing packages are not
upgraded unless `--upgrade` is supplied, unlisted packages are never removed,
and `brew bundle cleanup` is never used.

JankyBorders comes from a third-party tap. On Homebrew versions that enforce
tap trust, the bootstrap explicitly trusts only
`felixkratz/formulae/borders`; it does not trust every formula in the tap.

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
aerospace borders ghostty herdr nvim starship zsh gh-manager
```

Each package repeats the path it creates below the home directory:

```text
~/.aerospace.toml             → aerospace/.aerospace.toml
~/.config/borders/bordersrc   → borders/.config/borders/bordersrc
~/.config/ghostty/            → ghostty/.config/ghostty/
~/.config/herdr/config.toml   → herdr/.config/herdr/config.toml
~/.config/nvim/               → nvim/.config/nvim/
~/.config/starship.toml       → starship/.config/starship.toml
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

The bootstrap validates Zsh, JankyBorders, and, when available, the Ghostty,
Herdr, and AeroSpace configs. It refreshes an existing JankyBorders process or
starts one when AeroSpace is already running. Otherwise, AeroSpace starts it at
the next launch.

After the first installation:

1. Open a new shell.
2. Reload or restart Ghostty.
3. Start Herdr and verify `Control + B`, then `?` opens help.
4. Start AeroSpace and grant **System Settings → Privacy & Security → Accessibility** permission.
5. Move focus between windows and verify the focused window receives a subtle blue border.
6. Start Neovim once so LazyVim can install its pinned plugins.

## Troubleshooting

- **Homebrew:** rerun the official installer or complete the Command Line Tools prompt.
- **Repository:** resolve local changes or divergence manually, then rerun; never reset merely for the bootstrap.
- **Packages:** rerun `brew bundle check --verbose --file=~/Documents/dotfiles/Brewfile`.
- **Stow:** inspect the printed targets and the timestamped conflict manifest.
- **JankyBorders:** run `~/.config/borders/bordersrc` to refresh a running process, or restart AeroSpace.
- **Application validation:** run the commands in the [AeroSpace](aerospace.md) or [terminal](terminal.md) guides.

## Enable GitHub Pages

The repository is configured as a Jekyll site in `/docs`. After pushing:

1. Open the repository on GitHub.
2. Go to **Settings → Pages**.
3. Select **Deploy from a branch**.
4. Select `main` and `/docs`, then save.

The resulting site is <https://pabumake.github.io/dotfiles/>.
