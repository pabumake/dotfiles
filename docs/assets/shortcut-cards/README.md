# Shortcut card sources

`template.svg` is the shared 1024×1536 card frame. The generated SVG sources
in this directory and the PNG files one directory above are rebuilt from the
key data in `scripts/render-shortcut-cards.mjs`.

From the repository root:

```bash
node scripts/render-shortcut-cards.mjs
```

The renderer requires `resvg` and `imagemagick-full`, both included in the
default `Brewfile`. It also regenerates `dotfiles-shortcuts-overview.png` as a
2×2 map while retaining every individual card for its documentation section.

Card accents use the managed Catppuccin Mocha palette:

- AeroSpace windows: blue → lavender
- AeroSpace workspaces: mauve → pink
- Herdr terminal: green → teal
- Yazi file manager: lavender → mauve
