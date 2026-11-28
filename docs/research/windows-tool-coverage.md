---
layout: default
title: Windows setup proposal and tool coverage
---

# Windows setup proposal and tool coverage

Researched on 2026-11-28 against the tools declared at repository commit
`236cd7c`. Work belongs on `codex/windows-setup-research` until Windows testing
is complete. This document proposes decisions; it does not claim a working
Windows installer. Package catalogue entries and upstream documentation were
checked from macOS, not by installing on Windows.

The target is a future work PC. Admin rights and WSL availability are unknown,
so neither is a baseline requirement. Desktop window management is excluded.
The inventory covers `Brewfile`, `Brewfile.trials`, the Omarchy package lists,
ZMK Studio, shared configs, and the skills helper.

## Recommended direction

Use native Windows 11, PowerShell 7, Windows Terminal, and **WinGet as the first
package manager**. Keep Scoop optional for an actual package or installer-scope
gap discovered during testing. Prefer an employer-provided software channel
where one exists. The [package-manager comparison](windows-package-managers.md)
explains WinGet, Scoop, Chocolatey, MSYS2, WSL, and their limitations.

This recommendation preserves the useful terminal/editor workflow without
requiring a Linux VM or translating the macOS desktop setup. It is not a
promise that each selected installer can run without elevation.

Use three decisions per tool: whether the capability belongs on the work PC,
which installation source owns it, and how much configuration can be reused.
The categories below are proposed defaults, not approved installations.

## Native CLI tools

Each linked ID was checked in Microsoft's current community manifest repository.
Catalogue presence establishes a distribution route, not tested functionality,
vendor maintenance, or permission to install. Retain one installation owner per
tool and reuse an existing suitable installation.

| Current tool | Native Windows route | Proposed decision |
| --- | --- | --- |
| Git | [`Git.Git`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/Git/Git) | Core. Also supplies the `file.exe` needed by Yazi. |
| Starship | [`Starship.Starship`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/s/Starship/Starship) | Core. Reuse visual settings after adapting custom shell commands. |
| eza | [`eza-community.eza`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/e/eza-community/eza) | Core. Keep the existing `ll` behavior through a PowerShell function. |
| Yazi | [`sxyazi.yazi`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/s/sxyazi/yazi) | Core. Port the directory-changing `y` wrapper. |
| Neovim | [`Neovim.Neovim`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/n/Neovim/Neovim) | Core. Reuse Lua configuration and lockfile after Windows health checks. |
| ripgrep | [`BurntSushi.ripgrep.MSVC`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/b/BurntSushi/ripgrep/MSVC) | Core. |
| fd | [`sharkdp.fd`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/s/sharkdp/fd) | Core. |
| fzf | [`junegunn.fzf`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/j/junegunn/fzf) | Core. |
| lazygit | [`JesseDuffield.lazygit`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/j/JesseDuffield/lazygit) | Core. |
| Tree-sitter CLI | [`tree-sitter.tree-sitter-cli`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/t/tree-sitter/tree-sitter-cli) | Editor dependency. A separate working C compiler is still needed. |
| Node.js | [`OpenJS.NodeJS.LTS`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/o/OpenJS/NodeJS/LTS) | Install only if a suitable runtime is absent. Propose LTS rather than blindly matching Homebrew's current `node`. |
| jq | [`jqlang.jq`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/j/jqlang/jq) | Core and Yazi JSON previews. |
| sevenzip / 7zip | [`7zip.7zip`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/7/7zip/7zip) | Core. Verify command discovery and the full archive tools rather than a standalone extractor. |
| ffmpeg-full / ffmpeg | [`Gyan.FFmpeg`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/Gyan/FFmpeg) | Include in the preview group; verify codecs needed by actual files. Package names do not prove Homebrew build parity. |
| Poppler | [`oschwartz10612.Poppler`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/o/oschwartz10612/Poppler) | Preview group. This is a third-party Windows build; verify its upstream download and PDF tools. |
| resvg | [`linebender.resvg`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/l/linebender/resvg) | Preview group. Current portable package supports x64 and ARM64. |
| imagemagick-full / imagemagick | [`ImageMagick.ImageMagick`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/i/ImageMagick/ImageMagick) | Preview group. Verify delegates and `magick` discovery. |

The extra native shell and host packages are
[`Microsoft.PowerShell`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/PowerShell)
and [`Microsoft.WindowsTerminal`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/WindowsTerminal).
Do not replace an employer-managed terminal or shell installation automatically.

LazyVim requires Tree-sitter CLI, a C compiler, and curl in addition to its
editor/search tooling. An installed Neovim binary alone is insufficient. Choose
the compiler against the actual plugins and the available work-PC toolchain;
do not make a large Visual Studio installation an implicit prerequisite.
[LazyVim requirements](https://www.lazyvim.org/#%EF%B8%8F-requirements)

### Yazi parity requires more than packages

Set `YAZI_FILE_ONE` to the actual Git for Windows `usr\bin\file.exe` location.
Use discovery rather than assuming `C:\Program Files\Git`. Yazi specifically
discourages separate Scoop/Chocolatey `file` packages because of Unicode and
argument support. [Yazi Windows prerequisites](https://yazi-rs.github.io/docs/installation/#windows)

Current Yazi docs still claim WinGet lacks resvg. The newer
[`linebender.resvg` installer manifest](https://github.com/microsoft/winget-pkgs/blob/master/manifests/l/linebender/resvg/0.50.0/linebender.resvg.installer.yaml)
provides upstream ZIPs with hashes, so this is a documentation lag, not a reason
to require Scoop. Check whether the target WinGet client supports that manifest.

Windows Terminal supports Yazi image previews through Sixel from version
1.22.10352.0. Preview behavior must also be tested inside Herdr, where the
multiplexer is another layer. [Yazi terminal support](https://yazi-rs.github.io/docs/image-preview/)

## Tools requiring a separate decision

| Current capability | Evidence and Windows route | Proposed decision |
| --- | --- | --- |
| Ghostty terminal host | The official GUI has no Windows distribution; the 1.4 release notes dropped its Windows GUI roadmap. [Ghostty release notes](https://ghostty.org/docs/install/release-notes/1-4-0) | Replace with Windows Terminal initially. It provides tabs and panes. [Microsoft pane documentation](https://learn.microsoft.com/en-us/windows/terminal/panes) |
| Herdr workspaces and sessions | Native ConPTY support is now generally available, with stable and preview channels. An official PowerShell installer exists. [Windows support](https://herdr.dev/tui/docs/windows-beta/), [installer source](https://github.com/herdrdev/herdr/blob/master/distribution/install.ps1) | Keep as a local trial until this repository's keybindings, session restore, notifications, and previews pass. Use upstream stable; a local trial does not require upstream preview. |
| Alternative terminal | WezTerm supports Windows and offers multiplexing and image protocols. [WezTerm features](https://wezterm.org/features.html) | Optional terminal trial if Windows Terminal fails a concrete workflow test. No need to install two hosts by default. |
| Zsh and Bash overlays | The current shell files invoke POSIX commands, Homebrew, and Unix initialization. | Write a native PowerShell profile. Git Bash can remain available with Git; WSL/Zsh is optional. Do not source these files as PowerShell. |
| GNU Stow | The repository relies on Unix home-relative paths; native Windows app paths differ. | Use explicit Windows config destinations and backup-aware copies first. Add optional links only after testing privilege and filesystem behavior. Do not introduce a second dotfile manager just to install packages. |
| rsync and archive utility | The current archive script is a separate workflow with rsync, Unix paths, NAS validation, and deletion safeguards. Windows has `robocopy`. [Microsoft documentation](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy) | Defer the archive workflow. Robocopy can cover some copy jobs but is not a drop-in port of the verified archive/purge logic. WSL rsync can be evaluated separately if needed. |
| gh-manager | Its own repository documents a native PowerShell installer and user-local Windows binary. [Upstream README](https://github.com/pabumake/gh-manager/blob/main/README.md) | Remain configuration-only initially, matching this repository's other platforms. Native binary installation is a separate opt-in decision. |
| Mole | A separate native Windows source branch exists, but its README explicitly calls it experimental and unsuitable for critical machines. [Windows branch](https://github.com/tw93/Mole/tree/windows) | Exclude from the work baseline. Do not treat the Homebrew CLI as already portable or run cleanup during provisioning. |
| Vorssaint | The repository tracks a macOS application and plist settings. | Do not port the plist or assume one equivalent app. Select individual needed capabilities later. PowerToys Awake is one possible keep-awake equivalent, not a full replacement. [Awake documentation](https://learn.microsoft.com/en-us/windows/powertoys/awake) |
| PokeTokenBar | Installed as a macOS cask in this repository; no Windows package was verified in this pass. | Defer usage/cost display until a Windows requirement and maintained source are selected. |

Herdr's current support page labels native Windows generally available despite
its historical `windows-beta` URL. Some capabilities still differ, including
live shell directory reporting and terminal-dependent graphics. Avoid using old
issues as proof that Herdr requires WSL. [Current Windows support matrix](https://herdr.dev/tui/docs/windows-beta/)

## Optional applications and personal tools

These should be separate from the initial work CLI profile. Availability does
not establish whether an employer permits a browser, password manager,
microphone app, device tool, or game client.

| Tool | Verified native route | Proposed decision |
| --- | --- | --- |
| Keeper | [`KeeperSecurity.KeeperDesktop`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/k/KeeperSecurity/KeeperDesktop) | Opt in if this is the approved work password manager. Leave vaults and sign-in local. |
| Zen Browser | [`Zen-Team.Zen-Browser`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/z/Zen-Team/Zen-Browser) | Optional browser. Preserve the current default browser. |
| Orion trial | Kagi ended Windows development and says its planned Windows release will not be launched by Kagi. [October 2026 announcement](https://blog.kagi.com/update-orion-linux-windows) | Exclude. Do not carry the macOS Orion trial into Windows by name alone. |
| Handy | [`cjpais.Handy`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/c/cjpais/Handy); upstream documents Windows support and notes the WinGet package is community maintained. [Handy README](https://github.com/cjpais/Handy) | Optional dictation trial. Use native shortcuts; do not copy the Omarchy adapter. Test microphone, model download, and paste behavior. |
| ZMK Studio | Official Windows MSI/EXE releases and an Edge/Chrome web route are documented. [ZMK guide](https://zmk.dev/docs/features/studio), [0.3.1 release assets](https://github.com/zmkfirmware/zmk-studio/releases/tag/v0.3.1) | Optional keyboard setup. Prefer the web route for a first test when permitted; otherwise review and pin the Windows installer and its own checksum. No WinGet ID was verified. |
| JetBrains Mono Nerd Font | [`DEVCOM.JetBrainsMonoNerdFont`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/d/DEVCOM/JetBrainsMonoNerdFont); Scoop's nerd-fonts bucket also has [`JetBrainsMono-NF-Mono`](https://github.com/matthewjberger/scoop-nerd-fonts/blob/master/bucket/JetBrainsMono-NF-Mono.json) | Include a suitable font, but inspect the third-party font installer and available scope. Configure the terminal to actually use it. |
| Symbols-only Nerd Font | A separate font is declared on macOS. | Defer unless glyph tests show it is needed in addition to the chosen Nerd Font. No extra package ID was verified. |
| Steam | [`Valve.Steam`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/v/Valve/Steam) | Personal gaming profile only, off on the work baseline. |
| WowUp-CF | [`WowUp.CF`](https://github.com/microsoft/winget-pkgs/tree/master/manifests/w/WowUp/CF) | Personal gaming profile only. |
| Input Remapper / Orbweaver | The tracked preset is in Linux input-event format and the helper uses Linux paths and `pkexec`. | Do not copy the preset to Windows. Defer device-specific remapping to a separate hardware decision. |
| OpenCode | Current upstream provides native Windows binaries and explicitly says Windows package managers are unsupported. [Installation](https://opencode.ai/docs/) | Optional. Select the intended major version before choosing a distribution route; do not assume an old package ID matches current upstream. |
| Hermes | Official native Windows support and a PowerShell installation route now exist; WSL is optional. [Native Windows guide](https://hermes-agent.nousresearch.com/docs/user-guide/windows-native) | Optional. Port skills setup only after checking the Windows install's paths and configuration, rather than running the existing Bash helper. |

AeroSpace, JankyBorders, SwipeAeroSpace, Hidden Bar, Thaw, Hyprland overlays, and
Omarchy bar plugins are excluded from this Windows work. This includes searching
for Windows tiling replacements. Cliamp and Ice remain retired.

## Configuration portability

Package installation and configuration need separate Windows logic. The first
implementation should use an explicit destination map and keep application
runtime data out of the Git checkout.

| Tracked source | Windows target or adaptation | Status |
| --- | --- | --- |
| `nvim/.config/nvim/` | `%LOCALAPPDATA%\nvim\` | Reuse candidate. Keep `%LOCALAPPDATA%\nvim-data` separate. [Neovim paths](https://neovim.io/doc/user/starting/#standard-path) |
| `yazi/.config/yazi/` | `%APPDATA%\yazi\config\` | Reuse candidate. [Yazi paths](https://yazi-rs.github.io/docs/configuration/overview/) |
| `herdr/.config/herdr/config.toml` | `%APPDATA%\herdr\config.toml` | Reuse candidate after `herdr config check`; test the notification and keybinding settings. [Herdr configuration](https://herdr.dev/tui/docs/configuration/) |
| `starship/.config/starship.toml` | Explicit `STARSHIP_CONFIG` in the PowerShell profile | Adapt first. The current custom modules use `date`, `printf`, POSIX negation, and `/dev/null`. A Windows OS icon does not make those commands portable. [Starship config override](https://starship.rs/config/#config-file-location) |
| Zsh/Bash initialization | PowerShell-managed block in `$PROFILE.CurrentUserAllHosts` | Port `ll`, `y`, Starship, and zoxide initialization deliberately. Discover the profile path at runtime, including redirected Documents folders. [PowerShell profiles](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles) |
| `gh-manager/.config/gh-manager/` | Resolve through the selected Windows build | Defer destination verification; preserve configuration-only status. |
| Shared agent skills | Native Windows consumer paths | A separate port of the skills installation/configuration flow is needed. The present `scripts/setup-skills.sh` delegates to a Bash installer. |

Prefer backup-aware copies initially so Developer Mode and symlink rights are
not prerequisites. Treat links as an explicit, tested option. Windows supports
file symlinks and directory junctions, with different privilege and path rules;
they are not interchangeable. [PowerShell link documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item)

Do not globally redefine XDG paths to make all Windows programs look like Unix.
Use each application's documented path or override. Preserve PowerShell's
object-based `ls` command by default and expose the eza equivalent as `ll`.
The shell, config-copy, and alias choices here are proposed project behavior.

## Proposed implementation after decisions

Add a separate `setup/bootstrap-windows.ps1` and curated Windows package data.
Keep the macOS and Omarchy entry points independent. A future package record
should contain logical tool, manager, exact package ID, source, desired scope,
architecture restrictions, group, and verification command. Store direct
downloads with a pinned version and checksum. Do not populate these records by
exporting everything installed on a work PC.

Proposed groups are core CLI, media previews, optional applications, trials,
and personal gaming. Core should start with shell/terminal, Git, editor/search
tools, prompt/navigation, archive/JSON tools, and the chosen font. Include the
preview group when matching the current Yazi workflow is desired.

The wrapper should support PowerShell `-WhatIf`, explicit upgrades,
`-IncludeTrials`, conflict backups, and clear reporting of unsupported or
blocked packages. A normal run installs missing declared tools and leaves
existing versions alone. Omitting a trial flag later leaves its tools installed.
Upgrades affect only selected declarations. WinGet's `--no-upgrade` provides the
package-level building block. [WinGet install options](https://learn.microsoft.com/en-us/windows/package-manager/winget/install)

Request user scope only where a compatible installer exists. Report unavailable
scope rather than silently escalating or changing package managers. Do not
enable WSL, change execution policy, or replace a managed browser by default.
These choices follow the user's unknown-admin/optional-WSL constraint.

If WSL is later selected, treat it as a separate Linux environment. The current
Omarchy bootstrap requires an Omarchy desktop and cannot serve as an Ubuntu
WSL bootstrap. Unix CLI tools can share configuration selectively without
enabling Hyprland or running Omarchy's desktop setup.

## Testing required before merging

1. On the actual Windows architecture, confirm WinGet/client versions, allowed
   sources, and installer scope for every selected package. Start as a normal
   user with WSL absent.
2. Test a read-only plan, fresh installation, repeated run, partial package
   failure, existing manually installed tools, and explicit upgrades. Check
   PATH both immediately and from a new PowerShell session.
3. Back up conflicting configs and preserve unrelated profile content. Test
   a username/path containing spaces, Unicode filenames, redirected Documents,
   missing symlink rights, and existing links without editing their owners.
4. Run Neovim/LazyVim health checks, compile a Tree-sitter parser, and verify
   plugin installation against the tracked lockfile. Confirm a real C compiler.
5. Exercise `ll`, zoxide, Starship custom modules, and `y` directory adoption.
   In Yazi, test images, video, PDF, SVG, archives, JSON, clipboard, and Unicode.
6. For Herdr, verify the prefix map, pane creation, git/worktree detection,
   detach/reattach, restored sessions, notifications, and Yazi previews. Keep
   Windows Terminal usable without it throughout the trial.
7. Test trial inclusion, omission, upgrade selection, and explicit retirement.
   Confirm unrelated packages are never removed.
8. Record Windows build, architecture, package versions, scope, and results.
   Only then describe Windows as supported or merge an installer into `main`.

## Decisions still open

- Confirm WinGet as the initial owner, subject to the eventual work PC's
  permitted sources and scopes. No proven coverage gap currently requires Scoop.
- Confirm Windows Terminal as the default host and Herdr stable as the first
  local workflow trial. WezTerm remains an alternative, not another default.
- Choose which optional apps belong on the work PC, especially Keeper, browser,
  Handy, and keyboard tools. Keep gaming and experimental cleanup out of it.
- Select a compatible C compiler and Node runtime policy when the work-machine
  development requirements and admin rights are known.
