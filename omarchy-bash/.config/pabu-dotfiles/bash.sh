# Loaded after Omarchy's Bash defaults. Do not initialize prompt/tools twice.
[[ $- == *i* ]] || return 0

alias cls='clear'
if command -v eza >/dev/null 2>&1; then
  alias ll='eza --icons --group-directories-first -lA'
fi

# Start Yazi and adopt its final directory after quitting.
y() {
  local tmp cwd result
  tmp=$(mktemp -t yazi-cwd.XXXXXX) || return
  command yazi "$@" --cwd-file="$tmp"
  result=$?
  cwd=$(cat -- "$tmp")
  command rm -f -- "$tmp"
  if [[ -n "$cwd" && "$cwd" != "$PWD" && -d "$cwd" ]]; then
    builtin cd -- "$cwd" || return
  fi
  return "$result"
}
