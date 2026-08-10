#!/bin/bash

set -u

REPOSITORY_URL="https://github.com/pabumake/dotfiles.git"
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
DEFAULT_REPO_DIR="${HOME}/Documents/dotfiles"

FORMULAE=(git stow starship eza herdr borders neovim ripgrep fd fzf lazygit tree-sitter node)
CASKS=(ghostty aerospace hiddenbar font-jetbrains-mono-nerd-font)
STOW_PACKAGES=(aerospace borders ghostty herdr nvim starship zsh gh-manager)

DRY_RUN=0
ASSUME_YES=0
UPGRADE=0
NO_REPO_UPDATE=0
BACKUP_CONFLICTS=0
WITH_HUSHLOGIN=0
LOCAL_PASS=0
REPO_DIR="${DEFAULT_REPO_DIR}"
ORIGINAL_ARGS=("$@")

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [options]

Install or update Pabu's macOS dotfiles.

Options:
  --dry-run             Show planned actions without changing anything
  --yes                 Accept ordinary prompts after printing the plan
  --upgrade             Upgrade declared packages after installing missing ones
  --no-repo-update      Use the current checkout without fetching or pulling
  --backup-conflicts    Approve conflict backups when combined with --yes
  --with-hushlogin      Create ~/.hushlogin after setup
  --repo-dir PATH       Override ~/Documents/dotfiles
  --help                Show this help

Safety rules:
  * Local Git changes are never reset, stashed, or overwritten.
  * Repository updates are fast-forward only.
  * Existing configs are listed and require backup approval before replacement.
  * Installed Homebrew packages are not upgraded unless --upgrade is supplied.
  * Unlisted Homebrew packages are never removed.
USAGE
}

die() {
  printf '\nERROR: %s\n' "$1" >&2
  exit 1
}

heading() {
  printf '\n==> %s\n' "$1"
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

confirm() {
  local prompt="$1"
  local answer

  if [ "${ASSUME_YES}" -eq 1 ]; then
    note "Accepted by --yes: ${prompt}"
    return 0
  fi

  if [ ! -r /dev/tty ]; then
    die "Confirmation requires a terminal. Rerun interactively or use --yes."
  fi

  printf '%s [y/N] ' "${prompt}" > /dev/tty
  IFS= read -r answer < /dev/tty || return 1
  case "${answer}" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    --upgrade) UPGRADE=1 ;;
    --no-repo-update) NO_REPO_UPDATE=1 ;;
    --backup-conflicts) BACKUP_CONFLICTS=1 ;;
    --with-hushlogin) WITH_HUSHLOGIN=1 ;;
    --repo-dir)
      shift
      [ "$#" -gt 0 ] || die "--repo-dir requires a path"
      REPO_DIR="$1"
      ;;
    --local-pass) LOCAL_PASS=1 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

if [ "$(uname -s)" != "Darwin" ]; then
  die "This bootstrap currently supports macOS only."
fi

case "${REPO_DIR}" in
  /*) ;;
  *) die "--repo-dir must be an absolute path" ;;
esac

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [ -x /opt/homebrew/bin/brew ]; then
    printf '%s\n' /opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    printf '%s\n' /usr/local/bin/brew
  else
    return 1
  fi
}

load_brew_environment() {
  local brew_bin="$1"
  eval "$("${brew_bin}" shellenv)"
}

print_declared_packages() {
  local item
  note "Taps: nikitabobko/tap FelixKratz/formulae"
  printf '    Formulae:'
  for item in "${FORMULAE[@]}"; do printf ' %s' "${item}"; done
  printf '\n    Casks:'
  for item in "${CASKS[@]}"; do printf ' %s' "${item}"; done
  printf '\n'
}

install_homebrew() {
  local temp_dir
  local installer

  heading "Homebrew is missing"
  note "Official installer: ${HOMEBREW_INSTALL_URL}"
  note "Homebrew may install Apple's Command Line Tools and request administrator authentication."
  note "No packages will be installed until a later package summary is approved."

  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: Homebrew, repository clone, package installation, and Stow would be skipped."
    print_declared_packages
    exit 0
  fi

  if ! confirm "Download and run the official Homebrew installer?"; then
    die "Homebrew installation declined."
  fi

  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pabu-dotfiles-homebrew.XXXXXX")" || die "Could not create a temporary directory"
  installer="${temp_dir}/install.sh"
  trap 'rm -f "${installer:-}"; rmdir "${temp_dir:-}" 2>/dev/null || true' EXIT

  /usr/bin/curl --fail --silent --show-error --location "${HOMEBREW_INSTALL_URL}" --output "${installer}" || die "Could not download Homebrew installer"
  /bin/bash "${installer}" || die "Homebrew installation failed"

  rm -f "${installer}"
  rmdir "${temp_dir}" 2>/dev/null || true
  trap - EXIT
}

BREW_BIN="$(find_brew 2>/dev/null || true)"
if [ -z "${BREW_BIN}" ]; then
  install_homebrew
  BREW_BIN="$(find_brew 2>/dev/null || true)"
  [ -n "${BREW_BIN}" ] || die "Homebrew installer completed but brew was not found"
fi
load_brew_environment "${BREW_BIN}"

HIDDEN_BAR_WAS_INSTALLED=0
if brew list --cask hiddenbar >/dev/null 2>&1; then
  HIDDEN_BAR_WAS_INSTALLED=1
fi

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return
  fi

  heading "Git is required before the repository can be cloned"
  if ! confirm "Install Git with Homebrew?"; then
    die "Git installation declined."
  fi
  run brew install git || die "Git installation failed"
}

ensure_git

continue_without_repo_update() {
  local reason="$1"
  note "${reason}"
  if [ "${ASSUME_YES}" -eq 1 ]; then
    die "Automatic mode will not continue with an unsafe repository state. Use --no-repo-update explicitly."
  fi
  confirm "Continue with the current checkout without updating it?"
}

update_repository() {
  local branch
  local local_head
  local remote_head

  if [ "${NO_REPO_UPDATE}" -eq 1 ]; then
    heading "Repository update skipped"
    note "Using ${REPO_DIR} because --no-repo-update was supplied."
    return
  fi

  heading "Repository status"

  if [ "${DRY_RUN}" -eq 1 ]; then
    git -C "${REPO_DIR}" status --short
    note "Dry run: would inspect origin/main and fast-forward only when the checkout is clean and behind."
    return
  fi

  if [ -n "$(git -C "${REPO_DIR}" status --porcelain)" ]; then
    git -C "${REPO_DIR}" status --short
    continue_without_repo_update "The checkout has local changes; no fetch, pull, reset, or stash was performed." || die "Stopped to preserve local changes."
    return
  fi

  branch="$(git -C "${REPO_DIR}" branch --show-current)"
  if [ "${branch}" != "main" ]; then
    continue_without_repo_update "The checkout is on branch '${branch}', not 'main'." || die "Stopped to preserve the current branch."
    return
  fi

  git -C "${REPO_DIR}" fetch origin main || die "Could not fetch origin/main"
  local_head="$(git -C "${REPO_DIR}" rev-parse HEAD)"
  remote_head="$(git -C "${REPO_DIR}" rev-parse origin/main)"

  if [ "${local_head}" = "${remote_head}" ]; then
    note "Checkout is current."
  elif git -C "${REPO_DIR}" merge-base --is-ancestor HEAD origin/main; then
    note "Incoming commits:"
    git -C "${REPO_DIR}" log --oneline HEAD..origin/main
    note "Files changed upstream:"
    git -C "${REPO_DIR}" diff --name-status HEAD..origin/main
    if confirm "Fast-forward the checkout to origin/main?"; then
      git -C "${REPO_DIR}" merge --ff-only origin/main || die "Fast-forward failed"
    else
      die "Repository update declined."
    fi
  elif git -C "${REPO_DIR}" merge-base --is-ancestor origin/main HEAD; then
    note "Local checkout is ahead of origin/main; no history was changed."
  else
    continue_without_repo_update "Local and remote histories have diverged; no merge was attempted." || die "Stopped to preserve divergent history."
  fi
}

REMOTE_EXECUTION=1
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  if [ "$(basename "${SCRIPT_DIR}")" = "setup" ] && [ -d "${SCRIPT_DIR}/../.git" ]; then
    REMOTE_EXECUTION=0
    if [ "${REPO_DIR}" = "${DEFAULT_REPO_DIR}" ]; then
      REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
    fi
  fi
fi

if [ "${LOCAL_PASS}" -eq 0 ]; then
  if [ -e "${REPO_DIR}" ] && [ ! -d "${REPO_DIR}/.git" ]; then
    die "Repository path exists but is not a Git checkout: ${REPO_DIR}"
  fi

  if [ ! -d "${REPO_DIR}/.git" ]; then
    heading "Repository is missing"
    note "Source: ${REPOSITORY_URL}"
    note "Destination: ${REPO_DIR}"
    if [ "${DRY_RUN}" -eq 1 ]; then
      note "Dry run: repository clone and remaining phases would be skipped."
      print_declared_packages
      exit 0
    fi
    if ! confirm "Clone the dotfiles repository?"; then
      die "Repository clone declined."
    fi
    mkdir -p "$(dirname "${REPO_DIR}")" || die "Could not create repository parent directory"
    git clone "${REPOSITORY_URL}" "${REPO_DIR}" || die "Repository clone failed"
  else
    update_repository
  fi

  if [ "${REMOTE_EXECUTION}" -eq 1 ] && [ -x "${REPO_DIR}/setup/bootstrap.sh" ]; then
    if [ "${#ORIGINAL_ARGS[@]}" -gt 0 ]; then
      exec "${REPO_DIR}/setup/bootstrap.sh" --local-pass "${ORIGINAL_ARGS[@]}"
    else
      exec "${REPO_DIR}/setup/bootstrap.sh" --local-pass
    fi
  fi
fi

[ -f "${REPO_DIR}/Brewfile" ] || die "Brewfile not found in ${REPO_DIR}"

print_package_status() {
  local item
  local installed_formulae=()
  local missing_formulae=()
  local installed_casks=()
  local missing_casks=()

  for item in "${FORMULAE[@]}"; do
    if brew list --formula "${item}" >/dev/null 2>&1; then
      installed_formulae+=("${item}")
    else
      missing_formulae+=("${item}")
    fi
  done

  for item in "${CASKS[@]}"; do
    if brew list --cask "${item}" >/dev/null 2>&1; then
      installed_casks+=("${item}")
    else
      missing_casks+=("${item}")
    fi
  done

  printf '    Installed formulae:'
  if [ "${#installed_formulae[@]}" -gt 0 ]; then for item in "${installed_formulae[@]}"; do printf ' %s' "${item}"; done; fi
  printf '\n    Missing formulae:'
  if [ "${#missing_formulae[@]}" -gt 0 ]; then for item in "${missing_formulae[@]}"; do printf ' %s' "${item}"; done; fi
  printf '\n    Installed casks:'
  if [ "${#installed_casks[@]}" -gt 0 ]; then for item in "${installed_casks[@]}"; do printf ' %s' "${item}"; done; fi
  printf '\n    Missing casks:'
  if [ "${#missing_casks[@]}" -gt 0 ]; then for item in "${missing_casks[@]}"; do printf ' %s' "${item}"; done; fi
  printf '\n'
}

prepare_borders_formula() {
  note "Third-party formula: FelixKratz/formulae/borders"
  run brew tap FelixKratz/formulae || return 1
  if brew help trust >/dev/null 2>&1; then
    note "Trust scope: this formula only (not the complete tap)."
    run brew trust --formula felixkratz/formulae/borders || return 1
  fi
}

heading "Homebrew package plan"
note "Brewfile: ${REPO_DIR}/Brewfile"
print_package_status
if [ "${UPGRADE}" -eq 1 ]; then
  note "Upgrade mode: declared packages will be upgraded after missing packages are installed."
else
  note "Install-only mode: existing packages will not be upgraded."
fi
note "No unlisted package will be removed. gh-manager remains config-only."

if ! brew bundle check --file="${REPO_DIR}/Brewfile" >/dev/null 2>&1 || [ "${UPGRADE}" -eq 1 ]; then
  if [ "${DRY_RUN}" -eq 1 ]; then
    prepare_borders_formula
    run brew bundle install --no-upgrade --file="${REPO_DIR}/Brewfile"
    if [ "${UPGRADE}" -eq 1 ]; then
      run brew bundle upgrade --file="${REPO_DIR}/Brewfile"
    fi
  else
    if ! confirm "Apply the Homebrew package plan?"; then
      die "Package phase declined."
    fi
    prepare_borders_formula || die "Could not prepare the JankyBorders formula"
    run brew bundle install --no-upgrade --file="${REPO_DIR}/Brewfile" || die "Homebrew bundle installation failed"
    if [ "${UPGRADE}" -eq 1 ]; then
      run brew bundle upgrade --file="${REPO_DIR}/Brewfile" || die "Homebrew bundle upgrade failed"
    fi
  fi
else
  note "All declared dependencies are already installed."
fi

resolve_path() {
  /usr/bin/perl -MCwd=abs_path -e 'my $p = abs_path(shift); print $p if defined $p' "$1" 2>/dev/null
}

add_conflict() {
  local candidate="$1"
  local existing
  if [ "${#CONFLICTS[@]}" -gt 0 ]; then
    for existing in "${CONFLICTS[@]}"; do
      case "${candidate}" in
        "${existing}"|"${existing}"/*) return ;;
      esac
      case "${existing}" in
        "${candidate}"/*) return ;;
      esac
    done
  fi
  CONFLICTS+=("${candidate}")
}

inspect_leaf_target() {
  local package_root="$1"
  local source_leaf="$2"
  local relative="${source_leaf#${package_root}/}"
  local source_cursor="${package_root}"
  local target_cursor="${HOME}"
  local component
  local resolved_source
  local resolved_target
  local parts
  local index

  IFS='/' read -r -a parts <<< "${relative}"
  for ((index = 0; index < ${#parts[@]}; index++)); do
    component="${parts[${index}]}"
    source_cursor="${source_cursor}/${component}"
    target_cursor="${target_cursor}/${component}"

    if [ -L "${target_cursor}" ]; then
      resolved_source="$(resolve_path "${source_cursor}")"
      resolved_target="$(resolve_path "${target_cursor}")"
      if [ -z "${resolved_target}" ] || [ "${resolved_target}" != "${resolved_source}" ]; then
        add_conflict "${target_cursor}"
        return
      else
        # A matching directory symlink makes every descendant part of this
        # package managed as well; do not reinterpret its files as conflicts.
        return
      fi
    elif [ -e "${target_cursor}" ]; then
      if [ "${index}" -lt "$((${#parts[@]} - 1))" ]; then
        [ -d "${target_cursor}" ] || { add_conflict "${target_cursor}"; return; }
      else
        add_conflict "${target_cursor}"
        return
      fi
    fi
  done
}

collect_conflicts() {
  local package
  local package_root
  local leaf
  CONFLICTS=()

  for package in "${STOW_PACKAGES[@]}"; do
    package_root="${REPO_DIR}/${package}"
    [ -d "${package_root}" ] || die "Missing Stow package: ${package}"
    while IFS= read -r leaf; do
      inspect_leaf_target "${package_root}" "${leaf}"
    done < <(find "${package_root}" \( -type f -o -type l \) -print)
  done
}

backup_conflicts_now() {
  local timestamp
  local state_base
  local conflict
  local relative
  local destination

  timestamp="$(date +%Y%m%d-%H%M%S)"
  state_base="${XDG_STATE_HOME:-${HOME}/.local/state}/pabu-dotfiles/backups/${timestamp}"
  mkdir -p "${state_base}" || die "Could not create conflict backup directory"
  : > "${state_base}/manifest.txt"

  for conflict in "${CONFLICTS[@]}"; do
    relative="${conflict#${HOME}/}"
    destination="${state_base}/${relative}"
    mkdir -p "$(dirname "${destination}")" || die "Could not create backup parent for ${relative}"
    printf '%s -> %s\n' "${conflict}" "${destination}" >> "${state_base}/manifest.txt"
    mv "${conflict}" "${destination}" || die "Could not back up ${conflict}"
  done

  CONFLICT_BACKUP_DIR="${state_base}"
  note "Conflicts backed up to ${CONFLICT_BACKUP_DIR}"
}

restore_conflicts() {
  local index
  local conflict
  local relative
  local source

  [ -n "${CONFLICT_BACKUP_DIR:-}" ] || return
  for ((index = ${#CONFLICTS[@]} - 1; index >= 0; index--)); do
    conflict="${CONFLICTS[${index}]}"
    relative="${conflict#${HOME}/}"
    source="${CONFLICT_BACKUP_DIR}/${relative}"
    if [ -e "${source}" ] || [ -L "${source}" ]; then
      mkdir -p "$(dirname "${conflict}")"
      mv "${source}" "${conflict}" || true
    fi
  done
}

heading "Stow plan"
printf '    Packages:'; for package_name in "${STOW_PACKAGES[@]}"; do printf ' %s' "${package_name}"; done; printf '\n'
note "Target: ${HOME}"
collect_conflicts

CONFLICT_BACKUP_DIR=""
if [ "${#CONFLICTS[@]}" -gt 0 ]; then
  note "Conflicting targets:"
  for conflict_path in "${CONFLICTS[@]}"; do note "${conflict_path}"; done

  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: conflicts would require backup approval before Stow."
  elif [ "${ASSUME_YES}" -eq 1 ] && [ "${BACKUP_CONFLICTS}" -ne 1 ]; then
    die "Conflicts require --backup-conflicts when --yes is used."
  elif [ "${BACKUP_CONFLICTS}" -eq 1 ] || confirm "Back up these conflicts and replace them with managed links?"; then
    backup_conflicts_now
  else
    die "Conflict backup declined; no Stow changes were made."
  fi
fi

if [ "${DRY_RUN}" -eq 1 ]; then
  stow --simulate --restow --verbose=2 --dir="${REPO_DIR}" --target="${HOME}" "${STOW_PACKAGES[@]}" 2>&1 || true
else
  if ! stow --simulate --restow --verbose=2 --dir="${REPO_DIR}" --target="${HOME}" "${STOW_PACKAGES[@]}"; then
    restore_conflicts
    die "Stow simulation failed; moved conflicts were restored."
  fi
  stow --restow --dir="${REPO_DIR}" --target="${HOME}" "${STOW_PACKAGES[@]}" || die "Stow failed; any conflict backup remains at ${CONFLICT_BACKUP_DIR:-not created}"
fi

if [ "${WITH_HUSHLOGIN}" -eq 1 ]; then
  heading "Login message"
  run touch "${HOME}/.hushlogin" || die "Could not create ~/.hushlogin"
else
  note "Login message unchanged; use --with-hushlogin to create ~/.hushlogin."
fi

configure_hidden_bar() {
  local domain="com.dwarvesv.minimalbar"
  local has_preferences=0

  heading "Hidden Bar"
  if defaults read "${domain}" >/dev/null 2>&1; then
    has_preferences=1
    note "Existing Hidden Bar preferences found; bootstrap will preserve them."
  else
    note "First-run defaults: start at login, click to reveal, auto-collapse after 10 seconds."
    note "No global hotkey or always-hidden section will be configured."
    run defaults write "${domain}" isAutoStart -bool true || die "Could not configure Hidden Bar login behavior"
    run defaults write "${domain}" isAutoHide -bool true || die "Could not configure Hidden Bar auto-collapse"
    run defaults write "${domain}" numberOfSecondForAutoHide -float 10 || die "Could not configure Hidden Bar collapse delay"
    run defaults write "${domain}" isShowPreferences -bool true || die "Could not configure Hidden Bar onboarding"
    run defaults write "${domain}" areSeparatorsHidden -bool false || die "Could not configure Hidden Bar separators"
    run defaults write "${domain}" alwaysHiddenSectionEnabled -bool false || die "Could not configure Hidden Bar sections"
    run defaults write "${domain}" useFullStatusBarOnExpandEnabled -bool false || die "Could not configure Hidden Bar expansion"
  fi

  if [ "${HIDDEN_BAR_WAS_INSTALLED}" -eq 0 ] || [ "${has_preferences}" -eq 0 ]; then
    note "Hidden Bar will open once for onboarding and login-item registration."
    run open -a "Hidden Bar" || die "Could not launch Hidden Bar"
    if [ "${DRY_RUN}" -eq 0 ]; then
      /bin/sleep 2
    fi
  else
    note "Existing Hidden Bar installation will not be relaunched."
  fi
}

configure_hidden_bar

heading "Validation"
if [ "${DRY_RUN}" -eq 1 ]; then
  note "Dry run: would validate bordersrc and start or refresh JankyBorders when AeroSpace is running."
  note "Dry run: would verify Hidden Bar and its preserved or first-run preferences."
  note "Dry run complete; no validation requiring installed or linked files was run."
else
  /bin/zsh -n "${REPO_DIR}/zsh/.zshrc" || die "Zsh config validation failed"
  /bin/bash -n "${REPO_DIR}/borders/.config/borders/bordersrc" || die "JankyBorders config validation failed"
  [ -d "/Applications/Hidden Bar.app" ] || die "Hidden Bar application was not found"
  defaults read com.dwarvesv.minimalbar >/dev/null 2>&1 || die "Hidden Bar preferences were not found"

  if [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
    /Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config --config-file="${REPO_DIR}/ghostty/.config/ghostty/config.ghostty" || die "Ghostty config validation failed"
  fi

  if command -v herdr >/dev/null 2>&1; then
    HERDR_CONFIG_PATH="${REPO_DIR}/herdr/.config/herdr/config.toml" herdr config check || die "Herdr config validation failed"
  fi

  if command -v aerospace >/dev/null 2>&1 && pgrep -x AeroSpace >/dev/null 2>&1; then
    aerospace reload-config --dry-run --warnings-as-errors || die "AeroSpace config validation failed"
  else
    note "AeroSpace is not running; live config validation was skipped."
  fi

  if command -v borders >/dev/null 2>&1; then
    if pgrep -x borders >/dev/null 2>&1; then
      /bin/bash "${REPO_DIR}/borders/.config/borders/bordersrc" || die "Could not refresh JankyBorders"
      note "JankyBorders appearance refreshed."
    elif pgrep -x AeroSpace >/dev/null 2>&1; then
      borders_bin="$(command -v borders)"
      /usr/bin/nohup "${borders_bin}" >/dev/null 2>&1 &
      /bin/sleep 1
      pgrep -x borders >/dev/null 2>&1 || die "JankyBorders did not start"
      note "JankyBorders started for the running AeroSpace session."
    else
      note "AeroSpace is not running; JankyBorders will start with AeroSpace."
    fi
  fi

  note "Open a new shell, reload Ghostty, and grant AeroSpace Accessibility permission if prompted."
  note "Start Neovim once to let LazyVim install its pinned plugins."
fi

heading "Complete"
note "Repository: ${REPO_DIR}"
note "Package mode: $([ "${UPGRADE}" -eq 1 ] && printf upgrade || printf install-missing-only)"
note "No unlisted Homebrew packages were removed."
