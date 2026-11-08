#!/usr/bin/env python3
"""Copy the tracked MMO preset into Input Remapper; optionally apply it."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


REPO = Path(__file__).resolve().parent.parent
DEVICE = "Razer Razer Orbweaver Chroma"
PRESET = "Orbweaver MMO"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--apply", action="store_true", help="Apply to the connected Orbweaver after copying")
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error("Run as your desktop user; only device access uses pkexec.")
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "input-remapper-2"
    source = REPO / "input-remapper/orbweaver-mmo.json"
    target = config / "presets" / DEVICE / f"{PRESET}.json"
    data = json.loads(source.read_text())
    if not isinstance(data, list) or not data:
        parser.error("Expected a nonempty mapping array")
    for path in (target, *target.parents):
        if path.is_symlink():
            parser.error(f"Refusing symlinked destination: {path}")
    if target.exists() and not target.is_file():
        parser.error(f"Expected a regular file: {target}")
    apply = ["pkexec", "/usr/bin/input-remapper-control", "--config-dir", str(config),
             "--command", "start", "--device", DEVICE, "--preset", PRESET]
    print(f"Preset: {source} -> {target}", flush=True)
    print("Autoload preferences and other presets are preserved.", flush=True)
    if args.dry_run:
        if args.apply:
            print(f"Would apply {PRESET!r} to {DEVICE!r}")
        return
    if args.apply and not shutil.which("input-remapper-control"):
        parser.error("Install Input Remapper with the Omarchy bootstrap first")
    if not target.exists() or target.read_bytes() != source.read_bytes():
        if target.exists():
            state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
            base = state / "pabu-dotfiles/backups"
            base.mkdir(parents=True, exist_ok=True)
            backup = Path(tempfile.mkdtemp(prefix="orbweaver-mmo-", dir=base))
            shutil.copy2(target, backup / target.name)
            print(f"Previous preset backed up to {backup}", flush=True)
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as output:
            temporary = Path(output.name)
            output.write(source.read_bytes())
        try:
            temporary.chmod(0o644)
            temporary.replace(target)
        finally:
            temporary.unlink(missing_ok=True)
    if args.apply:
        subprocess.run(apply, check=True)
    print("Ready. Select 'Orbweaver MMO' in Input Remapper; test before enabling autoload.")


if __name__ == "__main__":
    main()
