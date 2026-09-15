#!/bin/bash
# Run from an existing checkout; the macOS bootstrap remains independent.
set -euo pipefail
command -v python3 >/dev/null || { echo 'Python 3 is required (included with Omarchy).' >&2; exit 1; }
exec python3 "$(dirname "$(realpath "$0")")/omarchy_bootstrap.py" "$@"
