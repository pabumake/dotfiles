#!/bin/bash

set -u

REPOSITORY_URL="https://github.com/pabumake/dotfiles.git"
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
DEFAULT_REPO_DIR="${HOME}/Documents/dotfiles"

FORMULAE=(git stow starship eza herdr borders yazi bjarneo/cliamp/cliamp mole ffmpeg-full sevenzip jq poppler zoxide resvg imagemagick-full neovim ripgrep fd fzf lazygit tree-sitter node)
CASKS=(ghostty caskhub aerospace swipeaerospace font-jetbrains-mono-nerd-font font-symbols-only-nerd-font)
STOW_PACKAGES=(aerospace borders ghostty herdr nvim starship yazi zsh gh-manager)
TRUSTED_FORMULAE=(felixkratz/formulae/borders bjarneo/cliamp/cliamp)
TRUSTED_CASKS=(mediosz/tap/swipeaerospace nikitabobko/tap/aerospace)

DRY_RUN=0
ASSUME_YES=0
UPGRADE=0
NO_REPO_UPDATE=0
BACKUP_CONFLICTS=0
TRUST_THIRD_PARTY=0
WITH_HUSHLOGIN=0
LOCAL_PASS=0
MENU_BAR_MANAGER=""
SWITCH_BAR_MANAGER=0
PROFILE_REQUEST=""
REPO_DIR="${DEFAULT_REPO_DIR}"
ORIGINAL_ARGS=("$@")

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [options]

Install or update Pabu's macOS dotfiles.

Requires macOS 15.6 or newer.

Options:
  --dry-run             Show planned actions without changing anything
  --yes                 Accept ordinary prompts after printing the plan
  --upgrade             Upgrade declared packages after installing missing ones
  --no-repo-update      Use the current checkout without fetching or pulling
  --backup-conflicts    Approve conflict backups when combined with --yes
  --trust-third-party   Approve required third-party Homebrew trust
  --with-hushlogin      Create ~/.hushlogin after setup
  --menu-bar-manager M  Select hiddenbar, ice, or none and remember the choice
  --switch-bar-manager  Show the menu-bar manager selector again
  --profile-personal    Enable and remember personal app workspace assignments
  --profile-default     Disable personal app workspace assignments
  --repo-dir PATH       Override ~/Documents/dotfiles
  --help                Show this help

Safety rules:
  * Local Git changes are never reset, stashed, or overwritten.
  * Repository updates are fast-forward only.
  * Existing configs are listed and require backup approval before replacement.
  * Third-party Homebrew trust is item-scoped and requires separate approval.
  * Installed Homebrew packages are not upgraded unless --upgrade is supplied.
  * Unrelated Homebrew packages are never removed.
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
    --trust-third-party) TRUST_THIRD_PARTY=1 ;;
    --with-hushlogin) WITH_HUSHLOGIN=1 ;;
    --menu-bar-manager)
      shift
      [ "$#" -gt 0 ] || die "--menu-bar-manager requires hiddenbar, ice, or none"
      MENU_BAR_MANAGER="$1"
      ;;
    --switch-bar-manager) SWITCH_BAR_MANAGER=1 ;;
    --profile-personal)
      [ -z "${PROFILE_REQUEST}" ] || die "Choose only one profile option"
      PROFILE_REQUEST="personal"
      ;;
    --profile-default)
      [ -z "${PROFILE_REQUEST}" ] || die "Choose only one profile option"
      PROFILE_REQUEST="default"
      ;;
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

case "${MENU_BAR_MANAGER}" in
  ""|hiddenbar|ice|none) ;;
  *) die "--menu-bar-manager must be hiddenbar, ice, or none" ;;
esac
[ "${SWITCH_BAR_MANAGER}" -eq 0 ] || [ -z "${MENU_BAR_MANAGER}" ] || \
  die "Use either --switch-bar-manager or --menu-bar-manager, not both."

if [ "$(uname -s)" != "Darwin" ]; then
  die "This bootstrap currently supports macOS only."
fi

MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
MACOS_VERSION_REMAINDER="${MACOS_VERSION#*.}"
MACOS_MINOR="${MACOS_VERSION_REMAINDER%%.*}"
if [ "${MACOS_MAJOR}" -lt 15 ] || \
   { [ "${MACOS_MAJOR}" -eq 15 ] && [ "${MACOS_MINOR}" -lt 6 ]; }; then
  die "This bootstrap requires macOS 15.6 or newer. Detected macOS ${MACOS_VERSION}."
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
  note "Taps: nikitabobko/tap FelixKratz/formulae mediosz/tap bjarneo/cliamp"
  printf '    Formulae:'
  for item in "${FORMULAE[@]}"; do printf ' %s' "${item}"; done
  printf '\n    Casks:'
  for item in "${CASKS[@]}"; do printf ' %s' "${item}"; done
  printf '\n'
  note "Menu-bar manager: selected separately (Hidden Bar, Ice, or None)."
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

trust_entry_present() {
  local trust_json="$1"
  local entry_type="$2"
  local entry="$3"

  printf '%s\n' "${trust_json}" | \
    /usr/bin/plutil -extract "${entry_type}" xml1 -o - -- - 2>/dev/null | \
    /usr/bin/grep -Fq "<string>${entry}</string>"
}

prepare_third_party_trust() {
  local trust_json
  local item
  local missing_formulae=()
  local missing_casks=()

  if ! brew help trust >/dev/null 2>&1; then
    note "This Homebrew version does not require explicit third-party trust."
    return 0
  fi

  trust_json="$(brew trust --json=v1 2>/dev/null)" || \
    die "Could not inspect Homebrew's trusted entries."

  for item in "${TRUSTED_FORMULAE[@]}"; do
    if ! trust_entry_present "${trust_json}" formulae "${item}" && \
       ! trust_entry_present "${trust_json}" taps "${item%/*}"; then
      missing_formulae+=("${item}")
    fi
  done
  for item in "${TRUSTED_CASKS[@]}"; do
    if ! trust_entry_present "${trust_json}" casks "${item}" && \
       ! trust_entry_present "${trust_json}" taps "${item%/*}"; then
      missing_casks+=("${item}")
    fi
  done

  if [ "${#missing_formulae[@]}" -eq 0 ] && [ "${#missing_casks[@]}" -eq 0 ]; then
    note "Required third-party Homebrew entries are already trusted."
    return 0
  fi

  heading "Third-party Homebrew trust"
  note "Homebrew formulae and casks are Ruby code that can run with your user privileges."
  note "The bootstrap will trust only these required items, not their complete taps:"
  if [ "${#missing_formulae[@]}" -gt 0 ]; then
    for item in "${missing_formulae[@]}"; do note "Formula: ${item}"; done
  fi
  if [ "${#missing_casks[@]}" -gt 0 ]; then
    for item in "${missing_casks[@]}"; do note "Cask: ${item}"; done
  fi

  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: trust approval would be required before these entries were added."
  elif [ "${TRUST_THIRD_PARTY}" -eq 1 ]; then
    note "Third-party trust approved by --trust-third-party."
  elif [ "${ASSUME_YES}" -eq 1 ]; then
    die "Third-party Homebrew trust requires --trust-third-party when --yes is used."
  elif ! confirm "Trust these third-party Homebrew items?"; then
    die "Third-party Homebrew trust declined."
  fi

  if [ "${#missing_formulae[@]}" -gt 0 ]; then
    for item in "${missing_formulae[@]}"; do
      case "${item}" in
        felixkratz/formulae/*) run brew tap FelixKratz/formulae || return 1 ;;
        bjarneo/cliamp/*) run brew tap bjarneo/cliamp || return 1 ;;
      esac
      run brew trust --formula "${item}" || return 1
    done
  fi
  if [ "${#missing_casks[@]}" -gt 0 ]; then
    for item in "${missing_casks[@]}"; do
      case "${item}" in
        mediosz/tap/*) run brew tap mediosz/tap || return 1 ;;
        nikitabobko/tap/*) run brew tap nikitabobko/tap || return 1 ;;
      esac
      run brew trust --cask "${item}" || return 1
    done
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
note "The fixed package phase removes nothing. Menu-bar switching is handled next."
note "gh-manager remains config-only."
prepare_third_party_trust || die "Could not prepare third-party Homebrew trust"

if ! brew bundle check --file="${REPO_DIR}/Brewfile" >/dev/null 2>&1 || [ "${UPGRADE}" -eq 1 ]; then
  if [ "${DRY_RUN}" -eq 1 ]; then
    run brew bundle install --no-upgrade --file="${REPO_DIR}/Brewfile"
    if [ "${UPGRADE}" -eq 1 ]; then
      run brew bundle upgrade --file="${REPO_DIR}/Brewfile"
    fi
  else
    if ! confirm "Apply the Homebrew package plan?"; then
      die "Package phase declined."
    fi
    run brew bundle install --no-upgrade --file="${REPO_DIR}/Brewfile" || die "Homebrew bundle installation failed"
    if [ "${UPGRADE}" -eq 1 ]; then
      run brew bundle upgrade --file="${REPO_DIR}/Brewfile" || die "Homebrew bundle upgrade failed"
    fi
  fi
else
  note "All declared dependencies are already installed."
fi

MENU_BAR_STATE_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/pabu-dotfiles"
MENU_BAR_STATE_DIR="${MENU_BAR_STATE_ROOT}/menu-bar-manager"
MENU_BAR_SELECTION_FILE="${MENU_BAR_STATE_DIR}/selection"
MENU_BAR_BACKUP_ROOT="${MENU_BAR_STATE_ROOT}/backups"
saved_menu_bar_manager() {
  local saved=""
  if [ -r "${MENU_BAR_SELECTION_FILE}" ]; then
    IFS= read -r saved < "${MENU_BAR_SELECTION_FILE}" || true
  fi
  case "${saved}" in hiddenbar|ice|none) printf '%s\n' "${saved}" ;; esac
}

ice_cask() {
  if [ "${MACOS_MAJOR}" -ge 26 ]; then
    printf '%s\n' "jordanbaird-ice@beta"
  elif [ "${MACOS_MAJOR}" -ge 14 ]; then
    printf '%s\n' "jordanbaird-ice"
  else
    return 1
  fi
}

choose_menu_bar_manager() {
  local selected=""
  local answer=""
  local ice_label="Ice"
  local ice_available=1
  if ! ice_cask >/dev/null 2>&1; then
    ice_label="Ice (unavailable before macOS 14)"
    ice_available=0
  fi

  [ -r /dev/tty ] || die "Menu-bar manager selection requires a terminal or --menu-bar-manager."
  if command -v fzf >/dev/null 2>&1; then
    if [ "${ice_available}" -eq 1 ]; then
      selected="$(printf '%s\tice\nHidden Bar\thiddenbar\nNone\tnone\n' "${ice_label}" | \
        fzf --height=8 --layout=reverse --border --no-multi --delimiter=$'\t' \
          --with-nth=1 --prompt='Menu-bar manager > ')" || selected=""
    else
      selected="$(printf 'Hidden Bar\thiddenbar\nNone\tnone\n' | \
      fzf --height=8 --layout=reverse --border --no-multi --delimiter=$'\t' \
          --with-nth=1 --prompt='Menu-bar manager > ')" || selected=""
    fi
    if [ -n "${selected}" ]; then
      printf '%s\n' "${selected##*$'\t'}"
      return
    fi
    printf 'fzf could not open; using the numbered selector.\n' > /dev/tty
  fi

  printf '\nChoose a menu-bar manager:\n' > /dev/tty
  if [ "${ice_available}" -eq 1 ]; then
    printf '  1) %s (default)\n  2) Hidden Bar\n  3) None\n' "${ice_label}" > /dev/tty
  else
    printf '  1) Hidden Bar (default)\n  2) None\n' > /dev/tty
  fi
  printf 'Selection [1]: ' > /dev/tty
  IFS= read -r answer < /dev/tty || die "Menu-bar manager selection cancelled."
  if [ "${ice_available}" -eq 1 ]; then
    case "${answer}" in
      ""|1) printf '%s\n' ice ;;
      2) printf '%s\n' hiddenbar ;;
      3) printf '%s\n' none ;;
      *) die "Invalid menu-bar manager selection: ${answer}" ;;
    esac
  else
    case "${answer}" in
      ""|1) printf '%s\n' hiddenbar ;;
      2) printf '%s\n' none ;;
      *) die "Invalid menu-bar manager selection: ${answer}" ;;
    esac
  fi
}

resolve_menu_bar_manager() {
  local saved selected
  saved="$(saved_menu_bar_manager)"
  PREVIOUS_MENU_BAR_MANAGER="${saved}"

  if [ -n "${MENU_BAR_MANAGER}" ]; then
    :
  elif [ "${SWITCH_BAR_MANAGER}" -eq 1 ]; then
    selected="$(choose_menu_bar_manager)" || die "Menu-bar manager selection cancelled."
    case "${selected}" in hiddenbar|ice|none) MENU_BAR_MANAGER="${selected}" ;; *) die "Menu-bar manager selection failed." ;; esac
  elif [ -z "${saved}" ]; then
    if [ -r /dev/tty ]; then
      selected="$(choose_menu_bar_manager)" || die "Menu-bar manager selection cancelled."
      case "${selected}" in hiddenbar|ice|none) MENU_BAR_MANAGER="${selected}" ;; *) die "Menu-bar manager selection failed." ;; esac
    elif ice_cask >/dev/null 2>&1; then
      MENU_BAR_MANAGER=ice
      note "No saved menu-bar manager and no interactive terminal; defaulting to Ice."
    else
      MENU_BAR_MANAGER=hiddenbar
      note "Ice is unavailable on this macOS version; defaulting to Hidden Bar."
    fi
  else
    MENU_BAR_MANAGER="${saved}"
  fi
  if [ "${MENU_BAR_MANAGER}" = ice ] && ! ice_cask >/dev/null 2>&1; then
    die "Ice requires macOS 14 or newer."
  fi
}

cask_installed() {
  brew list --cask "$1" >/dev/null 2>&1
}

provider_domain() {
  case "$1" in
    hiddenbar) printf '%s\n' com.dwarvesv.minimalbar ;;
    ice) printf '%s\n' com.jordanbaird.Ice ;;
  esac
}

provider_app() {
  case "$1" in hiddenbar) printf '%s\n' "Hidden Bar" ;; ice) printf '%s\n' Ice ;; esac
}

provider_helper() {
  printf '%s/scripts/%s-settings.sh\n' "${REPO_DIR}" "$1"
}

provider_baseline() {
  printf '%s/%s/preferences.plist\n' "${REPO_DIR}" "$1"
}

provider_running() {
  local app
  app="$(provider_app "$1")"
  [ "$(/usr/bin/osascript -e "application \"${app}\" is running" 2>/dev/null)" = true ]
}

quit_provider() {
  local provider="$1" app
  app="$(provider_app "${provider}")"
  if provider_running "${provider}"; then
    run /usr/bin/osascript -e "tell application \"${app}\" to quit" || return 1
  else
    note "${app} is not running."
  fi
}

backup_provider() {
  local provider="$1" domain helper timestamp directory destination record
  domain="$(provider_domain "${provider}")"
  helper="$(provider_helper "${provider}")"
  if ! defaults read "${domain}" >/dev/null 2>&1; then
    note "No ${provider} preferences found to back up."
    return 0
  fi
  timestamp="$(date +%Y%m%d-%H%M%S)"
  directory="${MENU_BAR_BACKUP_ROOT}/${provider}-${timestamp}-$$"
  destination="${directory}/preferences.plist"
  record="${MENU_BAR_STATE_DIR}/last-${provider}-backup"
  run "${helper}" export --output "${destination}" || return 1
  if [ "${DRY_RUN}" -eq 0 ]; then
    umask 077
    mkdir -p "${MENU_BAR_STATE_DIR}" || return 1
    printf '%s\n' "${destination}" > "${record}" || return 1
    chmod 600 "${record}" || return 1
  fi
  case "${provider}" in
    hiddenbar) HIDDENBAR_SWITCH_BACKUP="${destination}" ;;
    ice) ICE_SWITCH_BACKUP="${destination}" ;;
  esac
}

last_provider_backup() {
  local record="${MENU_BAR_STATE_DIR}/last-$1-backup" path=""
  if [ -r "${record}" ]; then IFS= read -r path < "${record}" || true; fi
  if [ -n "${path}" ] && [ -r "${path}" ] && /usr/bin/plutil -lint "${path}" >/dev/null 2>&1; then
    printf '%s\n' "${path}"
  fi
}

restore_or_initialize_provider() {
  local provider="$1" domain helper baseline backup
  domain="$(provider_domain "${provider}")"
  helper="$(provider_helper "${provider}")"
  baseline="$(provider_baseline "${provider}")"
  [ -x "${helper}" ] || return 1
  [ -f "${baseline}" ] || return 1
  if defaults read "${domain}" >/dev/null 2>&1; then
    note "Existing $(provider_app "${provider}") preferences found; preserving them."
    return 0
  fi
  backup="$(last_provider_backup "${provider}")"
  if [ -n "${backup}" ]; then
    note "Restoring the latest ${provider} preference backup."
    run "${helper}" import "${backup}" --initial || return 1
  else
    note "Importing the tracked initial ${provider} preferences."
    run "${helper}" import "${baseline}" --initial || return 1
  fi
}

persist_menu_bar_manager() {
  [ "${DRY_RUN}" -eq 1 ] && { note "Dry run: selection would be saved as ${MENU_BAR_MANAGER}."; return; }
  umask 077
  mkdir -p "${MENU_BAR_STATE_DIR}" || return 1
  printf '%s\n' "${MENU_BAR_MANAGER}" > "${MENU_BAR_SELECTION_FILE}.tmp" || return 1
  mv "${MENU_BAR_SELECTION_FILE}.tmp" "${MENU_BAR_SELECTION_FILE}" || return 1
  chmod 600 "${MENU_BAR_SELECTION_FILE}" || return 1
}

restore_backup_for_rollback() {
  local provider="$1" backup="$2" helper domain
  [ -n "${backup}" ] && [ -r "${backup}" ] || return 0
  helper="$(provider_helper "${provider}")"
  domain="$(provider_domain "${provider}")"
  if defaults read "${domain}" >/dev/null 2>&1; then
    "${helper}" import "${backup}" --yes >/dev/null 2>&1 || return 1
  else
    "${helper}" import "${backup}" --initial >/dev/null 2>&1 || return 1
  fi
}

rollback_menu_bar_switch() {
  note "Menu-bar switch failed; restoring the previous installation."
  [ "${DRY_RUN}" -eq 0 ] || return 1
  if [ "${PREV_HIDDENBAR_INSTALLED}" -eq 0 ] && cask_installed hiddenbar; then
    brew uninstall --cask hiddenbar >/dev/null 2>&1 || true
  fi
  if [ "${PREV_ICE_STABLE_INSTALLED}" -eq 0 ] && cask_installed jordanbaird-ice; then
    brew uninstall --cask jordanbaird-ice >/dev/null 2>&1 || true
  fi
  if [ "${PREV_ICE_BETA_INSTALLED}" -eq 0 ] && cask_installed jordanbaird-ice@beta; then
    brew uninstall --cask jordanbaird-ice@beta >/dev/null 2>&1 || true
  fi
  if [ "${PREV_HIDDENBAR_INSTALLED}" -eq 1 ] && ! cask_installed hiddenbar; then
    brew install --cask hiddenbar >/dev/null 2>&1 || true
  fi
  if [ "${PREV_ICE_STABLE_INSTALLED}" -eq 1 ] && ! cask_installed jordanbaird-ice; then
    brew install --cask jordanbaird-ice >/dev/null 2>&1 || true
  fi
  if [ "${PREV_ICE_BETA_INSTALLED}" -eq 1 ] && ! cask_installed jordanbaird-ice@beta; then
    brew install --cask jordanbaird-ice@beta >/dev/null 2>&1 || true
  fi
  restore_backup_for_rollback hiddenbar "${HIDDENBAR_SWITCH_BACKUP}" || true
  restore_backup_for_rollback ice "${ICE_SWITCH_BACKUP}" || true
  case "${PREVIOUS_MENU_BAR_MANAGER}" in
    hiddenbar|ice) /usr/bin/open -a "$(provider_app "${PREVIOUS_MENU_BAR_MANAGER}")" >/dev/null 2>&1 || true ;;
  esac
  return 1
}

apply_menu_bar_manager() {
  local desired_ice="" changes=0 remove_hiddenbar=0 remove_ice_stable=0 remove_ice_beta=0 install_cask=""
  PREV_HIDDENBAR_INSTALLED=0
  PREV_ICE_STABLE_INSTALLED=0
  PREV_ICE_BETA_INSTALLED=0
  HIDDENBAR_SWITCH_BACKUP=""
  ICE_SWITCH_BACKUP=""
  cask_installed hiddenbar && PREV_HIDDENBAR_INSTALLED=1
  cask_installed jordanbaird-ice && PREV_ICE_STABLE_INSTALLED=1
  cask_installed jordanbaird-ice@beta && PREV_ICE_BETA_INSTALLED=1
  if [ -z "${PREVIOUS_MENU_BAR_MANAGER}" ]; then
    if [ "${PREV_HIDDENBAR_INSTALLED}" -eq 1 ] && [ "${PREV_ICE_STABLE_INSTALLED}" -eq 0 ] && [ "${PREV_ICE_BETA_INSTALLED}" -eq 0 ]; then
      PREVIOUS_MENU_BAR_MANAGER=hiddenbar
    elif [ "${PREV_HIDDENBAR_INSTALLED}" -eq 0 ] && { [ "${PREV_ICE_STABLE_INSTALLED}" -eq 1 ] || [ "${PREV_ICE_BETA_INSTALLED}" -eq 1 ]; }; then
      PREVIOUS_MENU_BAR_MANAGER=ice
    fi
  fi

  if [ "${MENU_BAR_MANAGER}" = ice ]; then desired_ice="$(ice_cask)"; fi
  case "${MENU_BAR_MANAGER}" in
    hiddenbar)
      [ "${PREV_ICE_STABLE_INSTALLED}" -eq 0 ] || remove_ice_stable=1
      [ "${PREV_ICE_BETA_INSTALLED}" -eq 0 ] || remove_ice_beta=1
      [ "${PREV_HIDDENBAR_INSTALLED}" -eq 1 ] || install_cask=hiddenbar
      ;;
    ice)
      [ "${PREV_HIDDENBAR_INSTALLED}" -eq 0 ] || remove_hiddenbar=1
      if [ "${desired_ice}" = jordanbaird-ice@beta ]; then
        [ "${PREV_ICE_STABLE_INSTALLED}" -eq 0 ] || remove_ice_stable=1
        [ "${PREV_ICE_BETA_INSTALLED}" -eq 1 ] || install_cask="${desired_ice}"
      else
        [ "${PREV_ICE_BETA_INSTALLED}" -eq 0 ] || remove_ice_beta=1
        [ "${PREV_ICE_STABLE_INSTALLED}" -eq 1 ] || install_cask="${desired_ice}"
      fi
      ;;
    none)
      [ "${PREV_HIDDENBAR_INSTALLED}" -eq 0 ] || remove_hiddenbar=1
      [ "${PREV_ICE_STABLE_INSTALLED}" -eq 0 ] || remove_ice_stable=1
      [ "${PREV_ICE_BETA_INSTALLED}" -eq 0 ] || remove_ice_beta=1
      ;;
  esac
  [ "${remove_hiddenbar}" -eq 0 ] && [ "${remove_ice_stable}" -eq 0 ] && \
    [ "${remove_ice_beta}" -eq 0 ] && [ -z "${install_cask}" ] || changes=1

  heading "Menu-bar manager"
  note "Selected: ${MENU_BAR_MANAGER}"
  [ -z "${install_cask}" ] || note "Install: ${install_cask}"
  [ "${remove_hiddenbar}" -eq 0 ] || note "Back up and uninstall: hiddenbar"
  [ "${remove_ice_stable}" -eq 0 ] || note "Back up and uninstall: jordanbaird-ice"
  [ "${remove_ice_beta}" -eq 0 ] || note "Back up and uninstall: jordanbaird-ice@beta"

  if [ "${changes}" -eq 0 ]; then
    note "Installed manager already matches the selection; no package changes needed."
    persist_menu_bar_manager || die "Could not save the menu-bar manager choice."
    return
  fi
  if [ "${DRY_RUN}" -eq 0 ] && ! confirm "Apply this menu-bar manager switch?"; then
    die "Menu-bar manager switch declined."
  fi

  if [ "${remove_hiddenbar}" -eq 1 ]; then
    backup_provider hiddenbar || { rollback_menu_bar_switch; die "Could not back up Hidden Bar."; }
    quit_provider hiddenbar || { rollback_menu_bar_switch; die "Could not quit Hidden Bar."; }
    run brew uninstall --cask hiddenbar || { rollback_menu_bar_switch; die "Could not uninstall Hidden Bar."; }
  fi
  if [ "${remove_ice_stable}" -eq 1 ] || [ "${remove_ice_beta}" -eq 1 ]; then
    backup_provider ice || { rollback_menu_bar_switch; die "Could not back up Ice."; }
    quit_provider ice || { rollback_menu_bar_switch; die "Could not quit Ice."; }
  fi
  if [ "${remove_ice_stable}" -eq 1 ]; then
    run brew uninstall --cask jordanbaird-ice || { rollback_menu_bar_switch; die "Could not uninstall stable Ice."; }
  fi
  if [ "${remove_ice_beta}" -eq 1 ]; then
    run brew uninstall --cask jordanbaird-ice@beta || { rollback_menu_bar_switch; die "Could not uninstall Ice beta."; }
  fi
  if [ -n "${install_cask}" ]; then
    run brew install --cask "${install_cask}" || { rollback_menu_bar_switch; die "Could not install ${install_cask}."; }
  fi
  if [ "${MENU_BAR_MANAGER}" != none ]; then
    restore_or_initialize_provider "${MENU_BAR_MANAGER}" || { rollback_menu_bar_switch; die "Could not configure ${MENU_BAR_MANAGER}."; }
    run /usr/bin/open -a "$(provider_app "${MENU_BAR_MANAGER}")" || { rollback_menu_bar_switch; die "Could not open ${MENU_BAR_MANAGER}."; }
  fi
  persist_menu_bar_manager || { rollback_menu_bar_switch; die "Could not save the menu-bar manager choice."; }
}

resolve_menu_bar_manager
apply_menu_bar_manager

PROFILE_STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/pabu-dotfiles/profile"
PROFILE_SELECTION_FILE="${PROFILE_STATE_DIR}/selection"
DOTFILES_PROFILE="default"

saved_dotfiles_profile() {
  local saved=""
  if [ -r "${PROFILE_SELECTION_FILE}" ]; then
    IFS= read -r saved < "${PROFILE_SELECTION_FILE}" || true
  fi
  case "${saved}" in default|personal) printf '%s\n' "${saved}" ;; esac
}

resolve_dotfiles_profile() {
  local saved=""
  saved="$(saved_dotfiles_profile)"
  if [ -n "${PROFILE_REQUEST}" ]; then
    DOTFILES_PROFILE="${PROFILE_REQUEST}"
  elif [ -n "${saved}" ]; then
    DOTFILES_PROFILE="${saved}"
  fi

  heading "Dotfiles profile"
  note "Selected: ${DOTFILES_PROFILE}"
  if [ -z "${PROFILE_REQUEST}" ]; then
    if [ -n "${saved}" ]; then
      note "Preserving the saved profile; use --profile-default or --profile-personal to change it."
    else
      note "No saved profile found; using the portable default."
    fi
    return
  fi

  if [ "${DRY_RUN}" -eq 1 ]; then
    note "Dry run: profile selection would be saved as ${DOTFILES_PROFILE}."
    return
  fi

  /bin/mkdir -p "${PROFILE_STATE_DIR}" || die "Could not create profile state directory"
  printf '%s\n' "${DOTFILES_PROFILE}" > "${PROFILE_SELECTION_FILE}.tmp" || die "Could not stage profile selection"
  /bin/chmod 600 "${PROFILE_SELECTION_FILE}.tmp" || die "Could not secure profile selection"
  /bin/mv "${PROFILE_SELECTION_FILE}.tmp" "${PROFILE_SELECTION_FILE}" || die "Could not save profile selection"
  note "Saved profile selection."
}

resolve_dotfiles_profile

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

heading "JankyBorders service"
note "JankyBorders will run as a persistent per-user login service with automatic restart."
borders_service_args=(enable)
[ "${DRY_RUN}" -eq 0 ] || borders_service_args+=(--dry-run)
"${REPO_DIR}/scripts/borders-service.sh" "${borders_service_args[@]}" || \
  die "JankyBorders service setup did not complete"

heading "Trackpad gestures"
gesture_args=(enable)
[ "${DRY_RUN}" -eq 0 ] || gesture_args+=(--dry-run)
[ "${ASSUME_YES}" -eq 0 ] || gesture_args+=(--yes)
"${REPO_DIR}/scripts/trackpad-gestures.sh" "${gesture_args[@]}" || \
  die "Trackpad gesture setup did not complete"

heading "Validation"
if [ "${DRY_RUN}" -eq 1 ]; then
  note "Dry run: would validate Yazi, bordersrc, service state, and AeroSpace helpers."
  note "Dry run: would verify the selected menu-bar manager and its preferences."
  note "Dry run complete; no validation requiring installed or linked files was run."
else
  /bin/zsh -n "${REPO_DIR}/zsh/.zshrc" || die "Zsh config validation failed"
  /bin/bash -n "${REPO_DIR}/borders/.config/borders/bordersrc" || die "JankyBorders config validation failed"
  /bin/bash -n "${REPO_DIR}/scripts/borders-service.sh" || die "JankyBorders service helper validation failed"
  /bin/bash -n "${REPO_DIR}/aerospace/.config/aerospace/personal-window-router.sh" || die "AeroSpace profile router validation failed"
  /bin/bash -n "${REPO_DIR}/aerospace/.config/aerospace/start-swipeaerospace.sh" || die "SwipeAeroSpace startup helper validation failed"
  /bin/bash -n "${REPO_DIR}/scripts/trackpad-gestures.sh" || die "Trackpad gesture helper validation failed"

  command -v yazi >/dev/null 2>&1 || die "Yazi executable was not found"
  command -v ya >/dev/null 2>&1 || die "Yazi CLI executable was not found"
  YAZI_CONFIG_HOME="${REPO_DIR}/yazi/.config/yazi" yazi --debug >/dev/null || die "Yazi config validation failed"
  case "${MENU_BAR_MANAGER}" in
    hiddenbar)
      [ -d "/Applications/Hidden Bar.app" ] || die "Hidden Bar application was not found"
      defaults read com.dwarvesv.minimalbar >/dev/null 2>&1 || die "Hidden Bar preferences were not found"
      ;;
    ice)
      [ -d "/Applications/Ice.app" ] || die "Ice application was not found"
      defaults read com.jordanbaird.Ice >/dev/null 2>&1 || die "Ice preferences were not found"
      ;;
    none)
      note "No menu-bar manager selected; application validation skipped."
      ;;
  esac

  if [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
    /Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config --config-file="${REPO_DIR}/ghostty/.config/ghostty/config.ghostty" || die "Ghostty config validation failed"
  fi

  [ -d /Applications/SwipeAeroSpace.app ] || die "SwipeAeroSpace application was not found"
  "${REPO_DIR}/scripts/trackpad-gestures.sh" status || die "Trackpad gesture validation failed"

  if command -v herdr >/dev/null 2>&1; then
    HERDR_CONFIG_PATH="${REPO_DIR}/herdr/.config/herdr/config.toml" herdr config check || die "Herdr config validation failed"
  fi

  if command -v aerospace >/dev/null 2>&1 && pgrep -x AeroSpace >/dev/null 2>&1; then
    aerospace reload-config --dry-run --warnings-as-errors || die "AeroSpace config validation failed"
  else
    note "AeroSpace is not running; live config validation was skipped."
  fi

  "${REPO_DIR}/scripts/borders-service.sh" status || die "JankyBorders service validation failed"

  note "Open a new shell, use y to start Yazi, reload Ghostty, and grant AeroSpace and SwipeAeroSpace Accessibility permission if prompted."
  note "Start Neovim once to let LazyVim install its pinned plugins."
fi

heading "Complete"
note "Repository: ${REPO_DIR}"
note "Package mode: $([ "${UPGRADE}" -eq 1 ] && printf upgrade || printf install-missing-only)"
note "Dotfiles profile: ${DOTFILES_PROFILE}"
note "No unrelated Homebrew packages were removed."
