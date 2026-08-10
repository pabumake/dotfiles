#!/bin/bash

set -u

COMMAND="${1:-}"
[ -n "${COMMAND}" ] || COMMAND="status"
if [ "$#" -gt 0 ]; then shift; fi

DRY_RUN=0
ASSUME_YES=0
STATE_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/pabu-dotfiles"
GESTURE_STATE_DIR="${STATE_ROOT}/trackpad-gestures"
ENABLED_FILE="${GESTURE_STATE_DIR}/enabled"
BACKUP_DIR="${STATE_ROOT}/backups/trackpad-gestures"
BACKUP_FILE="${BACKUP_DIR}/original.tsv"

usage() {
  cat <<'USAGE'
Usage: trackpad-gestures.sh [enable|status|restore] [--yes] [--dry-run]

Commands:
  enable   Back up affected preferences, configure SwipeAeroSpace, and disable
           conflicting native horizontal and Mission Control gestures
  status   Report managed preference and integration state
  restore  Restore the original preference values and stop SwipeAeroSpace

Options:
  --yes      Skip confirmation for enable or restore
  --dry-run  Print planned changes without applying them
  --help     Show this help
USAGE
}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

note() {
  printf '    %s\n' "$1"
}

confirm() {
  local answer
  if [ "${ASSUME_YES}" -eq 1 ]; then
    note "Confirmation accepted by --yes."
    return 0
  fi
  [ -r /dev/tty ] || die "Confirmation requires a terminal; rerun with --yes."
  printf '%s [y/N] ' "$1" > /dev/tty
  IFS= read -r answer < /dev/tty || return 1
  case "${answer}" in y|Y|yes|YES|Yes) return 0 ;; *) return 1 ;; esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes) ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

case "${COMMAND}" in enable|status|restore) ;; --help|-h) usage; exit 0 ;; *) die "Unknown command: ${COMMAND}" ;; esac
[ "$(uname -s)" = Darwin ] || die "This helper supports macOS only."

preference_type() {
  local output
  output="$(defaults read-type "$1" "$2" 2>/dev/null)" || return 1
  case "${output}" in
    *integer) printf '%s\n' integer ;;
    *boolean) printf '%s\n' boolean ;;
    *float) printf '%s\n' float ;;
    *string) printf '%s\n' string ;;
    *) return 2 ;;
  esac
}

record_preference() {
  local domain="$1" key="$2" type value
  if type="$(preference_type "${domain}" "${key}")"; then
    value="$(defaults read "${domain}" "${key}")" || die "Could not read ${domain} ${key}"
    case "${value}" in *$'\t'*|*$'\n'*) die "Unsupported value in ${domain} ${key}" ;; esac
    printf '%s\t%s\t%s\t%s\n' "${domain}" "${key}" "${type}" "${value}"
  else
    [ "$?" -eq 1 ] || die "Unsupported preference type for ${domain} ${key}"
    printf '%s\t%s\tmissing\t\n' "${domain}" "${key}"
  fi
}

create_backup() {
  local temporary
  if [ -e "${BACKUP_FILE}" ]; then
    extend_backup com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture
    extend_backup com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture
    extend_backup club.mediosz.SwipeAeroSpace swipeUpOverview
    note "Original preference backup retained: ${BACKUP_FILE}"
    return
  fi
  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: would create original preference backup at ${BACKUP_FILE}"
    return
  fi
  umask 077
  /bin/mkdir -p "${BACKUP_DIR}" || die "Could not create ${BACKUP_DIR}"
  temporary="${BACKUP_FILE}.tmp.$$"
  {
    record_preference com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture
    record_preference com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture
    record_preference com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture
    record_preference com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture
    record_preference com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture
    record_preference com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture
    record_preference com.apple.dock expose-group-apps
    record_preference club.mediosz.SwipeAeroSpace fingers
    record_preference club.mediosz.SwipeAeroSpace natrual
    record_preference club.mediosz.SwipeAeroSpace skip-empty
    record_preference club.mediosz.SwipeAeroSpace wrap
    record_preference club.mediosz.SwipeAeroSpace threshold
    record_preference club.mediosz.SwipeAeroSpace swipeUpOverview
  } > "${temporary}" || { /bin/rm -f "${temporary}"; die "Could not create preference backup"; }
  /bin/mv "${temporary}" "${BACKUP_FILE}" || die "Could not finalize preference backup"
  note "Original preferences backed up: ${BACKUP_FILE}"
}

backup_contains() {
  local wanted_domain="$1" wanted_key="$2" domain key type value
  while IFS=$'\t' read -r domain key type value; do
    [ "${domain}" != "${wanted_domain}" ] || [ "${key}" != "${wanted_key}" ] || return 0
  done < "${BACKUP_FILE}"
  return 1
}

extend_backup() {
  local domain="$1" key="$2" temporary
  backup_contains "${domain}" "${key}" && return
  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: would add ${domain} ${key} to the original preference backup"
    return
  fi
  umask 077
  temporary="${BACKUP_FILE}.tmp.$$"
  /bin/cp "${BACKUP_FILE}" "${temporary}" || die "Could not stage preference backup extension"
  record_preference "${domain}" "${key}" >> "${temporary}" || {
    /bin/rm -f "${temporary}"
    die "Could not extend preference backup"
  }
  /bin/mv "${temporary}" "${BACKUP_FILE}" || die "Could not finalize preference backup extension"
  note "Added previously unmanaged preference to recovery backup: ${domain} ${key}"
}

write_preference() {
  local domain="$1" key="$2" type="$3" value="$4"
  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Would set ${domain} ${key} = ${value} (${type})"
  else
    defaults write "${domain}" "${key}" "-${type}" "${value}" || die "Could not set ${domain} ${key}"
  fi
}

preference_matches() {
  local domain="$1" key="$2" expected="$3" current
  current="$(defaults read "${domain}" "${key}" 2>/dev/null)" || return 1
  [ "${current}" = "${expected}" ]
}

configuration_matches() {
  [ -r "${ENABLED_FILE}" ] || return 1
  [ "$(sed -n '1p' "${ENABLED_FILE}")" = enabled ] || return 1
  preference_matches com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture 0 || return 1
  preference_matches com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture 0 || return 1
  preference_matches com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture 0 || return 1
  preference_matches com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture 0 || return 1
  preference_matches com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture 0 || return 1
  preference_matches com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture 0 || return 1
  preference_matches com.apple.dock expose-group-apps 1 || return 1
  preference_matches club.mediosz.SwipeAeroSpace fingers Three || return 1
  preference_matches club.mediosz.SwipeAeroSpace natrual 1 || return 1
  preference_matches club.mediosz.SwipeAeroSpace skip-empty 1 || return 1
  preference_matches club.mediosz.SwipeAeroSpace wrap 0 || return 1
  preference_matches club.mediosz.SwipeAeroSpace threshold 0.3 || return 1
  preference_matches club.mediosz.SwipeAeroSpace swipeUpOverview 0
}

save_enabled_state() {
  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Would save integration state as enabled: ${ENABLED_FILE}"
    return
  fi
  umask 077
  /bin/mkdir -p "${GESTURE_STATE_DIR}" || die "Could not create ${GESTURE_STATE_DIR}"
  printf 'enabled\n' > "${ENABLED_FILE}.tmp" || die "Could not stage gesture state"
  /bin/chmod 600 "${ENABLED_FILE}.tmp" || die "Could not secure gesture state"
  /bin/mv "${ENABLED_FILE}.tmp" "${ENABLED_FILE}" || die "Could not save gesture state"
}

enable_gestures() {
  note "Three-finger horizontal swipes: SwipeAeroSpace"
  note "Workspace order: natural direction, skip empty, stop at edges"
  note "Three-finger vertical swipe: disabled (no Mission Control overlay)"
  note "Mission Control: group windows by application"
  note "Recovery backup: ${BACKUP_FILE}"

  if [ -r "${ENABLED_FILE}" ] && [ "$(sed -n '1p' "${ENABLED_FILE}")" = enabled ] && [ ! -r "${BACKUP_FILE}" ]; then
    die "Gesture integration is enabled, but its original preference backup is missing: ${BACKUP_FILE}"
  fi
  if configuration_matches; then
    note "Gesture integration is already configured; no preferences were changed."
    note "Original preference backup retained: ${BACKUP_FILE}"
    return
  fi

  if [ "${DRY_RUN}" -eq 0 ] && ! confirm "Apply these trackpad and Mission Control preferences?"; then
    die "Gesture setup cancelled."
  fi
  create_backup
  write_preference com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture int 0
  write_preference com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture int 0
  write_preference com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture int 0
  write_preference com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture int 0
  write_preference com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture int 0
  write_preference com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture int 0
  write_preference com.apple.dock expose-group-apps bool true
  write_preference club.mediosz.SwipeAeroSpace fingers string Three
  write_preference club.mediosz.SwipeAeroSpace natrual bool true
  write_preference club.mediosz.SwipeAeroSpace skip-empty bool true
  write_preference club.mediosz.SwipeAeroSpace wrap bool false
  write_preference club.mediosz.SwipeAeroSpace threshold float 0.3
  write_preference club.mediosz.SwipeAeroSpace swipeUpOverview bool false
  save_enabled_state

  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: would restart Dock and open SwipeAeroSpace."
  else
    /usr/bin/killall Dock >/dev/null 2>&1 || true
    /usr/bin/open -gj -a SwipeAeroSpace || die "Could not open SwipeAeroSpace"
    note "Gesture integration enabled. Grant SwipeAeroSpace Accessibility permission if prompted."
  fi
}

print_status_line() {
  local label="$1" domain="$2" key="$3" expected="$4" current="missing" state="DIFFERS"
  current="$(defaults read "${domain}" "${key}" 2>/dev/null)" || true
  [ "${current}" != "${expected}" ] || state="OK"
  printf '    %-34s %-8s current=%s expected=%s\n' "${label}" "${state}" "${current}" "${expected}"
  [ "${state}" = OK ]
}

status_gestures() {
  local failures=0 enabled="disabled"
  if [ -r "${ENABLED_FILE}" ] && [ "$(sed -n '1p' "${ENABLED_FILE}")" = enabled ]; then enabled="enabled"; fi
  note "Integration state: ${enabled}"
  [ "${enabled}" = enabled ] || failures=$((failures + 1))
  print_status_line "Built-in trackpad horizontal 3" com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture 0 || failures=$((failures + 1))
  print_status_line "Built-in trackpad horizontal 4" com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture 0 || failures=$((failures + 1))
  print_status_line "Built-in trackpad vertical 3" com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture 0 || failures=$((failures + 1))
  print_status_line "Bluetooth trackpad horizontal 3" com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture 0 || failures=$((failures + 1))
  print_status_line "Bluetooth trackpad horizontal 4" com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture 0 || failures=$((failures + 1))
  print_status_line "Bluetooth trackpad vertical 3" com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture 0 || failures=$((failures + 1))
  print_status_line "Mission Control grouping" com.apple.dock expose-group-apps 1 || failures=$((failures + 1))
  print_status_line "Swipe fingers" club.mediosz.SwipeAeroSpace fingers Three || failures=$((failures + 1))
  print_status_line "Natural direction" club.mediosz.SwipeAeroSpace natrual 1 || failures=$((failures + 1))
  print_status_line "Skip empty workspaces" club.mediosz.SwipeAeroSpace skip-empty 1 || failures=$((failures + 1))
  print_status_line "Wrap at workspace edges" club.mediosz.SwipeAeroSpace wrap 0 || failures=$((failures + 1))
  print_status_line "Swipe threshold" club.mediosz.SwipeAeroSpace threshold 0.3 || failures=$((failures + 1))
  print_status_line "Swipe-up workspace overview" club.mediosz.SwipeAeroSpace swipeUpOverview 0 || failures=$((failures + 1))
  [ "${failures}" -eq 0 ]
}

restore_preference() {
  local domain="$1" key="$2" type="$3" value="$4"
  if [ "${DRY_RUN}" -eq 1 ]; then
    if [ "${type}" = missing ]; then note "Would delete ${domain} ${key}"; else note "Would restore ${domain} ${key} = ${value} (${type})"; fi
    return
  fi
  if [ "${type}" = missing ]; then
    defaults delete "${domain}" "${key}" >/dev/null 2>&1 || true
  else
    defaults write "${domain}" "${key}" "-${type}" "${value}" || die "Could not restore ${domain} ${key}"
  fi
}

restore_gestures() {
  local domain key type value
  [ -r "${BACKUP_FILE}" ] || die "Original preference backup not found: ${BACKUP_FILE}"
  note "Restore source: ${BACKUP_FILE}"
  if [ "${DRY_RUN}" -eq 0 ] && ! confirm "Restore the original gesture and Mission Control preferences?"; then
    die "Restore cancelled."
  fi
  while IFS=$'\t' read -r domain key type value; do
    [ -n "${domain}" ] || continue
    restore_preference "${domain}" "${key}" "${type}" "${value}"
  done < "${BACKUP_FILE}"

  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Would mark gesture integration disabled, restart Dock, and quit SwipeAeroSpace."
  else
    umask 077
    /bin/mkdir -p "${GESTURE_STATE_DIR}" || die "Could not create ${GESTURE_STATE_DIR}"
    printf 'disabled\n' > "${ENABLED_FILE}.tmp" || die "Could not stage gesture state"
    /bin/chmod 600 "${ENABLED_FILE}.tmp" || die "Could not secure gesture state"
    /bin/mv "${ENABLED_FILE}.tmp" "${ENABLED_FILE}" || die "Could not save gesture state"
    /usr/bin/killall Dock >/dev/null 2>&1 || true
    /usr/bin/osascript -e 'tell application "SwipeAeroSpace" to quit' >/dev/null 2>&1 || true
    note "Original preferences restored. The recovery backup was retained."
  fi
}

case "${COMMAND}" in
  enable) enable_gestures ;;
  status) status_gestures ;;
  restore) restore_gestures ;;
esac
