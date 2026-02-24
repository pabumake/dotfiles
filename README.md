# Pabus dotfiles
This is work in progress

# Understanding Stow location

dotfile exists in ------------------> gnu stow storage

				      Always has the package name in front followed by the folder location
~/.config/nvim    ------------------> nvim/.config/nvim
~/.config/ghostty ------------------> ghostty/.config/ghostty

# Moving exiting config

`mv ~/.config/nvim/ /nvim/.config/nvim/`

# Enable Stow linking

`stow nvim`

this is then enabled, probably the tool needs a restart to see effect
