#!/bin/bash

set -u

STATE_FILE="${XDG_STATE_HOME:-${HOME}/.local/state}/pabu-dotfiles/trackpad-gestures/enabled"

[ -r "${STATE_FILE}" ] || exit 0
IFS= read -r STATE < "${STATE_FILE}" || exit 0
[ "${STATE}" = enabled ] || exit 0
[ -d /Applications/SwipeAeroSpace.app ] || exit 0

exec /usr/bin/open -gj -a SwipeAeroSpace
