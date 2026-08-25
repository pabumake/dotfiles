# Vorssaint settings

Vorssaint's supported settings backup belongs at `vorssaint/settings.plist`.
Create it in Vorssaint 3.3.2 or newer with **Settings → Advanced → Export
Settings**. Review the file before committing it because portable settings can
include scratchpad text, snippets, saved links, and per-app choices.

On another Apple Silicon Mac, run bootstrap and then use **Settings → Advanced
→ Import Settings** in Vorssaint. Select the tracked `settings.plist`. Vorssaint
validates the file, applies the portable settings, and relaunches itself.

macOS permissions, clipboard history, machine-specific device state, and file
access grants are not part of the backup. Configure those separately on each
Mac.
