"""Small Hyprland hooks and explicit synchronization of writable dock files."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parent.parent
RELATIVE = Path('.config/pabu-dotfiles/omarchy')
DOCK_FILES = ('dock-settings.json', 'dock-pinned.json')
BEGIN = '-- BEGIN pabu-dotfiles omarchy'
END = '-- END pabu-dotfiles omarchy'


def command(*args):
    result = subprocess.run(args, text=True, capture_output=True, check=True)
    return result.stdout.strip()


def read_json(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise RuntimeError(f'Expected a JSON object: {path}')
    if path.name == 'dock-pinned.json' and not isinstance(value.get('pinned'), list):
        raise RuntimeError(f'Expected a pinned array: {path}')
    return value


def safe_target(path, home):
    # Do not follow runtime config symlinks into another owner's configuration.
    for parent in (path, *path.parents):
        if parent == home:
            break
        if parent.is_symlink():
            raise RuntimeError(f'Refusing redirected runtime configuration: {parent}')
    if path.exists() and not path.is_file():
        raise RuntimeError(f'Expected a regular file: {path}')


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        output.write(text)
    try:
        temporary.chmod(path.stat().st_mode & 0o777 if path.exists() else 0o644)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


class Backups:
    def __init__(self, home):
        self.home = home
        self.directory = None

    def __call__(self, path, move=False):
        if not path.exists() and not path.is_symlink():
            return
        if self.directory is None:
            base = Path(os.environ.get('XDG_STATE_HOME', str(self.home / '.local/state'))) / 'pabu-dotfiles/backups'
            base.mkdir(parents=True, exist_ok=True)
            self.directory = Path(tempfile.mkdtemp(prefix='omarchy-desktop-', dir=base))
            print(f'Backups: {self.directory}')
        try:
            relative = path.relative_to(self.home)
        except ValueError:
            relative = Path('repository') / path.name
        target = self.directory / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() and not target.is_symlink():
            if move:
                shutil.move(str(path), str(target))
            else:
                shutil.copy2(path, target, follow_symlinks=False)


def hook_content(old, name):
    if old.count(BEGIN) != old.count(END) or old.count(BEGIN) > 1:
        raise RuntimeError(f'Malformed managed hook in {name}')
    if BEGIN in old:
        pattern = re.escape(BEGIN) + r'\n.*?' + re.escape(END) + r'\n?'
        old, count = re.subn(pattern, '', old, flags=re.S)
        if count != 1:
            raise RuntimeError(f'Malformed managed hook in {name}')
    if name == 'bindings.lua':
        # Only remove the exact binding previously installed on this desktop.
        binding = ('hl.unbind("SUPER + SHIFT + D")\n'
                   'o.bind("SUPER + SHIFT + D", "Dock", "omarchy-shell -q rosakodu.dock toggleReveal")')
        old = old.replace(binding, '')
        old = old.replace('-- Omarchy Dock - omarchy plugin add https://github.com/rosakodu/omarchy-dock.git --enable\n', '')
        old = old.replace('-- Omarchy assigns this shortcut to Docker by default, so replace it explicitly.\n', '')
    else:
        # Migrate the two known blocks, without matching other monitor rules.
        for output, mode, position in [('DP-2', '3840x2160@240.02Hz', '0x0'),
                                       ('DP-3', '3440x1440@120.00Hz', '160x-1152')]:
            pattern = (r'(?m)^hl\.monitor\(\{\s*output\s*=\s*"' + re.escape(output)
                       + r'",\s*mode\s*=\s*"' + re.escape(mode)
                       + r'",\s*position\s*=\s*"' + re.escape(position)
                       + r'",\s*scale\s*=\s*omarchy_monitor_scale\s*\}\)\n?')
            old = re.sub(pattern, '', old)
        old = re.sub(r'(?m)^local omarchy_gdk_scale = 1$', 'local omarchy_gdk_scale = 2', old)
        old = re.sub(r'(?m)^local omarchy_monitor_scale = 1\.25$', 'local omarchy_monitor_scale = "auto"', old)
    hook = f'dofile(os.getenv("HOME") .. "/{RELATIVE.as_posix()}/{name}")'
    return old.rstrip('\n') + f'\n\n{BEGIN}\n{hook}\n{END}\n'


class Desktop:
    def __init__(self, repo=REPO, home=None):
        self.repo = repo
        self.home = home or Path.home()
        self.source = repo / 'omarchy-desktop' / RELATIVE
        self.omarchy = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy'))
        self.edits = []

    def preflight(self, live=True):
        if os.environ.get('XDG_CONFIG_HOME', str(self.home / '.config')) != str(self.home / '.config'):
            raise RuntimeError('Desktop setup requires XDG_CONFIG_HOME=~/.config.')
        self.plugin = read_json(self.source / 'plugins.json')
        if self.plugin.get('id') != 'rosakodu.dock' or self.plugin.get('section') not in ('left', 'center', 'right'):
            raise RuntimeError('Expected rosakodu.dock metadata with a valid bar section.')
        if not isinstance(self.plugin.get('url'), str) or not self.plugin['url'].startswith('https://'):
            raise RuntimeError('Expected an HTTPS plugin repository URL.')
        self.edits = []
        for name in ('bindings.lua', 'monitors.lua'):
            target = self.home / '.config/hypr' / name
            safe_target(target, self.home)
            old = target.read_text() if target.exists() else (self.omarchy / 'config/hypr' / name).read_text()
            new = hook_content(old, name)
            if not target.exists() or new != old:
                self.edits.append((target, new))
        for name in DOCK_FILES:
            value = read_json(self.source / name)
            target = self.home / '.config/omarchy' / name
            safe_target(target, self.home)
            if not target.exists() or read_json(target) != value:
                self.edits.append((target, json.dumps(value, indent=2) + '\n'))
        self.shell_path = self.home / '.config/omarchy/shell.json'
        safe_target(self.shell_path, self.home)
        self.shell = read_json(self.shell_path if self.shell_path.exists() else self.omarchy / 'config/omarchy/shell.json')
        if self.shell.get('version') != 1 or not isinstance(self.shell.get('bar', {}).get('layout'), dict):
            raise RuntimeError('Unsupported Omarchy shell configuration.')
        for section in ('left', 'center', 'right'):
            entries = self.shell['bar']['layout'].get(section)
            if not isinstance(entries, list) or any(not isinstance(entry, dict) for entry in entries):
                raise RuntimeError(f'Invalid bar layout: {section}')
        plugin_dir = self.home / '.config/omarchy/plugins' / self.plugin['id']
        self.install = not (plugin_dir.exists() or plugin_dir.is_symlink())
        if not self.install:
            manifest = read_json(plugin_dir / 'manifest.json')
            if manifest.get('id') != self.plugin['id']:
                raise RuntimeError(f'Unexpected plugin identity: {plugin_dir}')
            origin = command('git', '-C', str(plugin_dir), 'remote', 'get-url', 'origin')
            if origin.removesuffix('.git').rstrip('/') != self.plugin['url'].removesuffix('.git').rstrip('/'):
                raise RuntimeError(f'Existing dock has a different origin: {origin}')
            command('omarchy', 'plugin', 'validate', str(plugin_dir))
        self.placement = ['--section', self.plugin['section']]
        entries = self.shell['bar']['layout'][self.plugin['section']]
        anchor = self.plugin.get('before')
        if any(entry.get('id') == anchor for entry in entries):
            self.placement += ['--before', anchor]
        ids = [entry.get('id') for entry in entries]
        occurrences = sum(entry.get('id') == self.plugin['id'] for values in self.shell['bar']['layout'].values() for entry in values)
        desired = [entry for entry in ids if entry != self.plugin['id']]
        index = desired.index(anchor) if anchor in desired else len(desired)
        desired.insert(index, self.plugin['id'])
        self.enable = occurrences != 1 or ids != desired
        if live:
            errors = command('hyprctl', 'configerrors')
            if errors:
                raise RuntimeError(f'Hyprland already reports configuration errors: {errors}')
            # Prove that both session IPC endpoints work before any changes.
            catalog = json.loads(command('omarchy', 'plugin', 'list', '--json'))
            if not isinstance(catalog, list):
                raise RuntimeError('Could not read the live plugin catalog.')
            if not any(p.get('id') == self.plugin['id'] and p.get('enabled') for p in catalog):
                self.enable = True
        for path, _ in self.edits:
            print(f'Desktop: update {path}')
        if self.install:
            print(f'Desktop: install {self.plugin["url"]}')
        if self.enable or self.install:
            print('Desktop: enable dock ' + ' '.join(self.placement))

    def apply(self, backup=None):
        backup = backup or Backups(self.home)
        if self.install:
            print(command('omarchy', 'plugin', 'add', self.plugin['url'], '--yes'))
            manifest = read_json(self.home / '.config/omarchy/plugins' / self.plugin['id'] / 'manifest.json')
            if manifest.get('id') != self.plugin['id']:
                raise RuntimeError('Installed plugin identity does not match metadata.')
        for path, text in self.edits:
            if path.exists():
                backup(path)
            atomic_write(path, text)
        if self.enable or self.install:
            if self.shell_path.exists():
                backup(self.shell_path)
            command('omarchy-shell', 'shell', 'rescanPlugins')
            print(command('omarchy', 'plugin', 'enable', self.plugin['id'], *self.placement))
        command('hyprctl', 'reload')
        errors = command('hyprctl', 'configerrors')
        if errors:
            raise RuntimeError(f'Hyprland configuration errors after apply: {errors}. Restore the printed backups.')
        actual = read_json(self.shell_path)
        entries = actual['bar']['layout'][self.plugin['section']]
        if not any(entry.get('id') == self.plugin['id'] for entry in entries):
            raise RuntimeError('Dock enablement verification failed.')
        catalog = json.loads(command('omarchy', 'plugin', 'list', '--json'))
        if not any(p.get('id') == self.plugin['id'] and p.get('enabled') for p in catalog):
            raise RuntimeError('The running shell does not report the dock as enabled.')
        print('Desktop applied; Hyprland reports no configuration errors and the dock is enabled.')

    def capture(self, dry_run=False):
        edits = []
        for name in DOCK_FILES:
            runtime = self.home / '.config/omarchy' / name
            if not runtime.exists():
                print(f'Capture: {name} is absent; repository unchanged')
                continue
            value = read_json(runtime)
            target = self.source / name
            if read_json(target) != value:
                edits.append((target, json.dumps(value, indent=2) + '\n'))
                print(f'Capture: update {target}')
        if not dry_run:
            backup = Backups(self.home)
            for path, text in edits:
                backup(path)
                atomic_write(path, text)
        print('Capture dry run complete.' if dry_run else 'Capture complete; review the Git diff before committing.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('apply', 'capture-dock'))
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--yes', action='store_true', help='Apply without an interactive confirmation')
    parser.add_argument('--backup-conflicts', action='store_true', help='Allow replacing conflicting Stow targets with backups')
    args = parser.parse_args()
    try:
        desktop = Desktop()
        if args.action == 'capture-dock':
            desktop.capture(args.dry_run)
            return
        import omarchy_bootstrap as bootstrap
        desktop.preflight(live=not args.dry_run)
        conflicts = bootstrap.conflicts_for(REPO, desktop.home, packages=('omarchy-desktop',))
        for path in conflicts:
            print(f'Conflict (backup required): {path}')
        if args.dry_run:
            print('Desktop dry run complete; no changes made.')
            return
        if conflicts and not args.backup_conflicts:
            if args.yes or not bootstrap.confirm('Back up conflicting desktop overlay targets?'):
                raise RuntimeError('Conflicts require --backup-conflicts; nothing changed.')
        if not args.yes and not bootstrap.confirm('Apply the desktop overlay (changed runtime files will be backed up)?'):
            return
        backup = Backups(desktop.home)
        moved = []
        stow = ['stow', '--no-folding', '--restow', f'--dir={REPO}', f'--target={desktop.home}', 'omarchy-desktop']
        try:
            for path in conflicts:
                backup(path, move=True)
                destination = backup.directory / path.relative_to(desktop.home)
                moved.append((path, destination))
            command(*stow, '--simulate')
        except BaseException:
            for path, saved in reversed(moved):
                shutil.move(str(saved), str(path))
            raise
        command(*stow)
        desktop.apply(backup)
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        detail = getattr(error, 'stderr', '') or ''
        print(f'ERROR: {error}\n{detail}', file=sys.stderr)
        sys.exit(1)
