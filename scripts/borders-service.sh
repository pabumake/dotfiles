#!/bin/bash

set -u

COMMAND="${1:-status}"
if [ "$#" -gt 0 ]; then shift; fi

DRY_RUN=0
FORMULA="felixkratz/formulae/borders"
SERVICE_NAME="borders"
CONFIG_PATH="${HOME}/.config/borders/bordersrc"
SERVICE_INFO=""
SERVICE_REGISTERED="false"
SERVICE_RUNNING="false"
SERVICE_PID=""
SERVICE_OUTPUT_LOG=""
SERVICE_ERROR_LOG=""

usage() {
  cat <<'USAGE'
Usage: borders-service.sh [enable|status|restart|disable] [--dry-run]

Commands:
  enable   Migrate an unmanaged process and enable the persistent login service
  status   Report service registration, process, configuration, and log state
  restart  Restart the persistent service and reapply the managed appearance
  disable  Stop and unregister the service without removing its configuration

Options:
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

run() {
  printf '    +'
  printf ' %q' "$@"
  printf '\n'
  if [ "${DRY_RUN}" -eq 0 ]; then
    "$@"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

case "${COMMAND}" in
  enable|status|restart|disable) ;;
  --help|-h) usage; exit 0 ;;
  *) die "Unknown command: ${COMMAND}" ;;
esac

[ "$(uname -s)" = Darwin ] || die "This helper supports macOS only."
command -v brew >/dev/null 2>&1 || die "Homebrew is required."

formula_installed() {
  brew list --formula "${SERVICE_NAME}" >/dev/null 2>&1
}

service_info() {
  brew services info "${SERVICE_NAME}" --json 2>/dev/null
}

json_field() {
  /usr/bin/plutil -extract "0.$1" raw -o - - 2>/dev/null
}

read_service_state() {
  SERVICE_INFO="$(service_info || true)"
  if [ -z "${SERVICE_INFO}" ]; then
    SERVICE_REGISTERED="false"
    SERVICE_RUNNING="false"
    SERVICE_PID=""
    SERVICE_OUTPUT_LOG=""
    SERVICE_ERROR_LOG=""
    return
  fi
  SERVICE_REGISTERED="$(printf '%s' "${SERVICE_INFO}" | json_field registered || printf false)"
  SERVICE_RUNNING="$(printf '%s' "${SERVICE_INFO}" | json_field running || printf false)"
  SERVICE_PID="$(printf '%s' "${SERVICE_INFO}" | json_field pid || true)"
  SERVICE_OUTPUT_LOG="$(printf '%s' "${SERVICE_INFO}" | json_field log_path || true)"
  SERVICE_ERROR_LOG="$(printf '%s' "${SERVICE_INFO}" | json_field error_log_path || true)"
}

process_ids() {
  /usr/bin/pgrep -x borders 2>/dev/null || true
}

print_log_paths() {
  [ -z "${SERVICE_OUTPUT_LOG}" ] || note "Service output log: ${SERVICE_OUTPUT_LOG}"
  [ -z "${SERVICE_ERROR_LOG}" ] || note "Service error log: ${SERVICE_ERROR_LOG}"
}

wait_for_running_service() {
  local attempt=0
  while [ "${attempt}" -lt 10 ]; do
    read_service_state
    if [ "${SERVICE_REGISTERED}" = true ] && [ "${SERVICE_RUNNING}" = true ] && [ -n "$(process_ids)" ]; then
      return 0
    fi
    /bin/sleep 1
    attempt=$((attempt + 1))
  done
  return 1
}

wait_for_process_exit() {
  local attempt=0
  while [ "${attempt}" -lt 10 ]; do
    [ -n "$(process_ids)" ] || return 0
    /bin/sleep 1
    attempt=$((attempt + 1))
  done
  return 1
}

stop_unmanaged_processes() {
  local pids pid
  pids="$(process_ids)"
  [ -n "${pids}" ] || return 0

  note "Replacing unmanaged JankyBorders process(es): ${pids//$'\n'/ }"
  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: would send TERM only to the listed exact-name borders processes."
    return 0
  fi

  for pid in ${pids}; do
    /bin/kill -TERM "${pid}" || die "Could not stop unmanaged borders process ${pid}."
  done
  wait_for_process_exit || die "An unmanaged borders process did not stop; no service was started."
}

apply_config() {
  [ -x "${CONFIG_PATH}" ] || die "Managed JankyBorders config is missing or not executable: ${CONFIG_PATH}"
  run /bin/bash "${CONFIG_PATH}" || die "Could not apply ${CONFIG_PATH}."
}

verify_service() {
  if ! wait_for_running_service; then
    print_log_paths
    die "JankyBorders is not registered and running under Homebrew services."
  fi
}

enable_service() {
  local force_restart="$1"

  if ! formula_installed; then
    [ "${DRY_RUN}" -eq 1 ] || die "Install ${FORMULA} before enabling its service."
    note "Dry run: ${FORMULA} would be installed before service setup."
  fi
  if [ ! -x "${CONFIG_PATH}" ]; then
    [ "${DRY_RUN}" -eq 1 ] || die "Run Stow first; ${CONFIG_PATH} is missing or not executable."
    note "Dry run: Stow would link the executable config at ${CONFIG_PATH}."
  fi

  read_service_state
  if [ "${SERVICE_REGISTERED}" = true ]; then
    if [ "${force_restart}" -eq 1 ] || [ "${SERVICE_RUNNING}" != true ]; then
      run brew services restart "${FORMULA}" || die "Could not restart the JankyBorders service."
    else
      note "JankyBorders is already managed by Homebrew services."
    fi
  else
    stop_unmanaged_processes
    run brew services start "${FORMULA}" || die "Could not enable the JankyBorders service."
  fi

  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: would wait for the service, apply ${CONFIG_PATH}, and verify automatic login registration."
    return 0
  fi

  verify_service
  apply_config
  verify_service
  note "JankyBorders is registered, running, and configured."
  print_log_paths
}

show_status() {
  local pids pids_oneline
  formula_installed || die "${FORMULA} is not installed."
  read_service_state
  pids="$(process_ids)"
  pids_oneline="${pids//$'\n'/ }"

  note "Registered at login: ${SERVICE_REGISTERED}"
  note "Homebrew service running: ${SERVICE_RUNNING}"
  note "Homebrew service PID: ${SERVICE_PID:-none}"
  note "Observed borders PID(s): ${pids_oneline:-none}"
  note "Managed config: ${CONFIG_PATH}"
  print_log_paths

  [ "${SERVICE_REGISTERED}" = true ] && [ "${SERVICE_RUNNING}" = true ] && [ -n "${pids}" ] && [ -x "${CONFIG_PATH}" ]
}

disable_service() {
  formula_installed || die "${FORMULA} is not installed."
  read_service_state
  if [ "${SERVICE_REGISTERED}" != true ]; then
    note "JankyBorders is already unregistered."
    [ -z "$(process_ids)" ] || die "An unmanaged borders process is still running."
    return 0
  fi

  run brew services stop "${FORMULA}" || die "Could not disable the JankyBorders service."
  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: would verify that the service is unregistered and stopped."
    return 0
  fi
  read_service_state
  [ "${SERVICE_REGISTERED}" != true ] || die "JankyBorders is still registered after stop."
  wait_for_process_exit || die "JankyBorders is still running after its service was stopped."
  note "JankyBorders is stopped and unregistered; ${CONFIG_PATH} was retained."
}

case "${COMMAND}" in
  enable) enable_service 0 ;;
  restart) enable_service 1 ;;
  status) show_status ;;
  disable) disable_service ;;
esac
