#Requires -Version 7.2
<#
.SYNOPSIS
Install native Windows tools and backed-up user configuration from this checkout.
.EXAMPLE
pwsh -NoProfile -File .\setup\bootstrap-windows.ps1 -WhatIf
.EXAMPLE
pwsh -NoProfile -File .\setup\bootstrap-windows.ps1 -IncludePreviews -BackupConflicts
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Upgrade,
    [switch]$IncludePreviews,
    [switch]$IncludeTrials,
    [ValidateSet('keeper', 'zen', 'handy')][string[]]$Apps = @(),
    [switch]$Gaming,
    [string[]]$SkipPackages = @(),
    [string[]]$MachinePackages = @(),
    [switch]$BackupConflicts,
    [switch]$AcceptAgreements,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows/bootstrap-functions.ps1')
try {
    if (-not $IsWindows) { throw 'This bootstrap requires Windows. Run the isolated tests on other platforms.' }
    if (-not $env:LOCALAPPDATA -or -not $env:APPDATA) { throw 'LOCALAPPDATA and APPDATA must be set.' }
    $repo = Split-Path -Parent $PSScriptRoot
    $packages = @(Read-DotfilesPackages (Join-Path $PSScriptRoot 'windows/packages.json'))
    $selected = @(Select-DotfilesPackages -Packages $packages -IncludePreviews:$IncludePreviews -IncludeTrials:$IncludeTrials `
        -Apps $Apps -Gaming:$Gaming -SkipPackages $SkipPackages -MachinePackages $MachinePackages)
    $architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    $stateRoot = Join-Path $env:LOCALAPPDATA 'pabu-dotfiles/windows'
    $statePath = Join-Path $stateRoot 'state.json'
    $state = Read-DotfilesState $statePath
    $configs = @(Get-DotfilesConfigPlan -Repo $repo -LocalAppData $env:LOCALAPPDATA -AppData $env:APPDATA `
        -ProfilePath $PROFILE.CurrentUserAllHosts -State $state -IncludeTrials:($IncludeTrials -and 'herdr' -notin $SkipPackages))
    if (-not $WhatIfPreference -and -not (Find-DotfilesApplication 'winget.exe')) { throw 'WinGet is required. Install or enable approved Windows App Installer first.' }
    $plan = @(Get-DotfilesPackagePlan -Packages $selected -Architecture $architecture -Upgrade:$Upgrade `
        -Offline:$WhatIfPreference -AcceptAgreements:$AcceptAgreements -MachinePackages $MachinePackages)
    $trials = @()
    if ($IncludeTrials) {
        $trials = @((Get-Content -LiteralPath (Join-Path $PSScriptRoot 'windows/trials.json') -Raw | ConvertFrom-Json).scripts |
            Where-Object { $_.name -notin $SkipPackages -and -not (Find-DotfilesApplication $_.command) })
    }
    Write-Host "Repository: $repo`nWindows architecture: $architecture"
    foreach ($item in $plan) { Write-Host "Package $($item.Action): $($item.Package.name) [$($item.Package.id), $($item.Scope)]" }
    foreach ($trial in $trials) { Write-Host "Trial install: $($trial.name) [pinned upstream installer, stable channel]" }
    foreach ($item in $configs) { if ($item.Action -ne 'keep') { Write-Host "Config $($item.Action): $($item.Path)" } }
    Write-Host 'Existing executables outside WinGet are retained. Package scope defaults to user.'
    $deferred = @($plan | Where-Object Action -eq 'deferred-scope' | ForEach-Object { $_.Package.name })
    if ($deferred.Count) { Write-Host "Deferred machine-scope packages: $($deferred -join ', '). Select them explicitly with -MachinePackages if permitted." }
    if (-not $PSCmdlet.ShouldProcess('Selected Windows packages and user configuration', 'Apply printed plan')) { return }
    if (@($plan | Where-Object Action -eq 'unsupported').Count) { throw 'Unsupported package architecture. Use -SkipPackages with the listed logical names to exclude those tools.' }
    if (@($configs | Where-Object Action -eq 'conflict').Count -and -not $BackupConflicts) { throw 'Configuration conflicts require -BackupConflicts. Nothing was installed or copied.' }
    if (-not $Yes -and (Read-Host 'Apply this Windows setup? [y/N]') -notmatch '^(?i)y(es)?$') { Write-Host 'Setup declined.'; return }
    Invoke-DotfilesPackagePlan $plan -AcceptAgreements:$AcceptAgreements
    foreach ($trial in $trials) { Invoke-DotfilesTrialInstaller $trial }
    # Installers can update persistent PATH; refresh this process without changing it on disk.
    $paths = @([Environment]::GetEnvironmentVariable('Path', 'Machine'), [Environment]::GetEnvironmentVariable('Path', 'User'), $env:Path)
    $env:Path = (@(($paths -join ';') -split ';' | Where-Object { $_ } | Select-Object -Unique) -join ';')
    Invoke-DotfilesConfigPlan -Plan $configs -State $state -StatePath $statePath `
        -BackupRoot (Join-Path $stateRoot 'backups') -BackupConflicts:$BackupConflicts
    if ($IncludeTrials -and 'herdr' -notin $SkipPackages -and (Find-DotfilesApplication 'herdr')) {
        & herdr config check
        if ($LASTEXITCODE -ne 0) { throw 'Herdr config verification failed.' }
    }
    if (-not (Find-DotfilesApplication 'cl') -and -not (Find-DotfilesApplication 'clang') -and -not (Find-DotfilesApplication 'gcc')) {
        Write-Warning 'No C compiler was found. LazyVim Tree-sitter parser compilation still needs an approved compiler.'
    }
    Write-Host 'Complete. Open a new PowerShell session and select Pabu PowerShell in Windows Terminal.'
    if ($deferred.Count) { Write-Host "Still deferred: $($deferred -join ', ')." }
    Write-Host 'Run :checkhealth in Neovim and test Yazi previews. Existing Herdr trials are updated separately upstream.'
} catch {
    Write-Error -Message $_ -ErrorAction Continue
    exit 1
}
