#!/bin/zsh

set -eu
setopt pipe_fail

SCRIPT_DIR="${0:A:h}"
CONFIG_FILE="${ARCHIVE_MIGRATION_CONFIG:-${SCRIPT_DIR}/migrate-stale-projects.conf}"

SOURCE_ROOT="${HOME}/src/archive"
TARGET_ROOT="/Volumes/datastore0/project-archive"
TARGET_MOUNT_ROOT="/Volumes/datastore0"
RSYNC_BIN="/opt/homebrew/bin/rsync"
ALLOWED_REMOTE_MARKERS="github.com,git.cloud.pbmk.net"
MIN_FREE_BYTES="5368709120"
REQUIRE_MOUNT="1"

die() {
  print -u2 -r -- "ERROR: $1"
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: migrate-stale-projects.sh <command> [project]

Commands:
  list                 List locally staged archive projects
  plan <project>       Check and print the proposed archive transfer
  migrate <project>    Copy, verify, and finalize a NAS archive
  verify <project>     Compare a staged project with its finalized NAS archive
  purge <project>      Reverify and permanently remove the staged Mac copy
USAGE
}

expand_home() {
  local value="$1"
  if [[ "${value}" == '~/'* ]]; then
    print -r -- "${HOME}/${value#\~/}"
  else
    print -r -- "${value}"
  fi
}

load_config() {
  local key value
  [[ -f "${CONFIG_FILE}" ]] || die "Configuration file not found: ${CONFIG_FILE}"

  while IFS='=' read -r key value || [[ -n "${key}${value}" ]]; do
    key="${key%$'\r'}"
    value="${value%$'\r'}"
    [[ -z "${key}" || "${key}" == \#* ]] && continue
    [[ "${key}" != *[^A-Z0-9_]* ]] || die "Invalid configuration key: ${key}"
    case "${key}" in
      SOURCE_ROOT) SOURCE_ROOT="${value}" ;;
      TARGET_ROOT) TARGET_ROOT="${value}" ;;
      TARGET_MOUNT_ROOT) TARGET_MOUNT_ROOT="${value}" ;;
      RSYNC_BIN) RSYNC_BIN="${value}" ;;
      ALLOWED_REMOTE_MARKERS) ALLOWED_REMOTE_MARKERS="${value}" ;;
      MIN_FREE_BYTES) MIN_FREE_BYTES="${value}" ;;
      REQUIRE_MOUNT) REQUIRE_MOUNT="${value}" ;;
      *) die "Unknown configuration key: ${key}" ;;
    esac
  done < "${CONFIG_FILE}"

  SOURCE_ROOT="$(expand_home "${SOURCE_ROOT}")"
  TARGET_ROOT="$(expand_home "${TARGET_ROOT}")"
  TARGET_MOUNT_ROOT="$(expand_home "${TARGET_MOUNT_ROOT}")"
  RSYNC_BIN="$(expand_home "${RSYNC_BIN}")"
  [[ "${SOURCE_ROOT}" == /* && "${TARGET_ROOT}" == /* && "${TARGET_MOUNT_ROOT}" == /* && "${RSYNC_BIN}" == /* ]] || \
    die "SOURCE_ROOT, TARGET_ROOT, TARGET_MOUNT_ROOT, and RSYNC_BIN must resolve to absolute paths"
  [[ "${SOURCE_ROOT}" != / && "${TARGET_ROOT}" != / && "${TARGET_MOUNT_ROOT}" != / ]] || \
    die "Filesystem root cannot be used as an archive path"
  SOURCE_ROOT="${SOURCE_ROOT%/}"
  TARGET_ROOT="${TARGET_ROOT%/}"
  TARGET_MOUNT_ROOT="${TARGET_MOUNT_ROOT%/}"
  [[ "${TARGET_ROOT}" == "${TARGET_MOUNT_ROOT}" || "${TARGET_ROOT}" == "${TARGET_MOUNT_ROOT}/"* ]] || \
    die "TARGET_ROOT must be inside TARGET_MOUNT_ROOT"
  [[ "${SOURCE_ROOT}" != "${TARGET_ROOT}" && "${SOURCE_ROOT}" != "${TARGET_ROOT}/"* && "${TARGET_ROOT}" != "${SOURCE_ROOT}/"* ]] || \
    die "Source and target paths must not overlap"
  [[ "${MIN_FREE_BYTES}" == <-> ]] || die "MIN_FREE_BYTES must be an integer"
  [[ "${REQUIRE_MOUNT}" == 0 || "${REQUIRE_MOUNT}" == 1 ]] || die "REQUIRE_MOUNT must be 0 or 1"
}

list_projects() {
  local project_dir
  [[ -d "${SOURCE_ROOT}" ]] || die "Source root does not exist: ${SOURCE_ROOT}"
  for project_dir in "${SOURCE_ROOT}"/*(N/); do
    print -r -- "${project_dir:t}"
  done | LC_ALL=C sort
}

validate_project_name() {
  local project_name="$1"
  case "${project_name}" in
    ''|.*|*/*|*[^A-Za-z0-9._-]*) die "Invalid project name: ${project_name}" ;;
  esac
}

require_runtime() {
  local rsync_major available_kib available_bytes
  [[ -x "${RSYNC_BIN}" ]] || die "Configured rsync is not executable: ${RSYNC_BIN}"
  rsync_major="$("${RSYNC_BIN}" --version | awk 'NR == 1 {split($3, version, "."); print version[1]}')"
  [[ "${rsync_major}" == <-> && "${rsync_major}" -ge 3 ]] || die "rsync 3.x or newer is required: ${RSYNC_BIN}"
  [[ -d "${TARGET_ROOT}" ]] || die "Target root does not exist: ${TARGET_ROOT}"
  if [[ "${REQUIRE_MOUNT}" == 1 ]]; then
    /sbin/mount | grep -Fq " on ${TARGET_MOUNT_ROOT} " || die "Target mount is not mounted: ${TARGET_MOUNT_ROOT}"
  fi
  available_kib="$(df -Pk "${TARGET_ROOT}" | awk 'NR == 2 {print $4}')"
  [[ "${available_kib}" == <-> ]] || die "Could not determine free space for ${TARGET_ROOT}"
  available_bytes=$((available_kib * 1024))
  (( available_bytes >= MIN_FREE_BYTES )) || die "Target has less than MIN_FREE_BYTES available"
}

project_paths() {
  local project_name="$1"
  validate_project_name "${project_name}"
  PROJECT_SOURCE="${SOURCE_ROOT}/${project_name}"
  PROJECT_TARGET="${TARGET_ROOT}/${project_name}"
  [[ -d "${PROJECT_SOURCE}" && ! -L "${PROJECT_SOURCE}" ]] || die "Project source is not a real directory: ${PROJECT_SOURCE}"
}

require_project_capacity() {
  local source_kib available_kib required_bytes available_bytes
  source_kib="$(du -sk "${PROJECT_SOURCE}" | awk '{print $1}')"
  available_kib="$(df -Pk "${TARGET_ROOT}" | awk 'NR == 2 {print $4}')"
  [[ "${source_kib}" == <-> && "${available_kib}" == <-> ]] || die "Could not calculate transfer capacity"
  required_bytes=$((source_kib * 1024 + MIN_FREE_BYTES))
  available_bytes=$((available_kib * 1024))
  (( available_bytes >= required_bytes )) || die "Target lacks source size plus configured free-space reserve"
}

remote_is_allowed() {
  local remote_url="$1"
  local marker
  local -a markers
  markers=("${(@s:,:)ALLOWED_REMOTE_MARKERS}")
  for marker in "${markers[@]}"; do
    [[ -n "${marker}" && "${remote_url}" == *"${marker}"* ]] && return 0
  done
  return 1
}

check_repository() {
  local repository="$1"
  local remote_name remote_url approved_remote=""
  local remote_sha remote_ref local_sha local_ref remote_output
  local -a remote_names
  local -A remote_refs

  [[ -z "$(GIT_OPTIONAL_LOCKS=0 git -C "${repository}" status --porcelain --untracked-files=all)" ]] || \
    die "Repository working tree is not clean: ${repository}"

  remote_names=("${(@f)$(git -C "${repository}" remote)}")
  for remote_name in "${remote_names[@]}"; do
    [[ -n "${remote_name}" ]] || continue
    remote_url="$(git -C "${repository}" remote get-url "${remote_name}")"
    if remote_is_allowed "${remote_url}"; then
      approved_remote="${remote_name}"
      break
    fi
  done
  [[ -n "${approved_remote}" ]] || die "Repository has no approved Forgejo or GitHub remote: ${repository}"

  remote_output="$(git -C "${repository}" ls-remote --heads --tags "${approved_remote}")" || \
    die "Could not read refs from ${approved_remote}: ${repository}"
  while IFS=$'\t' read -r remote_sha remote_ref; do
    [[ -n "${remote_ref}" && "${remote_ref}" != *'^{}' ]] || continue
    remote_refs[${remote_ref}]="${remote_sha}"
  done <<< "${remote_output}"

  while IFS=' ' read -r local_sha local_ref; do
    [[ -n "${local_ref}" ]] || continue
    [[ "${remote_refs[${local_ref}]-}" == "${local_sha}" ]] || \
      die "Local ref is not present at ${approved_remote}: ${repository} (${local_ref})"
  done < <(git -C "${repository}" for-each-ref --format='%(objectname) %(refname)' refs/heads refs/tags)
}

check_remote_readiness() {
  local git_dir repository
  local repository_count=0
  while IFS= read -r git_dir; do
    [[ -n "${git_dir}" ]] || continue
    repository="${git_dir:h}"
    check_repository "${repository}"
    repository_count=$((repository_count + 1))
  done < <(find "${PROJECT_SOURCE}" -type d -name .git -prune -print | LC_ALL=C sort)
  REPOSITORY_COUNT="${repository_count}"
}

plan_project() {
  local project_name="$1"
  require_runtime
  project_paths "${project_name}"
  require_project_capacity
  [[ ! -e "${PROJECT_TARGET}" ]] || die "Final target already exists: ${PROJECT_TARGET}"
  check_remote_readiness
  print -r -- "READY: ${project_name}"
  print -r -- "Source: ${PROJECT_SOURCE}"
  print -r -- "Target: ${PROJECT_TARGET}"
  print -r -- "Repositories: ${REPOSITORY_COUNT}"
  print -r -- "rsync: ${RSYNC_BIN}"
}

tree_fingerprint() {
  local tree_root="$1"
  find "${tree_root}" -exec stat -f '%N|%HT|%z|%m|%p' {} + | LC_ALL=C sort | shasum -a 256 | awk '{print $1}'
}

verify_git_copies() {
  local copy_root="$1"
  local git_dir
  while IFS= read -r git_dir; do
    [[ -n "${git_dir}" ]] || continue
    git -C "${git_dir:h}" fsck --connectivity-only >/dev/null || \
      die "Git connectivity check failed in archive copy: ${git_dir:h}"
  done < <(find "${copy_root}" -type d -name .git -prune -print | LC_ALL=C sort)
}

verify_test_restore() {
  local source_root="$1"
  local copy_root="$2"
  local copied_file relative_path restored_file
  copied_file="$(find "${copy_root}" -type d -name .git -prune -o -type f -print | LC_ALL=C sort | head -n 1)"
  [[ -n "${copied_file}" ]] || return 0
  relative_path="${copied_file#${copy_root}/}"
  restored_file="$(mktemp "${TMPDIR:-/tmp}/archive-restore.XXXXXX")" || die "Could not create restore test file"
  cp -p "${copied_file}" "${restored_file}" || {
    rm -f -- "${restored_file}"
    die "Could not restore test file from archive copy"
  }
  cmp -s "${source_root}/${relative_path}" "${restored_file}" || {
    rm -f -- "${restored_file}"
    die "Restored test file does not match its source"
  }
  rm -f -- "${restored_file}"
}

verify_copy() {
  local source_root="$1"
  local copy_root="$2"
  local changes
  [[ -d "${copy_root}" ]] || die "Archive copy does not exist: ${copy_root}"
  changes="$("${RSYNC_BIN}" --archive --hard-links --xattrs --checksum --dry-run --delete --itemize-changes --protect-args -- "${source_root}/" "${copy_root}/")" || \
    die "Checksum verification failed for ${copy_root}"
  [[ -z "${changes}" ]] || {
    print -u2 -r -- "${changes}"
    die "Archive copy differs from source: ${copy_root}"
  }
  verify_git_copies "${copy_root}"
  verify_test_restore "${source_root}" "${copy_root}"
}

verify_project() {
  local project_name="$1"
  require_runtime
  project_paths "${project_name}"
  [[ -d "${PROJECT_TARGET}" ]] || die "Final archive does not exist: ${PROJECT_TARGET}"
  check_remote_readiness
  verify_copy "${PROJECT_SOURCE}" "${PROJECT_TARGET}"
  print -r -- "VERIFIED: ${project_name}"
}

migrate_project() {
  local project_name="$1"
  local run_id incoming_root incoming_project before_fingerprint after_fingerprint
  require_runtime
  project_paths "${project_name}"
  require_project_capacity
  [[ ! -e "${PROJECT_TARGET}" ]] || die "Final target already exists: ${PROJECT_TARGET}"
  check_remote_readiness

  incoming_root="${TARGET_ROOT}/.incoming"
  if find "${incoming_root}" -mindepth 1 -maxdepth 1 -name "${project_name}.*" -print -quit 2>/dev/null | grep -q .; then
    die "An unfinished incoming transfer already exists for ${project_name}"
  fi
  run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  incoming_project="${incoming_root}/${project_name}.${run_id}"
  mkdir -p "${incoming_project}" || die "Could not create incoming directory: ${incoming_project}"

  before_fingerprint="$(tree_fingerprint "${PROJECT_SOURCE}")"
  "${RSYNC_BIN}" --archive --hard-links --xattrs --itemize-changes --protect-args -- "${PROJECT_SOURCE}/" "${incoming_project}/" || \
    die "rsync transfer failed; incoming data remains at ${incoming_project}"
  after_fingerprint="$(tree_fingerprint "${PROJECT_SOURCE}")"
  [[ "${before_fingerprint}" == "${after_fingerprint}" ]] || \
    die "Source changed during transfer; incoming data remains at ${incoming_project}"

  verify_copy "${PROJECT_SOURCE}" "${incoming_project}"
  mv -- "${incoming_project}" "${PROJECT_TARGET}" || die "Could not finalize NAS archive"
  verify_copy "${PROJECT_SOURCE}" "${PROJECT_TARGET}"
  print -r -- "MIGRATED: ${project_name}"
  print -r -- "Local source retained: ${PROJECT_SOURCE}"
  print -r -- "NAS archive: ${PROJECT_TARGET}"
}

purge_project() {
  local project_name="$1"
  local source_root_real source_real confirmation
  require_runtime
  project_paths "${project_name}"
  [[ -d "${PROJECT_TARGET}" ]] || die "Final archive does not exist: ${PROJECT_TARGET}"
  check_remote_readiness
  verify_copy "${PROJECT_SOURCE}" "${PROJECT_TARGET}"

  source_root_real="${SOURCE_ROOT:A}"
  source_real="${PROJECT_SOURCE:A}"
  [[ "${source_real:h}" == "${source_root_real}" ]] || die "Refusing purge outside the configured source root"
  [[ "${source_real:t}" == "${project_name}" ]] || die "Refusing purge because the resolved project name changed"

  print -u2 -r -- "Verified NAS archive: ${PROJECT_TARGET}"
  print -u2 -n -r -- "Type the complete project name to permanently delete ${source_real}: "
  IFS= read -r confirmation || die "Purge confirmation was not provided"
  [[ "${confirmation}" == "${project_name}" ]] || die "Purge confirmation did not match"

  rm -rf -- "${source_real}"
  [[ ! -e "${source_real}" ]] || die "Local project still exists after purge: ${source_real}"
  print -r -- "PURGED: ${project_name}"
  print -r -- "NAS archive retained: ${PROJECT_TARGET}"
}

main() {
  local command_name="${1:-}"
  case "${command_name}" in
    -h|--help|help) usage; return 0 ;;
    '') usage; return 1 ;;
  esac
  load_config
  case "${command_name}" in
    list) [[ "$#" -eq 1 ]] || die "list takes no project argument"; list_projects ;;
    plan) [[ "$#" -eq 2 ]] || die "plan requires one project name"; plan_project "$2" ;;
    migrate) [[ "$#" -eq 2 ]] || die "migrate requires one project name"; migrate_project "$2" ;;
    verify) [[ "$#" -eq 2 ]] || die "verify requires one project name"; verify_project "$2" ;;
    purge) [[ "$#" -eq 2 ]] || die "purge requires one project name"; purge_project "$2" ;;
    *) die "Command is not implemented yet: ${command_name}" ;;
  esac
}

main "$@"
