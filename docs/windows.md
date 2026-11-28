---
layout: default
title: Windows bootstrap preview
---

# Windows bootstrap preview

The native Windows bootstrap is under development on
`codex/windows-setup-research`. It uses WinGet and PowerShell 7. It has isolated
tests and a Windows CI preview, but real package installation and desktop
behavior still need testing on a Windows PC before merging into `main`.

WSL, desktop window management, Scoop, and system cleanup are outside this
implementation. The existing macOS and Omarchy entry points remain separate.
The [research](research/windows-tool-coverage.md) records tool-by-tool decisions
and the remaining Windows verification work.

## Prerequisites and first run

Use Windows 11 with PowerShell 7.2 or newer and an available, permitted WinGet
source. Use your employer's existing PowerShell/App Installer installation when
provided. The bootstrap does not install WinGet, change execution policy, enable
Developer Mode, or request an elevated shell automatically.

Clone or update the feature branch, open PowerShell 7, and run from the checkout:

```powershell
git switch codex/windows-setup-research
.\setup\bootstrap-windows.ps1 -WhatIf
.\setup\bootstrap-windows.ps1
```

`-WhatIf` inspects local configuration and executables, then prints the plan.
It does not call WinGet, download trial installers, accept agreements, or write
files. Package entries without a discovered executable say `inspect/install`:
the real run will query the exact WinGet ID before deciding whether to install.
This keeps the preview useful before WinGet sources are initialized.

Real runs query WinGet with interaction disabled. If a source needs first-use
agreement, review/initialize it through WinGet first or explicitly supply
`-AcceptAgreements`. Source, policy, network, and unknown-client errors stop the
run rather than being treated as missing packages. Installer and policy failures
never trigger a fallback manager or execution-policy bypass.

## Package groups and controls

The source of truth is `setup/windows/packages.json`. Each entry declares its
logical name, exact WinGet ID, source, group, command probes, architectures, and
scopes. A normal run installs missing selected packages with `--no-upgrade`.
WinGet-recognized existing installations are kept. An executable that exists but
has no matching WinGet record is treated as externally managed and retained,
including during explicit upgrades.

| Option | Behavior |
| --- | --- |
| `-WhatIf` | Preview local changes without invoking package managers or installers |
| `-Upgrade` | Upgrade selected WinGet packages; preserve external executables |
| `-IncludePreviews` | Include FFmpeg, Poppler, resvg, and ImageMagick |
| `-IncludeTrials` | Include WezTerm and install Herdr stable when absent |
| `-Apps keeper,zen,handy` | Select only the named optional apps |
| `-Gaming` | Include Steam and WowUp-CF; off by default |
| `-SkipPackages name,...` | Exclude logical package names, including `herdr` |
| `-MachinePackages name,...` | Explicitly request machine scope for named WinGet entries |
| `-BackupConflicts` | Permit backups and replacement of conflicting managed config files |
| `-AcceptAgreements` | Explicitly accept WinGet package/source agreements |
| `-Yes` | Accept the printed setup plan without the ordinary confirmation prompt |
| `-Confirm` | Use PowerShell's additional confirmation for applying the plan |

The default group includes PowerShell, Windows Terminal, Git, Starship, eza,
Yazi, Neovim, ripgrep, fd, fzf, lazygit, Tree-sitter CLI, Node.js LTS, jq, 7-Zip,
JetBrains Mono Nerd Font, and zoxide. Preview, app, trial, and gaming groups are
opt-in per run. Omitting a flag later leaves those applications installed.
Nothing is uninstalled automatically.

### Scope and architecture

Scope defaults to `user`. The manifest conservatively treats the PowerShell
MSI, Node.js LTS MSI, 7-Zip, and font installer as machine-scope entries.
Missing entries in that set are **deferred**, not silently elevated. Existing
tools are kept. The completion output repeats anything still deferred.

When machine installation is permitted, select it for particular tools:

```powershell
.\setup\bootstrap-windows.ps1 -MachinePackages node,7zip,font -WhatIf
.\setup\bootstrap-windows.ps1 -MachinePackages node,7zip,font
```

WinGet may request UAC for those installations. `-Yes` does not grant admin
rights or override policy. Other user-scope packages can also fail if their
current installer does not support the requested scope; the script reports the
package and exit code without silently switching scope.

The manifest records x64 and ARM64 availability conservatively. An unsupported
selected architecture blocks application of the plan; exclude the named tool
with `-SkipPackages` or verify an appropriate package before editing its entry.
The script does not silently choose x64 emulation on ARM64.

### Examples

Run these inside PowerShell 7 so comma-separated array arguments are preserved:

```powershell
# Match the Yazi preview toolchain.
.\setup\bootstrap-windows.ps1 -IncludePreviews -WhatIf

# Add the workflow trials while keeping WezTerm optional.
.\setup\bootstrap-windows.ps1 -IncludeTrials -SkipPackages wezterm -WhatIf

# Opt into specific applications without changing the default browser.
.\setup\bootstrap-windows.ps1 -Apps keeper,zen -WhatIf

# Apply and allow config backups after reviewing the plan and agreements.
.\setup\bootstrap-windows.ps1 -IncludePreviews -BackupConflicts -AcceptAgreements -Yes

# Upgrade only the groups selected in this run.
.\setup\bootstrap-windows.ps1 -IncludePreviews -Upgrade
```

If a command/source is blocked by the work environment, use its approved
software-installation path. The package manifest is not an employer approval
list. The [package-manager research](research/windows-package-managers.md)
explains the distribution and scope choices.

## Configuration and shell integration

The bootstrap copies configuration to native Windows paths. It does not require
symlink privileges and never makes the repository hold application runtime data.

| Source | Destination |
| --- | --- |
| `nvim/.config/nvim/` | `%LOCALAPPDATA%\nvim\` |
| `yazi/.config/yazi/` | `%APPDATA%\yazi\config\` |
| Shared Starship config with adapted custom modules | `%LOCALAPPDATA%\pabu-dotfiles\windows\starship.toml` |
| `windows/profile.ps1` | `%LOCALAPPDATA%\pabu-dotfiles\windows\profile.ps1` |
| Managed profile loader | `$PROFILE.CurrentUserAllHosts` in PowerShell 7 |
| `windows/terminal-fragment.json` | `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\pabu-dotfiles\profiles.json` |
| Shared Herdr config, only with its trial selected | `%APPDATA%\herdr\config.toml` |

The PowerShell profile keeps existing user content and adds one marked loader
block. Repeated runs update that block. Malformed/duplicate markers and
redirected destinations, including symlinks and junctions, are rejected before
installation. The script uses the actual profile path, including a redirected
Documents folder when it is an ordinary directory.

The loader supplies `ll`, the directory-changing `y` function, Starship, and
zoxide. It preserves PowerShell's object-based `ls`. The copied Starship config
keeps the shared palette/format but runs date/git custom modules through native
PowerShell rather than `printf`, Unix `date`, or `/dev/null`.

Yazi's `file.exe` is discovered from Git for Windows, with an existing valid
`YAZI_FILE_ONE` preserved. Only known 7-Zip/ImageMagick directories are added to
the shell's PATH when present; Git's Unix tools directory is not added globally.
Open a new PowerShell session after installation. WinGet dependencies and apps
may need their own sign-in, permissions, model download, or initial setup.

The Windows Terminal fragment adds **Pabu PowerShell** and a Catppuccin Mocha
scheme without replacing `settings.json` or changing the default profile.
Select it from the terminal profile menu. If the font was deferred, install an
approved font and select its actual family name before judging glyph rendering.
Fragment paths follow [Microsoft's documented user-local extension location](https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions).

### State, backups, and local edits

Content hashes live in
`%LOCALAPPDATA%\pabu-dotfiles\windows\state.json`. Identical files are left alone.
A previously copied file can be updated automatically only when its content
still matches the recorded hash. User edits become conflicts requiring
`-BackupConflicts`. Personal changes outside the managed profile block are
preserved when the loader is updated.

Every changed existing file is backed up before replacement. Backups live under
`%LOCALAPPDATA%\pabu-dotfiles\windows\backups\<timestamp>-<unique-id>\`.
`manifest.json` records the original and backup paths. Restore the listed files
manually after inspecting that manifest. To stop shell integration, remove the
`BEGIN pabu-dotfiles windows` / `END pabu-dotfiles windows` loader block. Remove
the terminal fragment separately to remove its added profile.

The complete config plan and conflict checks precede package installation.
Destinations are checked again before the first copy to catch changes made
while installers were running. A package failure stops before config copying.
A filesystem failure can leave completed copies in place; retained backups and
per-file state allow inspection and retry. Package installation is not rolled
back automatically, and unrelated files are never pruned.

## Trials and deferred tools

Herdr uses the pinned installer URL and SHA-256 in `setup/windows/trials.json`.
The downloaded script is checked before execution in a separate `pwsh` process.
It selects upstream stable and lets the upstream installer verify its release
payload. The script itself is pinned; the stable release payload is not a full
version lock. No execution-policy bypass is added.

An existing Herdr executable is retained, even with `-Upgrade`; use Herdr's own
update controls for it. Trial inclusion also copies the shared Herdr config and
runs `herdr config check` when the executable is discoverable. Existing sessions
are not restarted. `-SkipPackages herdr` omits both its installer and config.
WezTerm is a normal WinGet trial, so selected WinGet upgrades apply to it.

ZMK Studio's [Edge/Chrome web route](https://zmk.dev/docs/features/studio) remains
the initial keyboard option. This bootstrap does not install a Windows ZMK MSI,
Mole, Orion, gh-manager, agent skills, or a C compiler. Those remaining choices
are documented in the research. No macOS plists, Omarchy shell adapters, or Linux
Input Remapper preset are installed.

## Validation before merging

Run isolated tests without installing packages:

```powershell
pwsh -NoProfile -File .\setup\test_windows_bootstrap.ps1
```

The GitHub workflow runs that suite and a real entry-point `-WhatIf` on
`windows-latest`. The package-manager calls in the suite are stubbed; the config
tests use temporary directories, real filesystem writes, and a directory
junction test on Windows. This verifies behavior without provisioning the runner.

The Python test discovery command also runs the suite when `pwsh` is on PATH.
`DOTFILES_TEST_PWSH` can select a portable test runtime on another platform.

On the intended Windows PC, verify the printed scope decisions and then test
fresh install, rerun, selected upgrade, and trials. Check PATH from a new shell,
`y` directory adoption, Unicode filenames, glyphs, archives, PDF/SVG/video
previews, and Herdr keybindings/session restore. Run `:checkhealth` in Neovim and
compile a Tree-sitter parser with the chosen approved C compiler. Missing
compiler support is reported after setup and remains a real editor limitation.
Keep the feature branch separate until those native application tests pass.
