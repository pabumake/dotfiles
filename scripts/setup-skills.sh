#!/bin/bash

# The skills repository owns tool-specific installation and configuration.
set -euo pipefail

REPOSITORY_URL="https://github.com/pabumake/skills.git"
REPO_DIR=""
DRY_RUN=0
ASSUME_YES=0
NO_REPO_UPDATE=0
DEDUPLICATE_HERMES=0

usage() {
  cat <<'USAGE'
Usage: setup-skills.sh [options]

Set up shared skills when OpenCode or Hermes is installed.

  --repo-dir PATH                 Skills checkout (default: ~/src/skills,
                                 reusing ~/Documents/skills when present)
  --dry-run                       Inspect without writes or network requests
  --yes                           Accept the printed installation plan
  --no-repo-update                Use the existing checkout without fetching
  --deduplicate-hermes-imports    Back up verified identical Hermes imports
  --help                         Show this help
USAGE
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '    %s\n' "$*"; }
confirm() {
  local answer
  [ "$ASSUME_YES" -eq 1 ] && return 0
  [ -r /dev/tty ] || die "Confirmation requires a terminal or --yes."
  printf '%s [y/N] ' "$1" > /dev/tty
  IFS= read -r answer < /dev/tty || return 1
  case "$answer" in y|Y|yes|YES|Yes) return 0 ;; *) return 1 ;; esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-dir) shift; [ "$#" -gt 0 ] || die "--repo-dir requires a path"; REPO_DIR="$1" ;;
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    --no-repo-update) NO_REPO_UPDATE=1 ;;
    --deduplicate-hermes-imports) DEDUPLICATE_HERMES=1 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

# Bootstrap runs in non-login Bash, which may not have the user's CLI paths.
find_tool() {
  local tool="$1" candidate
  if command -v "$tool" >/dev/null 2>&1; then command -v "$tool"; return; fi
  for candidate in "$HOME/.local/bin/$tool" "$HOME/.$tool/bin/$tool" \
    "/opt/homebrew/bin/$tool" "/usr/local/bin/$tool"; do
    if [ -x "$candidate" ]; then
      PATH="${candidate%/*}:$PATH"
      export PATH
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

opencode_bin="$(find_tool opencode || true)"
hermes_bin="$(find_tool hermes || true)"
if [ -z "$opencode_bin" ] && [ -z "$hermes_bin" ]; then
  note "Skills skipped: neither OpenCode nor Hermes is installed."
  exit 0
fi
for binary in "$opencode_bin" "$hermes_bin"; do
  [ -z "$binary" ] || PATH="${binary%/*}:$PATH"
done
export PATH

if [ -z "$REPO_DIR" ]; then
  REPO_DIR="$HOME/src/skills"
  if [ ! -e "$REPO_DIR" ] && [ -d "$HOME/Documents/skills/.git" ]; then
    REPO_DIR="$HOME/Documents/skills"
  fi
fi
case "$REPO_DIR" in /*) ;; *) die "--repo-dir must be absolute" ;; esac

note "Skills repository: $REPO_DIR"
note "Source: $REPOSITORY_URL"
note "OpenCode: ${opencode_bin:-not installed}"
note "Hermes: ${hermes_bin:-not installed}"
note "The installer links local skills, refreshes the selected baseline via GitHub/npm, and configures Hermes."
[ "$DEDUPLICATE_HERMES" -eq 0 ] || note "Identical Hermes imports will be backed up; differing imports will be reported."

if [ -e "$REPO_DIR" ] && [ ! -d "$REPO_DIR/.git" ]; then
  die "Skills path exists but is not a Git checkout: $REPO_DIR"
fi
if [ "$DRY_RUN" -eq 0 ]; then
  confirm "Apply the skills setup plan?" || { note "Skills setup skipped."; exit 0; }
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  if [ "$NO_REPO_UPDATE" -eq 1 ]; then
    die "--no-repo-update requires an existing skills checkout"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    note "Would clone the skills repository and run its installer."
    exit 0
  fi
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPOSITORY_URL" "$REPO_DIR"
elif [ "$NO_REPO_UPDATE" -eq 1 ]; then
  note "Skills repository update skipped."
elif [ "$DRY_RUN" -eq 1 ]; then
  note "Would inspect origin/main and fast-forward a clean main checkout."
elif [ -n "$(git -C "$REPO_DIR" status --porcelain)" ] || \
  [ "$(git -C "$REPO_DIR" branch --show-current)" != main ]; then
  git -C "$REPO_DIR" status --short
  [ "$ASSUME_YES" -eq 0 ] || die "Skills checkout is dirty or not on main; use --no-repo-update."
  confirm "Use the current skills checkout without updating it?" || die "Skills update declined."
else
  git -C "$REPO_DIR" fetch origin main
  if git -C "$REPO_DIR" merge-base --is-ancestor HEAD origin/main; then
    if [ "$(git -C "$REPO_DIR" rev-parse HEAD)" != "$(git -C "$REPO_DIR" rev-parse origin/main)" ]; then
      git -C "$REPO_DIR" log --oneline HEAD..origin/main
      git -C "$REPO_DIR" diff --stat HEAD..origin/main
      confirm "Fast-forward the skills checkout?" || die "Skills update declined."
      git -C "$REPO_DIR" merge --ff-only origin/main
    fi
  elif git -C "$REPO_DIR" merge-base --is-ancestor origin/main HEAD; then
    note "Skills checkout is ahead; using local commits."
  else
    [ "$ASSUME_YES" -eq 0 ] || die "Skills history diverged; use --no-repo-update."
    confirm "Use the divergent skills checkout without merging?" || die "Skills update declined."
  fi
fi

[ -f "$REPO_DIR/install.sh" ] || die "Skills installer is missing."
grep -q -- '--dry-run' "$REPO_DIR/install.sh" || \
  die "Update the skills checkout to a version supporting --dry-run and Hermes."
args=()
[ "$DRY_RUN" -eq 0 ] || args+=(--dry-run)
[ "$DEDUPLICATE_HERMES" -eq 0 ] || args+=(--deduplicate-hermes-imports)
/bin/bash "$REPO_DIR/install.sh" ${args[@]+"${args[@]}"}
