#!/bin/bash

set -eu

VERSION="0.3.1"
SHA256="a8d4df69175f8a476fc79e345d1a972b28c34b04f4177dfc6e425901fa458475"
URL="https://github.com/zmkfirmware/zmk-studio/releases/download/v${VERSION}/ZMK.Studio_universal.app.tar.gz"
APP_DIR="${HOME}/Applications"
DRY_RUN=0
UPGRADE=0
CONFIRM=0

usage() {
  cat <<'USAGE'
Usage: install-zmk-studio.sh [--dry-run] [--upgrade] [--app-dir PATH]

Install the pinned official macOS app into ~/Applications.
Existing installations in ~/Applications or /Applications are skipped unless
--upgrade is supplied. Replaced apps are backed up beside the installation.

Options:
  --dry-run       Print the plan without downloading or changing files
  --upgrade       Replace an existing app with the pinned version
  --app-dir PATH  Use an absolute destination directory
  --confirm       Ask before downloading or replacing an app
  --help          Show this help
USAGE
}

die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --upgrade) UPGRADE=1 ;;
    --confirm) CONFIRM=1 ;;
    --app-dir)
      shift
      [ "$#" -gt 0 ] || die "--app-dir requires a path"
      APP_DIR="$1"
      ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

[ "$(uname -s)" = Darwin ] || die "This installer supports macOS only."
case "${APP_DIR}" in /*) ;; *) die "--app-dir must be an absolute path" ;; esac
case "$(uname -m)" in arm64|x86_64) ;; *) die "Unsupported Mac architecture" ;; esac

APP="${APP_DIR}/ZMK Studio.app"
# Preserve installations made manually in either standard application directory.
if [ "${APP_DIR}" = "${HOME}/Applications" ] && [ ! -e "${APP}" ] && \
   [ ! -L "${APP}" ] && [ -e "/Applications/ZMK Studio.app" ]; then
  APP_DIR="/Applications"
  APP="${APP_DIR}/ZMK Studio.app"
fi

if [ -e "${APP}" ] || [ -L "${APP}" ]; then
  if [ "${UPGRADE}" -eq 0 ]; then
    printf 'ZMK Studio is already installed: %s\n' "${APP}"
    exit 0
  fi
  INSTALLED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist" 2>/dev/null || true)"
  if [ "${INSTALLED_VERSION}" = "${VERSION}" ]; then
    printf 'ZMK Studio %s is already installed: %s\n' "${VERSION}" "${APP}"
    exit 0
  fi
fi

printf 'Install ZMK Studio %s to %s\nSource: %s\nSHA-256: %s\n' "${VERSION}" "${APP}" "${URL}" "${SHA256}"
if [ "${DRY_RUN}" -eq 1 ]; then
  printf 'Dry run: would verify the download and back up any existing app before installation.\n'
  exit 0
fi

if [ "${CONFIRM}" -eq 1 ]; then
  [ -r /dev/tty ] || die "Confirmation requires a terminal."
  printf 'Apply the ZMK Studio installation plan? [y/N] ' > /dev/tty
  IFS= read -r ANSWER < /dev/tty || exit 0
  case "${ANSWER}" in y|Y|yes|YES|Yes) ;; *) printf 'ZMK Studio installation skipped.\n'; exit 0 ;; esac
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pabu-zmk-studio.XXXXXX")"
trap 'rm -rf "${TEMP_DIR}"' EXIT
/usr/bin/curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  "${URL}" --output "${TEMP_DIR}/studio.tar.gz"
printf '%s  %s\n' "${SHA256}" "${TEMP_DIR}/studio.tar.gz" | /usr/bin/shasum -a 256 -c -
/usr/bin/tar -xzf "${TEMP_DIR}/studio.tar.gz" -C "${TEMP_DIR}"
SOURCE_APP="${TEMP_DIR}/ZMK Studio.app"
[ -x "${SOURCE_APP}/Contents/MacOS/zmk-studio" ] || die "The archive does not contain the expected app."

/bin/mkdir -p "${APP_DIR}"
[ -w "${APP_DIR}" ] || die "Cannot write to ${APP_DIR}; use --app-dir with a writable directory."
# Stage on the destination filesystem before moving an existing app aside.
STAGE_DIR="$(mktemp -d "${APP_DIR}/.zmk-studio.XXXXXX")"
trap 'rm -rf "${TEMP_DIR}" "${STAGE_DIR}"' EXIT
/usr/bin/ditto "${SOURCE_APP}" "${STAGE_DIR}/ZMK Studio.app"
BACKUP=""
if [ -e "${APP}" ] || [ -L "${APP}" ]; then
  BACKUP="$(mktemp -d "${APP_DIR}/ZMK Studio.backup.XXXXXX")/ZMK Studio.app"
  /bin/mv "${APP}" "${BACKUP}"
  printf 'Previous app backed up: %s\n' "${BACKUP}"
fi
if ! /bin/mv "${STAGE_DIR}/ZMK Studio.app" "${APP}"; then
  if [ -n "${BACKUP}" ]; then /bin/mv "${BACKUP}" "${APP}"; fi
  die "Could not install ZMK Studio."
fi
printf 'Installed ZMK Studio %s. Open it from %s.\n' "${VERSION}" "${APP}"
