"""Install shared Stow packages without replacing Omarchy's desktop defaults."""

import argparse
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parent.parent
PACKAGES = ("herdr", "nvim", "starship", "yazi", "gh-manager", "omarchy-bash", "omarchy-desktop")
DEPENDENCIES = (
    "git", "stow", "herdr", "starship", "eza", "yazi", "neovim", "ripgrep",
    "fd", "fzf", "lazygit", "cliamp", "ffmpeg", "7zip", "jq", "poppler",
    "zoxide", "resvg", "imagemagick", "tree-sitter-cli",
    "ttf-jetbrains-mono-nerd",
)
SOURCE_LINE = '[[ -r "$HOME/.config/pabu-dotfiles/bash.sh" ]] && source "$HOME/.config/pabu-dotfiles/bash.sh"'
AUR_PACKAGES = ("keeper-password-manager", "zen-browser-bin")
TERMINAL_ID = "com.mitchellh.ghostty.desktop"
MIME_DEFAULTS = {
    "text/html": "zen.desktop",
    "application/xhtml+xml": "zen.desktop",
    "x-scheme-handler/http": "zen.desktop",
    "x-scheme-handler/https": "zen.desktop",
    "x-scheme-handler/keeper": "keeperpasswordmanager.desktop",
    "x-scheme-handler/steam": "steam.desktop",
    "x-scheme-handler/steamlink": "steam.desktop",
}


def installed(package):
    return subprocess.run(["pacman", "-Q", package], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0


def terminal_selected(home):
    path = home / ".config/xdg-terminals.list"
    if not path.exists():
        return False
    entries = [line.strip() for line in path.read_text().splitlines()
               if line.strip() and not line.lstrip().startswith("#")]
    return bool(entries) and entries[0] == TERMINAL_ID


def default_commands():
    # Omarchy's shell exports BROWSER; xdg-settings refuses changes with it set.
    env = {key: value for key, value in os.environ.items() if key != "BROWSER"}
    commands = []
    browser = subprocess.run(["xdg-settings", "get", "default-web-browser"],
                             env=env, text=True, capture_output=True)
    if browser.returncode or browser.stdout.strip() != "zen.desktop":
        commands.append(["xdg-settings", "set", "default-web-browser", "zen.desktop"])
    for mime, desktop in MIME_DEFAULTS.items():
        current = subprocess.run(["xdg-mime", "query", "default", mime],
                                 env=env, text=True, capture_output=True)
        if current.returncode or current.stdout.strip() != desktop:
            commands.append(["xdg-mime", "default", desktop, mime])
    return commands, env


def run(*args, **kwargs):
    print("  + " + shlex.join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), check=True, **kwargs)


def exists(path):
    return path.exists() or path.is_symlink()


def ignore_patterns(repo):
    # A repository-root .stow-local-ignore is not inherited by its packages.
    # Pass these patterns explicitly to Stow and use the same ones for planning.
    rules = []
    for line in (repo / ".stow-local-ignore").read_text().splitlines():
        line = re.split(r"(?<!\\)#", line, maxsplit=1)[0].strip()
        if line:
            if line.startswith("^/"):
                line = "^" + line[2:]
            rules.append(r"(^|/)(?:" + line + r")($|/)")
    return rules


def managed_files(repo, packages=PACKAGES):
    rules = [re.compile(pattern) for pattern in ignore_patterns(repo)]
    for package in packages:
        root = repo / package
        if not root.is_dir():
            raise RuntimeError(f"Missing Stow package: {root}")
        for source in sorted(root.rglob("*")):
            relative = source.relative_to(root)
            if any(rule.search(relative.as_posix()) for rule in rules):
                continue
            if source.is_file() or source.is_symlink():
                yield root, source, relative


def conflicts_for(repo, home, packages=PACKAGES):
    conflicts = set()
    for root, source, relative in managed_files(repo, packages):
        target = home
        for index, part in enumerate(relative.parts):
            target = target / part
            corresponding = root.joinpath(*relative.parts[:index + 1])
            if target.is_symlink():
                if target.resolve() != corresponding.resolve():
                    conflicts.add(target)
                break
            if exists(target) and (not target.is_dir() or target == home / relative):
                conflicts.add(target)
                break
    return sorted(p for p in conflicts if not any(parent in conflicts for parent in p.parents))


def bash_content(home, omarchy):
    bashrc = home / ".bashrc"
    if bashrc.is_symlink():
        raise RuntimeError("~/.bashrc is a symlink. Add the documented Bash source line to its owner, then rerun with --skip-bash.")
    old = bashrc.read_text() if bashrc.exists() else (omarchy / "default/bashrc").read_text()
    if SOURCE_LINE in old.splitlines():
        return None
    if "default/bash/rc" not in old:
        raise RuntimeError("~/.bashrc does not source Omarchy defaults. Review it before adding the documented overlay, or use --skip-bash.")
    return old.rstrip("\n") + "\n\n# Pabu's shared shell customizations (after Omarchy defaults).\n" + SOURCE_LINE + "\n"


def confirm(question):
    if not sys.stdin.isatty():
        raise RuntimeError("Run interactively, or use --yes (and --backup-conflicts for replacements).")
    return input(question + " [y/N] ").strip().lower() in ("y", "yes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Show changes without writing or installing")
    parser.add_argument("--yes", action="store_true", help="Accept package installation and Bash overlay setup")
    parser.add_argument("--backup-conflicts", action="store_true", help="Back up conflicting Stow targets before replacing them")
    parser.add_argument("--skip-bash", action="store_true", help="Link the overlay without editing ~/.bashrc")
    args = parser.parse_args()
    home = Path.home()
    omarchy = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))
    if sys.platform != "linux" or not (omarchy / "default/bash/rc").is_file():
        raise RuntimeError("This bootstrap requires an existing Omarchy installation.")
    if os.geteuid() == 0:
        raise RuntimeError("Run as your desktop user, not root; package installation requests sudo itself.")
    if os.environ.get("XDG_CONFIG_HOME", str(home / ".config")) != str(home / ".config"):
        raise RuntimeError("These Stow packages require XDG_CONFIG_HOME=~/.config.")
    if (home / ".config").is_symlink() or (exists(home / ".config") and not (home / ".config").is_dir()):
        raise RuntimeError("~/.config must be a real directory; refusing to replace or traverse a redirected config root.")
    for command in ("pacman", "omarchy", "bash", "xdg-settings", "xdg-mime"):
        if not shutil.which(command):
            raise RuntimeError(f"Required command is missing: {command}")

    from omarchy_desktop import Desktop
    desktop = Desktop(REPO, home)
    desktop.preflight(live=not args.dry_run)
    conflicts = conflicts_for(REPO, home)
    bash_text = None if args.skip_bash else bash_content(home, omarchy)
    dependencies = list(DEPENDENCIES)
    if any(plan['build'] for plan in desktop.plugin_plans) and not shutil.which("cargo"):
        dependencies.append("rust")
    if any(plugin['id'] == "ozdil.security-sentinel" for plugin in desktop.plugins):
        dependencies += ["libnotify", "networkmanager", "zenity", "pacman-contrib"]
    # Omarchy manages development runtimes with mise; keep an available Node.
    if not shutil.which("node"):
        dependencies += ["nodejs", "npm"]
    missing = [pkg for pkg in dependencies if not installed(pkg)]
    missing_aur = [pkg for pkg in AUR_PACKAGES if not installed(pkg)]
    applications = []
    if missing_aur:
        if not shutil.which("yay"):
            raise RuntimeError("Omarchy's yay helper is required to install Keeper and Zen.")
        applications.append(["omarchy", "pkg", "aur", "add", *missing_aur])
    if not installed("steam"):
        applications.append(["omarchy", "install", "gaming", "steam"])
    terminal_change = (not installed("ghostty") or not (home / ".config/ghostty").exists()
                       or not terminal_selected(home))
    defaults, desktop_env = default_commands()
    if terminal_change and (home / ".config/xdg-terminals.list").is_symlink():
        raise RuntimeError("xdg-terminals.list is a symlink; refusing to overwrite its owner.")
    mime_preferences = sorted((home / ".config").glob("*mimeapps.list"))
    if defaults:
        for path in mime_preferences:
            if path.is_symlink():
                raise RuntimeError(f"Refusing to overwrite a symlinked MIME preferences file: {path}")
    print(f"Repository: {REPO}\nTarget: {home}")
    print("Stow packages: " + " ".join(PACKAGES))
    print("Missing system packages: " + (" ".join(missing) or "none"))
    print("Missing AUR packages: " + (" ".join(missing_aur) or "none"))
    print("Bash: " + ("append overlay source (with backup)" if bash_text is not None else "no edit"))
    print("Ghostty shortcuts preserved; Hyprland desktop overlay managed through hooks")
    print("Defaults: Zen browser, Ghostty terminal, Keeper and Steam URI handlers")
    for command in applications + ([["omarchy", "install", "terminal", "ghostty"]] if terminal_change else []) + defaults:
        print("Planned: " + shlex.join(command))
    for path in conflicts:
        print(f"Conflict (backup required): {path}")
    if args.dry_run:
        if missing:
            print("Would run: " + shlex.join(["omarchy", "pkg", "add", *missing]))
        print("Dry run complete; no files, packages, or Git state changed.")
        return
    if conflicts and not args.backup_conflicts:
        if args.yes or not confirm("Back up the listed conflicts and replace them with managed links?"):
            raise RuntimeError("Conflicts require --backup-conflicts; nothing changed.")
    if not args.yes and not confirm("Apply this Omarchy setup?"):
        raise RuntimeError("Setup declined; nothing changed.")
    if missing:
        run("omarchy", "pkg", "add", *missing)
    for command in applications:
        run(*command)
    run("bash", "-n", REPO / "omarchy-bash/.config/pabu-dotfiles/bash.sh")
    run("herdr", "config", "check", env={**os.environ, "HERDR_CONFIG_PATH": str(REPO / "herdr/.config/herdr/config.toml")})

    backup = None

    def backup_path(path, move=False):
        nonlocal backup
        if backup is None:
            base = Path(os.environ.get("XDG_STATE_HOME", str(home / ".local/state"))) / "pabu-dotfiles/backups"
            base.mkdir(parents=True, exist_ok=True)
            backup = Path(tempfile.mkdtemp(prefix="omarchy-", dir=base))
            print(f"Backups: {backup}", flush=True)
        destination = backup / path.relative_to(home)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if move:
            shutil.move(str(path), str(destination))
        else:
            shutil.copy2(path, destination, follow_symlinks=False)
        return destination

    # Omarchy seeds its own Ghostty config only when the directory is absent.
    # Its terminal installer also sets xdg-terminal-exec's preference file.
    if terminal_change:
        preferences = home / ".config/xdg-terminals.list"
        if preferences.exists():
            backup_path(preferences)
        run("omarchy", "install", "terminal", "ghostty")
        if not installed("ghostty") or not terminal_selected(home):
            raise RuntimeError("Ghostty installation or terminal default verification failed.")
    if defaults:
        for path in mime_preferences:
            backup_path(path)
        for command in defaults:
            run(*command, env=desktop_env)
        remaining, _ = default_commands()
        if remaining:
            raise RuntimeError("Desktop default verification failed; see the printed preference backups.")

    moved = []
    stow = ["stow", "--no-folding", "--restow", f"--dir={REPO}", f"--target={home}",
            *(f"--ignore={pattern}" for pattern in ignore_patterns(REPO)), *PACKAGES]
    try:
        for path in conflicts:
            moved.append((path, backup_path(path, move=True)))
        run(*stow, "--simulate", "--verbose=1")
    except BaseException:
        for original, saved in reversed(moved):
            shutil.move(str(saved), str(original))
        raise
    # A real Stow failure may leave some links: retain backups for manual recovery.
    run(*stow)
    if bash_text is not None:
        bashrc = home / ".bashrc"
        if bashrc.exists():
            backup_path(bashrc)
        with tempfile.NamedTemporaryFile(mode="w", dir=home, prefix=".bashrc-dotfiles-", delete=False) as output:
            temporary = Path(output.name)
            output.write(bash_text)
        try:
            run("bash", "-n", temporary)
            temporary.chmod(bashrc.stat().st_mode & 0o777 if bashrc.exists() else 0o644)
            temporary.replace(bashrc)
        finally:
            temporary.unlink(missing_ok=True)
    desktop.apply(backup_path)
    run(*stow, "--simulate")
    print("Complete. Open a new Bash shell; use h for Herdr and y for Yazi.")
    print("Neovim installs its plugins on first launch. Existing Herdr sessions were not restarted.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
