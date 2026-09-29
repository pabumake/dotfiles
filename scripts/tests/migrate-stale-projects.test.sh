#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_UNDER_TEST="${SCRIPT_DIR}/../migrate-stale-projects.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/migrate-stale-projects-test.XXXXXX")"

cleanup() {
  rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [ "${expected}" != "${actual}" ]; then
    printf 'Expected: %s\nActual:   %s\n' "${expected}" "${actual}" >&2
    fail "${message}"
  fi
}

write_config() {
  local fixture="$1"
  cat > "${fixture}/archive.conf" <<EOF
SOURCE_ROOT=${fixture}/source
TARGET_ROOT=${fixture}/target
TARGET_MOUNT_ROOT=${fixture}/target
RSYNC_BIN=/opt/homebrew/bin/rsync
ALLOWED_REMOTE_MARKERS=file://
MIN_FREE_BYTES=0
REQUIRE_MOUNT=0
EOF
}

create_ready_project() {
  local fixture="$1"
  local project="$2"
  local project_dir="${fixture}/source/${project}"
  local remote_dir="${fixture}/remotes/${project}.git"

  mkdir -p "${project_dir}" "${fixture}/remotes"
  git init --bare --quiet "${remote_dir}"
  git -C "${project_dir}" init --quiet
  git -C "${project_dir}" config user.name "Archive Test"
  git -C "${project_dir}" config user.email "archive-test@example.invalid"
  printf 'ready\n' > "${project_dir}/README.md"
  git -C "${project_dir}" add README.md
  git -C "${project_dir}" commit --quiet -m "test fixture"
  git -C "${project_dir}" remote add origin "file://${remote_dir}"
  git -C "${project_dir}" push --quiet --set-upstream origin HEAD
}

test_list_shows_only_project_directories() {
  local fixture="${TEST_ROOT}/list"
  local output
  mkdir -p "${fixture}/source/2026-01-alpha" "${fixture}/source/.pending-delete" "${fixture}/target"
  touch "${fixture}/source/migrate-stale-projects.sh"
  write_config "${fixture}"

  output="$(ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" list)" || \
    fail "list command exited unsuccessfully"
  assert_eq "2026-01-alpha" "${output}" "list should show only archive project directories"
}

test_plan_accepts_a_clean_project_with_a_pushed_remote() {
  local fixture="${TEST_ROOT}/plan"
  local output
  mkdir -p "${fixture}/source" "${fixture}/target"
  write_config "${fixture}"
  create_ready_project "${fixture}" "2026-01-alpha"

  output="$(ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" plan 2026-01-alpha)" || \
    fail "plan should accept a clean project with a pushed approved remote"
  [[ "${output}" == *"READY: 2026-01-alpha"* ]] || fail "plan should report that the project is ready"
  [[ "${output}" == *"${fixture}/target/2026-01-alpha"* ]] || fail "plan should print the final target"
}

test_migrate_finalizes_a_verified_copy_without_removing_source() {
  local fixture="${TEST_ROOT}/migrate"
  local project_dir
  local output
  mkdir -p "${fixture}/source" "${fixture}/target"
  write_config "${fixture}"
  create_ready_project "${fixture}" "2026-02-beta"
  project_dir="${fixture}/source/2026-02-beta"
  mkdir -p "${project_dir}/empty-directory"
  printf '#!/bin/sh\nprintf beta\\n\n' > "${project_dir}/run.sh"
  chmod 755 "${project_dir}/run.sh"
  ln -s README.md "${project_dir}/readme-link"
  git -C "${project_dir}" add run.sh readme-link
  git -C "${project_dir}" commit --quiet -m "add archive shapes"
  git -C "${project_dir}" push --quiet

  output="$(ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" migrate 2026-02-beta)" || \
    fail "migrate should copy and verify a ready project"
  [[ "${output}" == *"MIGRATED: 2026-02-beta"* ]] || fail "migrate should report finalization"
  [[ -d "${project_dir}" ]] || fail "migrate must preserve the local source"
  [[ -d "${fixture}/target/2026-02-beta" ]] || fail "migrate should create the final NAS directory"
  [[ -L "${fixture}/target/2026-02-beta/readme-link" ]] || fail "migrate should preserve symlinks"
  [[ -x "${fixture}/target/2026-02-beta/run.sh" ]] || fail "migrate should preserve executable bits"
  [[ -d "${fixture}/target/2026-02-beta/empty-directory" ]] || fail "migrate should preserve empty directories"

  ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" verify 2026-02-beta >/dev/null || \
    fail "verify should accept the finalized copy"
}

test_purge_requires_exact_confirmation_after_reverification() {
  local fixture="${TEST_ROOT}/purge"
  local project="2026-03-gamma"
  local project_dir
  mkdir -p "${fixture}/source" "${fixture}/target"
  write_config "${fixture}"
  create_ready_project "${fixture}" "${project}"
  project_dir="${fixture}/source/${project}"

  ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" migrate "${project}" >/dev/null || \
    fail "purge fixture migration should succeed"

  if printf 'wrong-project\n' | ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" purge "${project}" >/dev/null 2>&1; then
    fail "purge should reject an incorrect confirmation"
  fi
  [[ -d "${project_dir}" ]] || fail "failed purge must preserve the local source"

  printf '%s\n' "${project}" | ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" purge "${project}" >/dev/null || \
    fail "purge should accept the exact project confirmation"
  [[ ! -e "${project_dir}" ]] || fail "confirmed purge should remove the exact local source"
  [[ -d "${fixture}/target/${project}" ]] || fail "purge must preserve the NAS archive"
}

test_config_rejects_unknown_keys() {
  local fixture="${TEST_ROOT}/unknown-config"
  mkdir -p "${fixture}/source" "${fixture}/target"
  write_config "${fixture}"
  printf 'UNSAFE_SHELL_FRAGMENT=ignored\n' >> "${fixture}/archive.conf"

  if ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" list >/dev/null 2>&1; then
    fail "configuration parser should reject unknown keys"
  fi
}

test_migrate_refuses_an_existing_final_target() {
  local fixture="${TEST_ROOT}/collision"
  local project="2026-04-delta"
  mkdir -p "${fixture}/source" "${fixture}/target/${project}"
  write_config "${fixture}"
  create_ready_project "${fixture}" "${project}"

  if ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" migrate "${project}" >/dev/null 2>&1; then
    fail "migrate should refuse an existing final target"
  fi
  [[ -d "${fixture}/source/${project}" ]] || fail "collision refusal must preserve the source"
}

test_verify_detects_a_changed_archive_copy() {
  local fixture="${TEST_ROOT}/changed-copy"
  local project="2026-05-epsilon"
  mkdir -p "${fixture}/source" "${fixture}/target"
  write_config "${fixture}"
  create_ready_project "${fixture}" "${project}"
  ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" migrate "${project}" >/dev/null || \
    fail "changed-copy fixture migration should succeed"
  printf 'changed on target\n' > "${fixture}/target/${project}/README.md"

  if ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" verify "${project}" >/dev/null 2>&1; then
    fail "verify should reject a changed archive copy"
  fi
  [[ -d "${fixture}/source/${project}" ]] || fail "verification failure must preserve the source"
}

test_plan_rejects_an_unpushed_commit() {
  local fixture="${TEST_ROOT}/unpushed"
  local project="2026-06-zeta"
  local project_dir
  mkdir -p "${fixture}/source" "${fixture}/target"
  write_config "${fixture}"
  create_ready_project "${fixture}" "${project}"
  project_dir="${fixture}/source/${project}"
  printf 'local only\n' >> "${project_dir}/README.md"
  git -C "${project_dir}" add README.md
  git -C "${project_dir}" commit --quiet -m "unpushed fixture commit"

  if ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" plan "${project}" >/dev/null 2>&1; then
    fail "plan should reject a local commit that is absent from the remote"
  fi
}

test_plan_accepts_an_unversioned_archive_project() {
  local fixture="${TEST_ROOT}/unversioned"
  local project="2026-07-eta"
  mkdir -p "${fixture}/source/${project}" "${fixture}/target"
  write_config "${fixture}"
  printf 'legacy script\n' > "${fixture}/source/${project}/legacy.sh"

  ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" plan "${project}" >/dev/null || \
    fail "plan should accept an archive project that contains no Git repository"
}

test_config_rejects_filesystem_root_as_source() {
  local fixture="${TEST_ROOT}/root-source"
  mkdir -p "${fixture}/target"
  write_config "${fixture}"
  perl -pi -e 's#^SOURCE_ROOT=.*#SOURCE_ROOT=/#' "${fixture}/archive.conf"

  if ARCHIVE_MIGRATION_CONFIG="${fixture}/archive.conf" /bin/zsh "${SCRIPT_UNDER_TEST}" list >/dev/null 2>&1; then
    fail "configuration should reject the filesystem root as a source"
  fi
}

test_list_shows_only_project_directories
printf 'PASS: list shows only project directories\n'
test_plan_accepts_a_clean_project_with_a_pushed_remote
printf 'PASS: plan accepts a clean project with a pushed remote\n'
test_migrate_finalizes_a_verified_copy_without_removing_source
printf 'PASS: migrate finalizes a verified copy without removing source\n'
test_purge_requires_exact_confirmation_after_reverification
printf 'PASS: purge requires exact confirmation after reverification\n'
test_config_rejects_unknown_keys
printf 'PASS: configuration rejects unknown keys\n'
test_migrate_refuses_an_existing_final_target
printf 'PASS: migrate refuses an existing final target\n'
test_verify_detects_a_changed_archive_copy
printf 'PASS: verify detects a changed archive copy\n'
test_plan_rejects_an_unpushed_commit
printf 'PASS: plan rejects an unpushed commit\n'
test_plan_accepts_an_unversioned_archive_project
printf 'PASS: plan accepts an unversioned archive project\n'
test_config_rejects_filesystem_root_as_source
printf 'PASS: configuration rejects filesystem root as source\n'
