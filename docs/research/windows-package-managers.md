---
layout: default
title: Windows package-manager research
---

# Windows package-manager research

Researched on 2026-11-28 for the Windows setup feature branch. This is a
proposal based on official documentation and source code. No installation or
rerun behavior has been verified on a Windows machine.

## Recommendation

Start with WinGet alone for the native Windows baseline. Keep Scoop as an
optional answer to a demonstrated package or installer-scope gap, not a required
second manager. Give each tool one installation owner. Do not install both
managers' copies of the same executable.

This is a project recommendation, not a claim that WinGet has every tool or
that the employer permits it. WinGet is delivered through Windows App Installer,
supports existing installer formats and portable packages, and exposes separate
install and upgrade commands. Those properties fit the repository's existing
install-only default. App Installer can be absent, and some installers still
require elevation. [Microsoft's WinGet overview](https://learn.microsoft.com/en-us/windows/package-manager/winget/)

Yazi's Windows instructions still say `resvg` is unavailable through WinGet.
The current WinGet catalog contradicts that statement: `linebender.resvg`
0.50.0 has portable ZIP installers for x64 and ARM64, with upstream GitHub
release URLs and hashes. Prefer the current manifest for this availability
decision. That removes the main apparent reason to require Scoop for Yazi's
preview dependencies. Source inspection is not an installed-package test.
[Yazi's instructions](https://yazi-rs.github.io/docs/installation/#windows),
[current WinGet resvg installer manifest](https://github.com/microsoft/winget-pkgs/blob/master/manifests/l/linebender/resvg/0.50.0/linebender.resvg.installer.yaml)

## Manager comparison

| Manager | Suitable role here | State and installation behavior | Decision |
| --- | --- | --- | --- |
| WinGet | Native applications and most selected CLI tools | JSON package lists through export/import; individual installs support exact IDs, source, architecture, version, and scope selection. `install` and `import` both provide `--no-upgrade`. | Preferred initial manager. [Install](https://learn.microsoft.com/en-us/windows/package-manager/winget/install), [import](https://learn.microsoft.com/en-us/windows/package-manager/winget/import) |
| Scoop | User-local CLI tools where a selected WinGet package proves unsuitable | PowerShell-based; exports apps and buckets, optionally config. Packages come from Git repositories called buckets. | Optional, subject to a concrete need and target-machine permission. [Commands](https://github.com/ScoopInstaller/Scoop/wiki/Commands), [buckets](https://github.com/ScoopInstaller/Scoop/wiki/Buckets) |
| Chocolatey | An existing employer-managed software distribution path | Supports XML `packages.config` and export, including optional version numbers. | Prefer it if IT already provides a vetted feed; do not introduce a third manager by default. [Install](https://docs.chocolatey.org/en-us/choco/commands/install/), [export](https://docs.chocolatey.org/en-us/choco/commands/export/) |
| MSYS2 | A targeted POSIX/build-tool requirement | Provides a Unix-like environment, native Windows toolchains, and package management. Its environments use distinct runtimes, architecture, and toolchain settings. | Optional compatibility environment, not the general app baseline. [MSYS2 overview](https://www.msys2.org/docs/what-is-msys2/), [environments](https://www.msys2.org/docs/environments/) |
| WSL | A separate Linux development profile | Runs a Linux distribution and its utilities. Microsoft's initial setup uses an elevated shell and a restart. | Optional only after confirming availability; not a substitute for researching native Windows tools. [WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install) |

## Reproducibility and update control

WinGet export writes a JSON package list. Versions are optional and omitted by
default. Import can request specific versions, ignore them, or preserve already
installed versions with `--no-upgrade`. Maintain a curated manifest instead of
committing a complete export from a work machine. A package list does not
capture application settings, shell profiles, credentials, or every dependency.
[Export schema and behavior](https://learn.microsoft.com/en-us/windows/package-manager/winget/export),
[import schema and behavior](https://learn.microsoft.com/en-us/windows/package-manager/winget/import)

For the first implementation, recommend a PowerShell wrapper with one explicit
package ID and source per entry. Its ordinary path should use
`winget install --id ID --exact --source SOURCE --no-upgrade`; an upgrade option
should affect only declared entries. Keep standard and trial lists separate.
These commands are proposed semantics, not Windows test results.
[WinGet installation options](https://learn.microsoft.com/en-us/windows/package-manager/winget/install)

WinGet Configuration can combine packages with machine settings through DSC
resources. Microsoft recommends reviewing both the configuration and its
resources before execution. Defer it until the initial package and config-link
behavior is tested; a small package wrapper will be easier to compare with the
current macOS and Omarchy bootstraps.
[WinGet configure](https://learn.microsoft.com/en-us/windows/package-manager/winget/configure)

Scoop's export records installed apps and bucket sources. Its current import
implementation selects ordinary bucket packages as `bucket/name`; the exported
version is used for the special auto-generated package case, not as a general
lock for bucket entries. Treat a Scoopfile as a restoration list, not an exact
version lock. If exact versions become necessary, design and test pinned or
vendored manifests separately.
[Scoop export source](https://raw.githubusercontent.com/ScoopInstaller/Scoop/master/libexec/scoop-export.ps1),
[Scoop import source](https://raw.githubusercontent.com/ScoopInstaller/Scoop/master/libexec/scoop-import.ps1)

Scoop separates updating the manager and bucket manifests from updating apps:
`scoop update` refreshes Scoop, while `scoop update APP` or `scoop update *`
updates applications. Install operations may refresh Scoop metadata. The future
wrapper should inspect installed apps first and make application upgrades an
explicit action.
[Scoop quick start](https://github.com/ScoopInstaller/Scoop/wiki/Quick-Start)

## Scope and work-PC constraints

WinGet's `--scope user` requests a user-scoped installer; it does not turn a
machine-only installer into a user install. Do not append it indiscriminately.
Check scope per package and report packages that require unavailable elevation.
[Installer scope selection](https://learn.microsoft.com/en-us/windows/package-manager/winget/install),
[administrator considerations](https://learn.microsoft.com/en-us/windows/package-manager/winget/#administrator-considerations)

Scoop's installer defaults to a non-elevated user installation and disables
running in an administrator console unless explicitly requested. Its documented
prerequisites include PowerShell 5.1+ and an execution policy allowing scripts.
Whether that model is allowed on the work PC is still unknown; the bootstrap
should not change execution policy automatically.
[Scoop installer](https://github.com/ScoopInstaller/Install),
[Scoop prerequisites](https://github.com/ScoopInstaller/Scoop/wiki/Quick-Start)

Chocolatey's default setup uses an administrative shell. Its own documentation
describes non-administrative installation as an advanced, limited fallback.
This makes it less attractive as a new user-managed default when local admin
rights are unknown.
[Chocolatey installation options](https://docs.chocolatey.org/en-us/choco/setup/)

Windows policy can disable WinGet use and restrict default, allowed, or
enterprise-provided sources. A command existing on `PATH` is therefore not
proof that installation is permitted. Use the available enterprise path when
one exists; do not automatically fall back to another manager after a policy
rejection.
[Desktop App Installer policies](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-desktopappinstaller)

## Package provenance

The public WinGet manifest repository accepts contributions and applies
automated validation and package-policy checks. Repository inclusion should
not be described as vendor authorship or employer approval. Record the exact
ID, source, installer architecture, and intended scope for every selected tool.
[Microsoft's manifest-submission process](https://learn.microsoft.com/en-us/windows/package-manager/package/repository)

Scoop buckets are Git repositories of manifests and can be created by anyone.
Restrict any proposed supplement to reviewed manifests in selected buckets;
adding a bucket is a deliberate source decision. Chocolatey likewise separates
its manager from community packages, whose PowerShell instructions often fetch
vendor downloads. Chocolatey's organizational guidance recommends controlled
internal feeds and binaries.
[Scoop buckets](https://github.com/ScoopInstaller/Scoop/wiki/Buckets),
[Chocolatey organizational guidance](https://docs.chocolatey.org/en-us/information/security/#organizational-use-of-chocolatey)

One important tool-specific exception: Yazi recommends Git for Windows'
`file.exe` through `YAZI_FILE_ONE`. It advises against standalone Scoop or
Chocolatey `file` packages because of filename and option limitations. A
manager-level coverage count would miss that requirement.
[Yazi's Windows prerequisites](https://yazi-rs.github.io/docs/installation/#windows)

## Decisions before implementation

1. Confirm Windows version and architecture, the available elevation model,
   and whether App Installer and the selected package sources are permitted.
   Admin rights and WSL availability are currently unknown; both stay optional.
2. Test the WinGet package set first, including `linebender.resvg`. Only propose
   Scoop for a remaining verified gap or a suitable user-local installer variant
   that the work PC permits. Keep package ownership stable between reruns.
3. Confirm the WinGet client version supports the selected manifest and
   installer features. The inspected resvg manifest uses schema 1.28.0; catalog
   availability alone does not prove compatibility with an older work-PC client.
4. Keep WSL and MSYS2 opt-in. If selected, distinguish their files, PATH,
   packages, and shell initialization from native Windows state.
5. Test fresh install, repeat install, partial failure, explicit upgrade,
   trials, configuration backups, and non-admin behavior on Windows before
   merging the feature branch.

No manager choice establishes feature parity by itself. The per-tool proposal
must separately check native Windows support, configuration paths, terminal
behavior, package provenance, and whether an equivalent is actually wanted.
