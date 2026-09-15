"""Desktop synchronization tests never contact the live desktop or network."""
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import omarchy_desktop as desktop


class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / 'home'
        self.repo = self.base / 'repo'
        self.home.mkdir()
        shutil.copytree(desktop.REPO / 'omarchy-desktop', self.repo / 'omarchy-desktop')
        self.config = self.home / '.config/omarchy'
        self.config.mkdir(parents=True)
        self.hypr = self.home / '.config/hypr'
        self.hypr.mkdir()
        for name in ('bindings.lua', 'monitors.lua'):
            (self.hypr / name).write_text('-- unrelated customization\n')
        self.shell_path = self.config / 'shell.json'
        self.shell_path.write_text(json.dumps({'version': 1, 'idle': {'lock': 913},
            'bar': {'layout': {'left': [{'id': 'mine'}], 'center': [
                {'id': 'omarchy.system-update'}], 'right': []}}, 'plugins': []}))
        self.env = patch.dict(os.environ, {'XDG_CONFIG_HOME': str(self.home / '.config'),
                                          'XDG_STATE_HOME': str(self.home / '.local/state')})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.calls = []
        self.stub = patch.object(desktop, 'command', side_effect=self.command)
        self.stub.start()
        self.addCleanup(self.stub.stop)
        self.manager = desktop.Desktop(self.repo, self.home)

    def command(self, *args):
        self.calls.append(args)
        if args[:3] == ('omarchy', 'plugin', 'add'):
            plugin = self.config / 'plugins/rosakodu.dock'
            plugin.mkdir(parents=True)
            (plugin / 'manifest.json').write_text('{"id":"rosakodu.dock"}')
        elif args[:3] == ('omarchy', 'plugin', 'enable'):
            shell = json.loads(self.shell_path.read_text())
            layout = shell['bar']['layout']
            for key in layout:
                layout[key] = [entry for entry in layout[key] if entry['id'] != 'rosakodu.dock']
            values = layout['center']
            index = next((i for i, value in enumerate(values) if value['id'] == 'omarchy.system-update'), len(values))
            values.insert(index, {'id': 'rosakodu.dock'})
            self.shell_path.write_text(json.dumps(shell))
        elif args[0] == 'git':
            return 'https://github.com/rosakodu/omarchy-dock.git'
        elif args[:3] == ('omarchy', 'plugin', 'list'):
            return '[{"id":"rosakodu.dock","enabled":true}]'
        return ''

    def snapshot(self):
        return {str(p.relative_to(self.base)): p.read_bytes() for p in self.base.rglob('*') if p.is_file()}

    def test_preflight_is_read_only_and_apply_is_idempotent(self):
        before = self.snapshot()
        self.manager.preflight(live=False)
        self.assertEqual(before, self.snapshot())
        self.assertEqual(self.calls, [])
        self.manager.apply()
        shell = json.loads(self.shell_path.read_text())
        self.assertEqual(shell['idle']['lock'], 913)
        self.assertEqual(shell['bar']['layout']['left'], [{'id': 'mine'}])
        self.assertEqual(shell['bar']['layout']['center'][0]['id'], 'rosakodu.dock')
        self.assertTrue((self.hypr / 'bindings.lua').read_text().startswith('-- unrelated customization\n'))
        before = self.snapshot()
        self.manager.preflight()
        self.manager.apply()
        self.assertEqual(before, self.snapshot())
        installs = [call for call in self.calls if call[:3] == ('omarchy', 'plugin', 'add')]
        self.assertEqual(len(installs), 1)
        self.assertNotIn('--enable', installs[0])

    def test_capture_round_trip_preserves_unknown_fields_and_dry_run(self):
        value = {'visibilityMode': 'hybrid', 'futureOption': {'value': True}}
        pins = {'pinned': [{'id': 'folder', 'apps': ['zen.desktop']}]}
        for name, data in zip(desktop.DOCK_FILES, (value, pins)):
            (self.config / name).write_text(json.dumps(data))
        before = self.snapshot()
        self.manager.capture(dry_run=True)
        self.assertEqual(before, self.snapshot())
        self.manager.capture()
        self.assertEqual(desktop.read_json(self.manager.source / 'dock-settings.json'), value)
        self.assertEqual(desktop.read_json(self.manager.source / 'dock-pinned.json'), pins)
        (self.config / 'dock-settings.json').write_text('{}')
        self.manager.preflight(live=False)
        self.manager.apply()
        self.assertEqual(desktop.read_json(self.config / 'dock-settings.json'), value)

    def test_missing_capture_inputs_leave_repo_unchanged(self):
        before = self.snapshot()
        self.manager.capture()
        self.assertEqual(before, self.snapshot())

    def test_invalid_json_prevents_partial_capture(self):
        (self.config / 'dock-settings.json').write_text('{"new":true}')
        (self.config / 'dock-pinned.json').write_text('{broken')
        before = self.snapshot()
        with self.assertRaises(ValueError):
            self.manager.capture()
        self.assertEqual(before, self.snapshot())

    def test_invalid_source_and_symlinked_runtime_fail_before_mutation(self):
        source = self.manager.source / 'dock-pinned.json'
        source.write_text('{"pinned":false}')
        before = self.snapshot()
        with self.assertRaises(RuntimeError):
            self.manager.preflight(live=False)
        self.assertEqual(before, self.snapshot())
        source.write_text('{"pinned":[]}')
        (self.config / 'dock-pinned.json').symlink_to(source)
        with self.assertRaisesRegex(RuntimeError, 'redirected'):
            self.manager.preflight(live=False)

    def test_missing_session_fails_without_writes(self):
        before = self.snapshot()
        with patch.object(desktop, 'command', side_effect=RuntimeError('IPC unavailable')):
            with self.assertRaisesRegex(RuntimeError, 'IPC unavailable'):
                self.manager.preflight()
        self.assertEqual(before, self.snapshot())

    def test_known_binding_migrates_and_hook_reloads_with_dofile(self):
        binding = (self.manager.source / 'bindings.lua').read_text().split('\n', 1)[1]
        old = '-- keep me\n' + binding
        result = desktop.hook_content(old, 'bindings.lua')
        self.assertNotIn('o.bind(', result)
        self.assertIn('-- keep me', result)
        self.assertIn('dofile(os.getenv("HOME")', result)
        self.assertEqual(result, desktop.hook_content(result, 'bindings.lua'))

    def test_known_monitors_migrate_without_removing_other_rules(self):
        old = '''local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25
hl.monitor({
  output = "DP-2",
  mode = "3840x2160@240.02Hz",
  position= "0x0",
  scale= omarchy_monitor_scale
})
hl.monitor({ output = "HDMI-A-1", mode = "preferred" })
'''
        result = desktop.hook_content(old, 'monitors.lua')
        self.assertNotIn('output = "DP-2"', result)
        self.assertIn('output = "HDMI-A-1"', result)
        self.assertIn('local omarchy_monitor_scale = "auto"', result)
        self.assertEqual(result, desktop.hook_content(result, 'monitors.lua'))

    def test_malformed_hook_is_rejected(self):
        with self.assertRaises(RuntimeError):
            desktop.hook_content(desktop.BEGIN, 'bindings.lua')

    def test_missing_anchor_appends_to_center(self):
        shell = desktop.read_json(self.shell_path)
        shell['bar']['layout']['center'] = [{'id': 'clock'}]
        self.shell_path.write_text(json.dumps(shell))
        self.manager.preflight(live=False)
        self.assertEqual(self.manager.placement, ['--section', 'center'])
        self.manager.apply()
        self.assertEqual(desktop.read_json(self.shell_path)['bar']['layout']['center'][-1]['id'], 'rosakodu.dock')

    def test_reload_errors_are_reported_and_backups_retained(self):
        self.manager.preflight(live=False)
        original = self.command
        with patch.object(desktop, 'command', side_effect=lambda *args:
                          'bad Lua' if args == ('hyprctl', 'configerrors') else original(*args)):
            with self.assertRaisesRegex(RuntimeError, 'bad Lua'):
                self.manager.apply()
        backups = list((self.home / '.local/state/pabu-dotfiles/backups').glob('*/.config/hypr/bindings.lua'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), '-- unrelated customization\n')


if __name__ == '__main__':
    unittest.main()
