"""Exercise bootstrap's package phases with an isolated home and a fake brew."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parent.parent


class MacOSPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-macos-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "repo with spaces"
        self.repo.mkdir()
        for name in ("Brewfile", "Brewfile.trials"):
            shutil.copy2(REPO / name, self.repo / name)
        # Run the actual package phases, stopping before app helpers and services.
        source, boundary, _ = (REPO / "setup/bootstrap.sh").read_text().partition("\ncleanup_retired_packages\n")
        self.assertTrue(boundary, "Missing package-phase boundary")
        self.script = self.base / "bootstrap-packages.sh"
        self.script.write_text(source + boundary)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.home = self.base / "home"
        self.home.mkdir()
        self.log = self.base / "brew-log"
        self.env = {**os.environ, "HOME": str(self.home),
                    "PATH": f"{self.bin}:{os.environ['PATH']}", "TEST_ROOT": str(self.base)}
        self.command("uname", 'if [ "$1" = -m ]; then echo x86_64; else echo Darwin; fi')
        self.command("sw_vers", "echo 26.0")
        brew = self.bin / "brew"
        brew.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ["TEST_ROOT"])
args = sys.argv[1:]
with (root / "brew-log").open("a") as log:
    log.write(json.dumps(args) + "\\n")
if args == ["shellenv"]:
    pass
elif args == ["help", "trust"]:
    sys.exit(1)
elif args[:2] == ["bundle", "list"]:
    if "--all" in args or "--cask" in args:
        print("orion")
elif args[:2] == ["bundle", "check"]:
    trial = args[-1].endswith("Brewfile.trials")
    sys.exit(0 if not trial or (root / "orion").exists() else 1)
elif args[:2] == ["bundle", "install"]:
    if args[-1].endswith("Brewfile.trials"):
        if (root / "fail-install").exists():
            sys.exit(1)
        (root / "orion").touch()
elif args[:2] == ["bundle", "upgrade"]:
    pass
elif args == ["list", "--formula", "cliamp"]:
    sys.exit(0 if (root / "cliamp").exists() else 1)
elif args == ["list", "--full-name"]:
    if (root / "cliamp").exists():
        print("bjarneo/cliamp/cliamp")
    if (root / "other-tap-package").exists():
        print("bjarneo/cliamp/other")
elif args[0] == "list":
    pass
elif args == ["tap"]:
    if (root / "tap").exists():
        print("bjarneo/cliamp")
elif args == ["uninstall", "--formula", "cliamp"]:
    assert os.environ.get("HOMEBREW_NO_AUTOREMOVE") == "1", "Keep other dependencies"
    if (root / "fail-uninstall").exists():
        sys.exit(1)
    (root / "cliamp").unlink()
elif args == ["untap", "bjarneo/cliamp"]:
    (root / "tap").unlink()
else:
    sys.exit("Unexpected brew command: " + repr(args))
''')
        brew.chmod(0o755)

    def command(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def invoke(self, *args, success=True):
        result = subprocess.run(["/bin/bash", str(self.script), "--local-pass", "--yes",
                                 "--repo-dir", str(self.repo), *args],
                                env=self.env, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_default_run_does_not_read_or_install_trials(self):
        (self.repo / "Brewfile.trials").unlink()
        self.invoke()
        self.assertFalse(any("Brewfile.trials" in " ".join(cmd) for cmd in self.commands()))
        self.assertFalse((self.base / "orion").exists())

    def test_trials_install_once_and_later_default_runs_preserve_them(self):
        self.invoke("--include-trials")
        self.assertTrue((self.base / "orion").exists())
        self.invoke("--include-trials")
        self.invoke()
        installs = [cmd for cmd in self.commands() if cmd[:2] == ["bundle", "install"]]
        self.assertEqual(installs, [["bundle", "install", "--no-upgrade",
                                     f"--file={self.repo}/Brewfile.trials"]])

    def test_upgrade_includes_trials_only_with_flag(self):
        self.invoke("--upgrade")
        upgrades = [cmd[-1] for cmd in self.commands() if cmd[:2] == ["bundle", "upgrade"]]
        self.assertEqual(upgrades, [f"--file={self.repo}/Brewfile"])
        self.log.unlink()
        self.invoke("--upgrade", "--include-trials")
        upgrades = [cmd[-1] for cmd in self.commands() if cmd[:2] == ["bundle", "upgrade"]]
        self.assertEqual(upgrades, [f"--file={self.repo}/Brewfile", f"--file={self.repo}/Brewfile.trials"])

    def test_dry_run_plans_trials_and_removal_without_mutations(self):
        for name in ("cliamp", "tap"):
            (self.base / name).touch()
        result = self.invoke("--include-trials", "--dry-run", "--upgrade")
        self.assertIn("brew uninstall --formula cliamp", result.stdout)
        self.assertIn("brew untap bjarneo/cliamp", result.stdout)
        self.assertIn("orion", result.stdout)
        self.assertTrue((self.base / "cliamp").exists())
        self.assertTrue((self.base / "tap").exists())
        self.assertFalse((self.base / "orion").exists())
        self.assertFalse(any(cmd[0] in ("uninstall", "untap") or
                             cmd[:2] in (["bundle", "install"], ["bundle", "upgrade"])
                             for cmd in self.commands()))

    def test_cliamp_removed_once_even_when_all_standard_packages_are_installed(self):
        for name in ("cliamp", "tap"):
            (self.base / name).touch()
        self.invoke()
        self.invoke()
        self.assertEqual(self.commands().count(["uninstall", "--formula", "cliamp"]), 1)
        self.assertEqual(self.commands().count(["untap", "bjarneo/cliamp"]), 1)
        self.assertFalse((self.base / "cliamp").exists())
        self.assertFalse((self.base / "tap").exists())

    def test_other_installed_tap_packages_are_preserved(self):
        for name in ("cliamp", "tap", "other-tap-package"):
            (self.base / name).touch()
        self.invoke()
        self.assertFalse((self.base / "cliamp").exists())
        self.assertTrue((self.base / "tap").exists())
        self.assertNotIn(["untap", "bjarneo/cliamp"], self.commands())

    def test_failed_uninstall_stops_before_untapping(self):
        for name in ("cliamp", "tap", "fail-uninstall"):
            (self.base / name).touch()
        self.invoke(success=False)
        self.assertNotIn(["untap", "bjarneo/cliamp"], self.commands())

    def test_missing_trial_manifest_fails_before_package_changes(self):
        (self.repo / "Brewfile.trials").unlink()
        self.invoke("--include-trials", success=False)
        self.assertEqual(self.commands(), [["shellenv"]])

    def test_failed_trial_install_stops_before_retired_cleanup(self):
        (self.base / "fail-install").touch()
        (self.base / "cliamp").touch()
        self.invoke("--include-trials", success=False)
        self.assertTrue((self.base / "cliamp").exists())


if __name__ == "__main__":
    unittest.main()
