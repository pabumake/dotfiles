# Start Yazi and adopt its final directory after a normal quit.
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd

  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [[ "$cwd" != "$PWD" && -d "$cwd" ]] && builtin cd -- "$cwd"
  command rm -f -- "$tmp"
}
