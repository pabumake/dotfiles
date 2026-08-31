######################
# Aliases
######################
# Quick update brew packages
alias brup="brew update && brew upgrade"

# Cls alias
alias cls="clear"

######################
# Applications
######################
# Prefer the first installed VS Code variant for tools that open an external editor.
for external_editor in codium code code-insiders; do
  if command -v "$external_editor" >/dev/null 2>&1; then
    export VISUAL="$external_editor --wait"
    export EDITOR="$VISUAL"
    break
  fi
done
unset external_editor

######################
# Fast Access Folders
######################
# alias pbproj="cd $HOME/Documents/03-coding-projects/"

######################
# Command Replacements
######################
# brew install eza required
alias ls="eza --icons --group-directories-first -A"
alias ll="eza --icons --group-directories-first -lA"
