"""Run with: python3 -m unittest discover -s setup -p 'test_omarchy_*.py'"""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location("bootstrap", Path(__file__).with_name("omarchy_bootstrap.py"))
bootstrap = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bootstrap)


@unittest.skipUnless(shutil.which("stow"), "GNU Stow is required for integration tests")
class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / "home with spaces"
        self.home.mkdir()
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.omarchy = self.base / "omarchy"
        (self.omarchy / "default/bash").mkdir(parents=True)
        (self.omarchy / "default/bash/rc").write_text("")
        self.original = '# Local customization\nsource "$OMARCHY_PATH/default/bash/rc"\nalias mine=true\n'
        (self.omarchy / "default/bashrc").write_text(self.original)
        (self.home / ".bashrc").write_text(self.original)
        (self.home / ".config/ghostty").mkdir(parents=True)
        (self.home / ".config/xdg-terminals.list").write_text(bootstrap.TERMINAL_ID + "\n")
        self.command("xdg-settings", 'if [[ "$1" == get ]]; then echo zen.desktop; else exit 98; fi')
        self.command("xdg-mime", 'case "$3" in\n'
                     'x-scheme-handler/keeper) echo keeperpasswordmanager.desktop ;;\n'
                     'x-scheme-handler/steam*) echo steam.desktop ;;\n'
                     '*) echo zen.desktop ;;\nesac')
        # Package managers are stubbed; all file linking uses the real GNU Stow.
        self.command("pacman", "exit 0")
        self.command("omarchy", "echo unexpected-package-install >&2; exit 99")
        self.command("herdr", "exit 0")
        self.command("hyprctl", "exit 0")
        self.command("git", 'case "$2" in *ozdil.security-sentinel) echo https://github.com/ozdil/omarchy-security-sentinel.git ;; *air.workspaces) echo https://github.com/airenare/omarchy-workspaces-by-monitor.git ;; *n0d3x.input-language) echo https://github.com/n0d3xt-max/n0d3x.input-language.git ;; *) echo https://github.com/rosakodu/omarchy-dock.git ;; esac')
        (self.omarchy / "config/hypr").mkdir(parents=True)
        for name in ("bindings.lua", "monitors.lua"):
            (self.omarchy / "config/hypr" / name).write_text("-- defaults\n")
        plugin = self.home / ".config/omarchy/plugins/rosakodu.dock"
        plugin.mkdir(parents=True)
        (plugin / "manifest.json").write_text('{"id":"rosakodu.dock"}')
        plugin = self.home / '.config/omarchy/plugins/n0d3x.input-language'
        plugin.mkdir()
        (plugin / 'manifest.json').write_text('{"id":"n0d3x.input-language"}')
        plugin = self.home / '.config/omarchy/plugins/air.workspaces'
        plugin.mkdir()
        (plugin / 'manifest.json').write_text('{"id":"air.workspaces"}')
        plugin = self.home / '.config/omarchy/plugins/ozdil.security-sentinel'
        plugin.mkdir()
        (plugin / 'manifest.json').write_text('{"id":"ozdil.security-sentinel"}')
        (plugin / 'sentinel-engine').write_text('built engine')
        (plugin / 'sentinel-engine').chmod(0o755)
        (self.home / ".config/omarchy/shell.json").write_text(json.dumps({
            "version": 1, "bar": {"layout": {"left": [{"id": "air.workspaces"}], "right": [{"id": "ozdil.security-sentinel"}, {"id": "n0d3x.input-language"}], "center": [
                {"id": "rosakodu.dock"}, {"id": "omarchy.system-update"}]}}}))
        self.env = {**os.environ, "HOME": str(self.home), "OMARCHY_PATH": str(self.omarchy),
                    "PATH": f"{self.bin}:{os.environ['PATH']}",
                    "XDG_CONFIG_HOME": str(self.home / ".config"),
                    "XDG_STATE_HOME": str(self.home / ".local/state")}

    def command(self, name, body):
        if name == "omarchy":
            body = 'case "$*" in "plugin validate "*) exit 0 ;; "plugin list --json") echo \'[{"id":"rosakodu.dock","enabled":true},{"id":"n0d3x.input-language","enabled":true},{"id":"air.workspaces","enabled":true},{"id":"ozdil.security-sentinel","enabled":true}]\'; exit 0 ;; esac\n' + body
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def invoke(self, *args):
        return subprocess.run(["bash", str(bootstrap.REPO / "setup/bootstrap-omarchy.sh"), *args],
                              env=self.env, text=True, capture_output=True)

    def snapshot(self):
        return {str(p.relative_to(self.home)): (os.readlink(p) if p.is_symlink() else
                p.read_bytes() if p.is_file() else None) for p in self.home.rglob("*")}

    def test_dry_run_is_read_only_with_conflicts(self):
        config = self.home / ".config/starship.toml"
        config.parent.mkdir(exist_ok=True)
        config.write_text("old config")
        before = self.snapshot()
        result = self.invoke("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Conflict (backup required)", result.stdout)
        self.assertEqual(before, self.snapshot())

    def test_conflict_requires_explicit_backup_before_any_change(self):
        config = self.home / ".config/starship.toml"
        config.parent.mkdir(exist_ok=True)
        config.write_text("old config")
        before = self.snapshot()
        result = self.invoke("--yes")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(before, self.snapshot())

    def test_install_backups_idempotence_and_desktop_preservation(self):
        config = self.home / ".config/starship.toml"
        config.parent.mkdir(exist_ok=True)
        config.write_text("old config")
        ghostty = self.home / ".config/ghostty/config"
        ghostty.parent.mkdir(exist_ok=True)
        ghostty.write_text("keybind = super+c=copy_to_clipboard\n")
        hypr = self.home / ".config/hypr/bindings.lua"
        hypr.parent.mkdir()
        hypr.write_text("-- personal bindings\n")
        result = self.invoke("--yes", "--backup-conflicts")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(hypr.read_text().startswith("-- personal bindings\n"))
        self.assertEqual(hypr.read_text().count("-- BEGIN pabu-dotfiles omarchy"), 1)
        self.assertEqual(config.resolve(), bootstrap.REPO / "starship/.config/starship.toml")
        self.assertTrue((self.home / ".bashrc").read_text().startswith(self.original))
        self.assertEqual((self.home / ".bashrc").read_text().count(bootstrap.SOURCE_LINE), 1)
        backups = list((self.home / ".local/state/pabu-dotfiles/backups").iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / ".config/starship.toml").read_text(), "old config")
        self.assertEqual((backups[0] / ".bashrc").read_text(), self.original)
        self.assertEqual(bootstrap.conflicts_for(bootstrap.REPO, self.home), [])
        for _, source, relative in bootstrap.managed_files(bootstrap.REPO):
            self.assertEqual((self.home / relative).resolve(), source.resolve())
        before = self.snapshot()
        result = self.invoke("--yes")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(before, self.snapshot())

    def test_simulation_failure_restores_moved_conflicts(self):
        self.command("stow", "exit 1")
        config = self.home / ".config/starship.toml"
        config.parent.mkdir(exist_ok=True)
        config.write_text("recover me")
        result = self.invoke("--yes", "--backup-conflicts")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(config.read_text(), "recover me")
        self.assertFalse(config.is_symlink())
        self.assertEqual((self.home / ".bashrc").read_text(), self.original)

    def test_existing_nested_readme_is_ignored_by_planner_and_stow(self):
        readme = self.home / ".config/nvim/README.md"
        readme.parent.mkdir(parents=True)
        readme.write_text("Existing Omarchy documentation\n")
        result = self.invoke("--yes")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(readme.read_text(), "Existing Omarchy documentation\n")
        self.assertFalse(readme.is_symlink())
        self.assertEqual(bootstrap.conflicts_for(bootstrap.REPO, self.home), [])

    def test_external_directory_symlink_is_backed_up_without_touching_owner(self):
        external = self.base / "external"
        external.mkdir()
        (external / "config.toml").write_text("external config")
        (self.home / ".config").mkdir(exist_ok=True)
        (self.home / ".config/herdr").symlink_to(external, target_is_directory=True)
        result = self.invoke("--yes", "--backup-conflicts")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((external / "config.toml").read_text(), "external config")
        self.assertFalse((self.home / ".config/herdr").is_symlink())

    def test_symlinked_bashrc_requires_skip_bash(self):
        bashrc = self.home / ".bashrc"
        bashrc.unlink()
        owner = self.base / "owned-bashrc"
        owner.write_text(self.original)
        bashrc.symlink_to(owner)
        self.assertNotEqual(self.invoke("--yes").returncode, 0)
        result = self.invoke("--yes", "--skip-bash")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(bashrc.is_symlink())
        self.assertEqual(owner.read_text(), self.original)

    def test_missing_bashrc_uses_omarchy_template(self):
        (self.home / ".bashrc").unlink()
        result = self.invoke("--yes")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.home / ".bashrc").read_text().startswith(self.original))

    def test_non_omarchy_and_redirected_config_fail_before_changes(self):
        for change in ("bashrc", "config"):
            with self.subTest(change=change):
                if change == "bashrc":
                    (self.home / ".bashrc").write_text("# custom shell\n")
                else:
                    (self.home / ".bashrc").write_text(self.original)
                    self.env["XDG_CONFIG_HOME"] = str(self.base / "elsewhere")
                before = self.snapshot()
                self.assertNotEqual(self.invoke("--yes").returncode, 0)
                self.assertEqual(before, self.snapshot())

    def test_missing_applications_use_omarchy_installers_once(self):
        self.env["TEST_STATE"] = str(self.base / "package-state")
        Path(self.env["TEST_STATE"]).mkdir()
        self.command("yay", "exit 99")
        self.command("pacman", 'case "$2" in\n'
                     'keeper-password-manager|zen-browser-bin|steam|ghostty) [[ -f "$TEST_STATE/$2" ]] ;;\n'
                     '*) exit 0 ;;\nesac')
        self.command("omarchy", 'echo "$*" >> "$TEST_STATE/commands"\n'
                     'case "$*" in\n'
                     '"pkg aur add keeper-password-manager zen-browser-bin") touch "$TEST_STATE/keeper-password-manager" "$TEST_STATE/zen-browser-bin" ;;\n'
                     '"install gaming steam") touch "$TEST_STATE/steam" ;;\n'
                     '"install terminal ghostty") touch "$TEST_STATE/ghostty"; echo com.mitchellh.ghostty.desktop > "$HOME/.config/xdg-terminals.list" ;;\n'
                     '*) exit 99 ;;\nesac')
        before = self.snapshot()
        result = self.invoke("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("install gaming steam", result.stdout)
        self.assertIn("install terminal ghostty", result.stdout)
        self.assertIn("pkg aur add keeper-password-manager zen-browser-bin", result.stdout)
        self.assertEqual(before, self.snapshot())
        self.assertFalse((Path(self.env["TEST_STATE"]) / "commands").exists())
        result = self.invoke("--yes")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        commands = (Path(self.env["TEST_STATE"]) / "commands").read_text()
        self.assertEqual(len(commands.splitlines()), 3)
        result = self.invoke("--yes")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((Path(self.env["TEST_STATE"]) / "commands").read_text(), commands)

    def test_defaults_preserve_unrelated_associations_and_are_backed_up(self):
        # Exercise real xdg-mime with an isolated home and desktop database.
        (self.bin / "xdg-mime").unlink()
        data = self.home / ".local/share"
        apps = data / "applications"
        apps.mkdir(parents=True)
        self.env["XDG_DATA_HOME"] = str(data)
        self.env["XDG_CURRENT_DESKTOP"] = "X-Generic"
        self.env["BROWSER"] = "a-shell-browser-override"
        for desktop in set(bootstrap.MIME_DEFAULTS.values()):
            (apps / desktop).write_text(f"[Desktop Entry]\nName={desktop}\nType=Application\nExec=/usr/bin/true %u\n")
        preferences = self.home / ".config/mimeapps.list"
        preferences.write_text("[Default Applications]\ntext/html=old.desktop\nx-scheme-handler/mailto=mail.desktop\napplication/pdf=reader.desktop\n")
        original = preferences.read_text()
        # xdg-settings is stubbed to avoid dependence on the host desktop backend.
        self.command("xdg-settings", '[[ -z "${BROWSER:-}" ]] || exit 97\n'
                     'if [[ "$1" == get ]]; then xdg-mime query default text/html; '
                     'else xdg-mime default "$3" text/html; fi')
        result = self.invoke("--yes")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for mime, desktop in bootstrap.MIME_DEFAULTS.items():
            current = subprocess.check_output(["xdg-mime", "query", "default", mime], env=self.env, text=True)
            self.assertEqual(current.strip(), desktop)
        self.assertIn("x-scheme-handler/mailto=mail.desktop", preferences.read_text())
        self.assertIn("application/pdf=reader.desktop", preferences.read_text())
        saved = list((self.home / ".local/state/pabu-dotfiles/backups").glob("*/.config/mimeapps.list"))
        self.assertEqual(len(saved), 1)
        self.assertEqual(saved[0].read_text(), original)
        before = self.snapshot()
        result = self.invoke("--yes")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(before, self.snapshot())

    def test_bash_overlay_preserves_yazi_status_and_changes_directory(self):
        destination = self.base / "directory with spaces"
        destination.mkdir()
        self.env["YAZI_DESTINATION"] = str(destination)
        self.command("yazi", 'for argument in "$@"; do case "$argument" in '
                     '--cwd-file=*) printf "%s" "$YAZI_DESTINATION" > "${argument#--cwd-file=}" ;; '
                     'esac; done; exit 7')
        overlay = bootstrap.REPO / "omarchy-bash/.config/pabu-dotfiles/bash.sh"
        result = subprocess.run(["bash", "--noprofile", "--norc", "-ic",
                                 'source "$1"; y; result=$?; printf "%s\\n%s\\n" "$result" "$PWD"',
                                 "bash", str(overlay)], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["7", str(destination)])

    def test_bash_overlay_is_inactive_for_noninteractive_shells(self):
        overlay = bootstrap.REPO / "omarchy-bash/.config/pabu-dotfiles/bash.sh"
        result = subprocess.run(["bash", "--noprofile", "--norc", "-c",
                                 'source "$1"; ! declare -F y; ! alias cls 2>/dev/null',
                                 "bash", str(overlay)], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
