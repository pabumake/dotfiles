##############################
# external configuration
##############################
[[ -f ~/.zsh/aliases.zsh ]] && source ~/.zsh/aliases.zsh
[[ -f ~/.zsh/starship.zsh ]] && source ~/.zsh/starship.zsh
[[ -f ~/.zsh/yazi.zsh ]] && source ~/.zsh/yazi.zsh
# Currently disabled, caused error on macos
#[[ -f ~/.zsh/wsl2fix.zsh ]] && source ~/.zsh/wsl2fix.zsh:

# Only available in Work environments
[[ -r "${HOME}/.zsh/work-aliases.zsh" ]] && source "${HOME}/.zsh/work-aliases.zsh"

##############################
# Homebrew and Starship configuration
##############################
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Yazi's full media preview tools are keg-only; expose them without force-linking.
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  for yazi_tool in ffmpeg-full imagemagick-full; do
    yazi_tool_bin="${HOMEBREW_PREFIX}/opt/${yazi_tool}/bin"
    if [[ -d "${yazi_tool_bin}" ]]; then
      path=("${yazi_tool_bin}" ${path:#${yazi_tool_bin}})
    fi
  done
  unset yazi_tool yazi_tool_bin
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

##############################
# brew updater configuration
##############################
alias forceupdate='brew update && brew upgrade && brew install --cask --force `brew list --cask` && brew cleanup -s && brew cleanup --prune 0 && rm -rf "$(brew --cache)"'
