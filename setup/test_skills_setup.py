"""Test the macOS skills phase without Homebrew or network access."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class SkillsPhaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-skills-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.home.mkdir()
        self.bin.mkdir()
        (self.bin / "opencode").write_text("#!/bin/bash\nexit 0\n")
        (self.bin / "opencode").chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=f"{self.bin}:/usr/bin:/bin",
                        GIT_CONFIG_NOSYSTEM="1")
        self.checkout = self.root / "skills checkout"
        subprocess.run(["git", "init", "-q", "-b", "main", str(self.checkout)],
                       env=self.env, check=True)
        self.installer = self.checkout / "install.sh"
        self.installer.write_text('''#!/bin/bash
# --dry-run and --deduplicate-hermes-imports supported
for arg in "$@"; do
  if [ "$arg" = --dry-run ]; then echo "installer preview"; exit 0; fi
done
printf '%s\\n' "$@" > "$HOME/installer-args"
''')

    def run_phase(self, *args):
        return subprocess.run(["/bin/bash", str(REPO / "scripts/setup-skills.sh"), *args],
                              env=self.env, text=True, capture_output=True)

    def test_dry_run_uses_existing_checkout_without_mutation(self):
        before = self.installer.read_bytes()
        result = self.run_phase("--repo-dir", str(self.checkout), "--dry-run")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("installer preview", result.stdout)
        self.assertEqual(self.installer.read_bytes(), before)
        self.assertFalse((self.home / "installer-args").exists())
        self.assertFalse((self.checkout / ".git/FETCH_HEAD").exists())

    def test_explicit_checkout_and_deduplication_are_forwarded(self):
        result = self.run_phase("--repo-dir", str(self.checkout), "--no-repo-update", "--yes",
                                "--deduplicate-hermes-imports")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("--deduplicate-hermes-imports", (self.home / "installer-args").read_text())

    def test_dirty_checkout_requires_explicit_no_update(self):
        result = self.run_phase("--repo-dir", str(self.checkout), "--yes")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--no-repo-update", result.stderr)
        self.assertFalse((self.home / "installer-args").exists())

    def test_missing_checkout_preview_does_not_clone(self):
        missing = self.root / "new checkout"
        result = self.run_phase("--repo-dir", str(missing), "--dry-run")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Would clone", result.stdout)
        self.assertFalse(missing.exists())

    def test_old_installer_is_not_invoked_by_dry_run(self):
        self.installer.write_text('touch "$HOME/unexpected-write"\n')
        result = self.run_phase("--repo-dir", str(self.checkout), "--dry-run")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Update the skills checkout", result.stderr)
        self.assertFalse((self.home / "unexpected-write").exists())

    def test_reuses_documents_checkout(self):
        legacy = self.home / "Documents/skills"
        legacy.parent.mkdir()
        shutil.move(self.checkout, legacy)
        result = self.run_phase("--dry-run")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(str(legacy), result.stdout)
        self.assertIn("installer preview", result.stdout)

    def test_bootstrap_help_exposes_skill_options(self):
        result = subprocess.run(["/bin/bash", str(REPO / "setup/bootstrap.sh"), "--help"],
                                env=self.env, capture_output=True, text=True, check=True)
        self.assertIn("--skills-repo-dir", result.stdout)
        self.assertIn("--skip-skills", result.stdout)


if __name__ == "__main__":
    unittest.main()
