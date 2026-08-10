##############################
# external configuration
##############################
[[ -f ~/.zsh/aliases.zsh ]] && source ~/.zsh/aliases.zsh
[[ -f ~/.zsh/starship.zsh ]] && source ~/.zsh/starship.zsh
# Currently disabled, caused error on macos
#[[ -f ~/.zsh/wsl2fix.zsh ]] && source ~/.zsh/wsl2fix.zsh:

# Only available in Work environments
[[ -f ~/.zsh/starship.zsh ]] && source ~/.zsh/work-aliases.zsh

##############################
# Homebrew and Starship configuration
##############################
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

##############################
# brew updater configuration
##############################
alias forceupdate='brew update && brew upgrade && brew install --cask --force `brew list --cask` && brew cleanup -s && brew cleanup --prune 0 && rm -rf "$(brew --cache)"'
