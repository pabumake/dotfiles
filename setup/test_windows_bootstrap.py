"""Expose the isolated native PowerShell suite to the repository test command."""
import os
from pathlib import Path
import shutil
import subprocess
import unittest


PWSH = os.environ.get("DOTFILES_TEST_PWSH") or shutil.which("pwsh")


@unittest.skipUnless(PWSH, "PowerShell 7 is required for Windows bootstrap tests")
class WindowsBootstrapTests(unittest.TestCase):
    def test_isolated_powershell_suite(self):
        result = subprocess.run(
            [PWSH, "-NoLogo", "-NoProfile", "-File", str(Path(__file__).with_suffix(".ps1"))],
            text=True, capture_output=True, timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
