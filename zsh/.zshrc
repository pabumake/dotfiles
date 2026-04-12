##############################
# external configuration
##############################
[[ -f ~/.zsh/aliases.zsh ]] && source ~/.zsh/aliases.zsh
[[ -f ~/.zsh/starship.zsh ]] && source ~/.zsh/starship.zsh
# Currently disabled, caused error on macos
#[[ -f ~/.zsh/wsl2fix.zsh ]] && source ~/.zsh/wsl2fix.zsh:

##############################
# starship configuration
##############################
eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(starship init zsh)"

##############################
# brew updater configuration
##############################
alias forceupdate='brew update && brew upgrade && brew install --cask --force `brew list --cask` && brew cleanup -s && brew cleanup --prune 0 && rm -rf "$(brew --cache)"'

