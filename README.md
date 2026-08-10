# Pabu's dotfiles

This is a work in progress.

## Understanding the Stow layout

```bash
dotfile location -------------------> GNU Stow package

Each package repeats the path that should be created below the target directory.

~/.config/nvim     -----------------> nvim/.config/nvim
~/.config/ghostty  -----------------> ghostty/.config/ghostty
~/.aerospace.toml  -----------------> aerospace/.aerospace.toml
```

## Moving an existing config into a package

```bash
mv ~/.config/nvim ~/Documents/dotfiles/nvim/.config/nvim
```

## Enable Stow linking

Run Stow from the repository root and explicitly target the home directory:

```bash
cd ~/Documents/dotfiles
stow --target="$HOME" nvim
stow --target="$HOME" aerospace
```

Restart or reload the relevant application after linking its configuration.

## Remove Stow links

```bash
cd ~/Documents/dotfiles
stow --delete --target="$HOME" aerospace
```

The package files remain in the repository; only the generated links are removed.

## Restoring on a new device

```bash
cd ~/Documents/dotfiles
stow --target="$HOME" starship
stow --target="$HOME" aerospace
```
