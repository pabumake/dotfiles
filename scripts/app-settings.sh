#!/bin/bash

set -u

PROVIDER="${1:-}"
[ -n "${PROVIDER}" ] || { printf 'ERROR: Missing provider.\n' >&2; exit 1; }
shift

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"
STATE_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/pabu-dotfiles/backups"

case "${PROVIDER}" in
  hiddenbar)
    DOMAIN="com.dwarvesv.minimalbar"
    APP_NAME="Hidden Bar"
    DEFAULTS_NAME="Hidden Bar"
    ;;
  ice)
    DOMAIN="com.jordanbaird.Ice"
    APP_NAME="Ice"
    DEFAULTS_NAME="Ice"
    ;;
  *) printf 'ERROR: Unknown provider: %s\n' "${PROVIDER}" >&2; exit 1 ;;
esac

COMMAND=""
OUTPUT_PATH=""
SOURCE_PATH=""
ASSUME_YES=0
DRY_RUN=0
INITIAL_IMPORT=0

usage() {
  cat <<USAGE
Usage:
  ${PROVIDER}-settings.sh export [--output /absolute/path/preferences.plist] [--dry-run]
  ${PROVIDER}-settings.sh import PATH [--yes] [--initial] [--dry-run]
  ${PROVIDER}-settings.sh --help

Commands:
  export    Export ${DEFAULTS_NAME} preferences to an external backup.
  import    Validate and import a plist after creating a recovery backup.

Options:
  --output PATH  Override the export destination; PATH must be absolute and
                 outside the dotfiles repository
  --yes          Skip import confirmation; a recovery backup is still made
  --initial      Import only when no existing preferences are present
  --dry-run      Print actions without changing preferences or app state
  --help, -h     Show this help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

note() {
  printf '%s\n' "$1"
}

print_command() {
  printf '  +'
  printf ' %q' "$@"
  printf '\n'
}

confirm() {
  local answer
  if [ "${ASSUME_YES}" -eq 1 ]; then
    note "Confirmation accepted by --yes."
    return 0
  fi
  [ -r /dev/tty ] || die "Import confirmation requires a terminal; rerun with --yes."
  printf 'Import these %s settings? [y/N] ' "${DEFAULTS_NAME}" > /dev/tty
  IFS= read -r answer < /dev/tty || return 1
  case "${answer}" in y|Y|yes|YES|Yes) return 0 ;; *) return 1 ;; esac
}

default_export_path() {
  local stamp directory counter
  stamp="$(date +%Y%m%d-%H%M%S)"
  directory="${STATE_ROOT}/${PROVIDER}-${stamp}"
  counter=1
  while [ -e "${directory}" ]; do
    directory="${STATE_ROOT}/${PROVIDER}-${stamp}-${counter}"
    counter=$((counter + 1))
  done
  printf '%s/preferences.plist\n' "${directory}"
}

ensure_external_output() {
  local path="$1" parent suffix="" canonical
  case "${path}" in /*) ;; *) die "Export destination must be absolute: ${path}" ;; esac
  parent="$(dirname -- "${path}")"
  while [ ! -d "${parent}" ]; do
    suffix="/$(basename -- "${parent}")${suffix}"
    [ "$(dirname -- "${parent}")" != "${parent}" ] || die "Could not resolve: ${path}"
    parent="$(dirname -- "${parent}")"
  done
  parent="$(CDPATH= cd -P -- "${parent}" && pwd)" || die "Could not resolve: ${path}"
  canonical="${parent}${suffix}/$(basename -- "${path}")"
  case "${canonical}" in
    "${REPO_ROOT}"|"${REPO_ROOT}"/*) die "Refusing repository-local backup: ${path}" ;;
  esac
}

validate_plist() {
  /usr/bin/plutil -lint "$1" >/dev/null 2>&1 || die "Invalid property list: $1"
}

export_preferences() {
  local destination="$1" directory temporary
  ensure_external_output "${destination}"
  [ ! -e "${destination}" ] || die "Export destination already exists: ${destination}"
  directory="$(dirname -- "${destination}")"
  if [ "${DRY_RUN}" -eq 1 ]; then
    print_command /bin/mkdir -p "${directory}"
    print_command /usr/bin/defaults export "${DOMAIN}" "${destination}"
    note "Dry run: no preferences were exported."
    return
  fi
  /usr/bin/defaults read "${DOMAIN}" >/dev/null 2>&1 || die "${DEFAULTS_NAME} has no readable preferences."
  umask 077
  /bin/mkdir -p "${directory}" || die "Could not create: ${directory}"
  temporary="${destination}.tmp.$$"
  if ! /usr/bin/defaults export "${DOMAIN}" "${temporary}" >/dev/null; then
    /bin/rm -f "${temporary}"
    die "Could not export ${DEFAULTS_NAME} preferences."
  fi
  if ! /usr/bin/plutil -lint "${temporary}" >/dev/null 2>&1; then
    /bin/rm -f "${temporary}"
    die "${DEFAULTS_NAME} produced an invalid export."
  fi
  /bin/mv "${temporary}" "${destination}" || die "Could not finalize: ${destination}"
  /bin/chmod 600 "${destination}" || die "Could not secure: ${destination}"
  note "Exported ${DEFAULTS_NAME} preferences:"
  note "${destination}"
}

app_is_running() {
  [ "$(/usr/bin/osascript -e "application \"${APP_NAME}\" is running" 2>/dev/null)" = "true" ]
}

quit_app() {
  local attempts=0
  /usr/bin/osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null || \
    die "Could not quit ${APP_NAME}; no preferences were imported."
  while app_is_running; do
    attempts=$((attempts + 1))
    [ "${attempts}" -lt 25 ] || die "${APP_NAME} did not quit."
    /bin/sleep 0.2
  done
}

reopen_if_needed() {
  [ "$1" -eq 0 ] || /usr/bin/open -a "${APP_NAME}" >/dev/null 2>&1 || true
}

restore_after_failure() {
  local recovery="$1" was_running="$2"
  note "Import failed; restoring the pre-import export."
  /usr/bin/defaults import "${DOMAIN}" "${recovery}" >/dev/null 2>&1 || \
    note "WARNING: restore manually from ${recovery}"
  reopen_if_needed "${was_running}"
  die "${DEFAULTS_NAME} settings were not imported. Recovery: ${recovery}"
}

import_initial() {
  local source="$1" was_running=0
  if /usr/bin/defaults read "${DOMAIN}" >/dev/null 2>&1; then
    note "Existing ${DEFAULTS_NAME} preferences found; initial import skipped."
    return
  fi
  note "Initial preference source: ${source}"
  if [ "${DRY_RUN}" -eq 1 ]; then
    print_command /usr/bin/defaults import "${DOMAIN}" "${source}"
    note "Dry run: no preferences or application state were changed."
    return
  fi
  if app_is_running; then was_running=1; quit_app; fi
  if ! /usr/bin/defaults import "${DOMAIN}" "${source}" >/dev/null 2>&1; then
    reopen_if_needed "${was_running}"
    die "Could not import initial ${DEFAULTS_NAME} preferences."
  fi
  /usr/bin/defaults read "${DOMAIN}" >/dev/null 2>&1 || die "Initial preferences could not be verified."
  reopen_if_needed "${was_running}"
  note "Imported initial ${DEFAULTS_NAME} preferences successfully."
}

import_preferences() {
  local source="$1" recovery was_running=0
  [ -f "${source}" ] || die "Import source is not a file: ${source}"
  [ -r "${source}" ] || die "Import source is not readable: ${source}"
  validate_plist "${source}"
  if [ "${INITIAL_IMPORT}" -eq 1 ]; then import_initial "${source}"; return; fi
  /usr/bin/defaults read "${DOMAIN}" >/dev/null 2>&1 || die "No existing preferences to protect before import."
  recovery="$(default_export_path)"
  note "Import source: ${source}"
  note "Pre-import recovery export: ${recovery}"
  if [ "${DRY_RUN}" -eq 1 ]; then
    print_command /usr/bin/defaults export "${DOMAIN}" "${recovery}"
    print_command /usr/bin/defaults import "${DOMAIN}" "${source}"
    note "Dry run: no preferences or application state were changed."
    return
  fi
  export_preferences "${recovery}"
  if ! confirm; then note "Import cancelled. Recovery retained: ${recovery}"; return; fi
  if app_is_running; then was_running=1; quit_app; fi
  /usr/bin/defaults import "${DOMAIN}" "${source}" >/dev/null 2>&1 || \
    restore_after_failure "${recovery}" "${was_running}"
  /usr/bin/defaults read "${DOMAIN}" >/dev/null 2>&1 || \
    restore_after_failure "${recovery}" "${was_running}"
  reopen_if_needed "${was_running}"
  note "Imported ${DEFAULTS_NAME} preferences successfully."
  note "Recovery export retained: ${recovery}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    export|import) [ -z "${COMMAND}" ] || die "Specify one command."; COMMAND="$1" ;;
    --output) shift; [ "$#" -gt 0 ] || die "--output requires a path."; OUTPUT_PATH="$1" ;;
    --yes) ASSUME_YES=1 ;;
    --initial) INITIAL_IMPORT=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --help|-h) usage; exit 0 ;;
    --*) die "Unknown option: $1" ;;
    *)
      [ "${COMMAND}" = import ] || die "Unexpected argument: $1"
      [ -z "${SOURCE_PATH}" ] || die "Import accepts one source."
      SOURCE_PATH="$1"
      ;;
  esac
  shift
done

[ "$(uname -s)" = Darwin ] || die "This helper supports macOS only."
[ -n "${COMMAND}" ] || { usage; exit 1; }
case "${COMMAND}" in
  export)
    [ -z "${SOURCE_PATH}" ] || die "Export does not accept a source."
    [ "${ASSUME_YES}" -eq 0 ] || die "--yes is only valid with import."
    [ "${INITIAL_IMPORT}" -eq 0 ] || die "--initial is only valid with import."
    [ -n "${OUTPUT_PATH}" ] || OUTPUT_PATH="$(default_export_path)"
    export_preferences "${OUTPUT_PATH}"
    ;;
  import)
    [ -z "${OUTPUT_PATH}" ] || die "--output is only valid with export."
    [ -n "${SOURCE_PATH}" ] || die "Import requires a plist path."
    import_preferences "${SOURCE_PATH}"
    ;;
esac
