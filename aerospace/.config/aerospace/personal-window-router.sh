#!/bin/bash

set -u

PROFILE_FILE="${XDG_STATE_HOME:-${HOME}/.local/state}/pabu-dotfiles/profile/selection"
WINDOW_ID="${AEROSPACE_WINDOW_ID:-}"

[ -r "${PROFILE_FILE}" ] || exit 0
IFS= read -r PROFILE < "${PROFILE_FILE}" || exit 0
[ "${PROFILE}" = personal ] || exit 0
[ -n "${WINDOW_ID}" ] || exit 0
command -v aerospace >/dev/null 2>&1 || exit 0

APP_BUNDLE_ID="$(
  aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}' 2>/dev/null |
    /usr/bin/awk -F '|' -v window_id="${WINDOW_ID}" '$1 == window_id { print $2; exit }'
)"

case "${APP_BUNDLE_ID}" in
  com.mitchellh.ghostty)
    aerospace move-node-to-workspace --window-id "${WINDOW_ID}" 1 >/dev/null 2>&1 || exit 0
    aerospace fullscreen --window-id "${WINDOW_ID}" on >/dev/null 2>&1
    ;;
  com.vscodium)
    aerospace move-node-to-workspace --window-id "${WINDOW_ID}" 2 >/dev/null 2>&1
    ;;
  app.zen-browser.zen)
    aerospace move-node-to-workspace --window-id "${WINDOW_ID}" 3 >/dev/null 2>&1
    ;;
esac
