# Shared by the Windows entry point and the isolated PowerShell tests.
Set-StrictMode -Version Latest

function Invoke-DotfilesWinGet {
    param([string[]]$Arguments)
    $PSNativeCommandUseErrorActionPreference = $false
    $output = & winget.exe @Arguments 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output.Trim() }
}

function Get-DotfilesExitCode {
    param($Result)
    ([long]$Result.ExitCode -band 4294967295L)
}

function Find-DotfilesApplication {
    param([string]$Name)
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    return $null
}

function Read-DotfilesPackages {
    param([string]$Path)
    $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($data.schemaVersion -ne 1) { throw 'Unsupported Windows package schema.' }
    $names = @{}; $ids = @{}
    foreach ($package in $data.packages) {
        if ($package.name -notmatch '^[a-z0-9-]+$' -or $names.ContainsKey($package.name)) { throw 'Invalid or duplicate package name.' }
        if ($package.id -notmatch '^[A-Za-z0-9.-]+$' -or $ids.ContainsKey($package.id)) { throw 'Invalid or duplicate package ID.' }
        if ($package.source -ne 'winget' -or $package.group -notin @('core', 'previews', 'apps', 'trials', 'gaming')) { throw 'Invalid package source/group.' }
        if (@($package.architectures).Count -eq 0 -or @($package.architectures | Where-Object { $_ -notin @('x64', 'arm64') }).Count) { throw 'Invalid architectures.' }
        if (@($package.scopes).Count -eq 0 -or @($package.scopes | Where-Object { $_ -notin @('user', 'machine') }).Count) { throw 'Invalid installer scopes.' }
        $names[$package.name] = $true; $ids[$package.id] = $true
    }
    return @($data.packages)
}

function Get-DotfilesPackagePlan {
    param([object[]]$Packages, [string]$Architecture, [switch]$Upgrade,
          [switch]$Offline, [switch]$AcceptAgreements, [string[]]$MachinePackages = @())
    foreach ($package in $Packages) {
        $available = @($package.commands).Count -gt 0
        foreach ($command in $package.commands) {
            if (-not (Find-DotfilesApplication $command)) { $available = $false }
        }
        $installed = $false
        if (-not $Offline) {
            $arguments = @('list', '--id', $package.id, '--exact', '--source', $package.source, '--disable-interactivity')
            if ($AcceptAgreements) { $arguments += '--accept-source-agreements' }
            $result = Invoke-DotfilesWinGet $arguments
            $code = Get-DotfilesExitCode $result
            if ($code -eq 0) { $installed = $true }
            elseif ($code -ne 2316632084L) { # APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND
                throw "WinGet could not inspect $($package.id) (0x$($code.ToString('X8'))): $($result.Output)"
            }
        }
        $scope = if ($package.name -in $MachinePackages) { 'machine' } else { 'user' }
        $action = 'install'
        if ($installed) { $action = if ($Upgrade) { 'upgrade' } else { 'keep' } }
        elseif ($available) { $action = 'external' }
        elseif ($Offline) { $action = 'inspect/install' }
        if ($action -notin @('keep', 'external') -and $scope -notin $package.scopes) { $action = 'deferred-scope' }
        if ($action -notin @('keep', 'external') -and $Architecture -notin $package.architectures) { $action = 'unsupported' }
        [pscustomobject]@{ Package = $package; Action = $action; Scope = $scope }
    }
}

function Select-DotfilesPackages {
    param([object[]]$Packages, [switch]$IncludePreviews, [switch]$IncludeTrials,
          [string[]]$Apps = @(), [switch]$Gaming, [string[]]$SkipPackages = @(), [string[]]$MachinePackages = @())
    foreach ($name in $SkipPackages) {
        if ($name -ne 'herdr' -and $name -notin $Packages.name) { throw "Unknown package name: $name" }
    }
    foreach ($name in $MachinePackages) {
        if ($name -notin $Packages.name) { throw "Unknown machine package name: $name" }
    }
    @($Packages | Where-Object {
        $_.name -notin $SkipPackages -and ($_.group -eq 'core' -or
        ($_.group -eq 'previews' -and $IncludePreviews) -or ($_.group -eq 'trials' -and $IncludeTrials) -or
        ($_.group -eq 'apps' -and $_.name -in $Apps) -or ($_.group -eq 'gaming' -and $Gaming))
    })
}

function Invoke-DotfilesPackagePlan {
    param([object[]]$Plan, [switch]$AcceptAgreements)
    foreach ($item in $Plan) {
        if ($item.Action -in @('keep', 'external', 'deferred-scope')) { continue }
        if ($item.Action -notin @('install', 'upgrade')) { throw "Cannot apply package action $($item.Action)." }
        $arguments = @($item.Action, '--id', $item.Package.id, '--exact', '--source', $item.Package.source,
                       '--scope', $item.Scope, '--disable-interactivity')
        if ($item.Action -eq 'install') { $arguments += '--no-upgrade' }
        if ($AcceptAgreements) { $arguments += @('--accept-source-agreements', '--accept-package-agreements') }
        Write-Host "  + winget $($arguments -join ' ')"
        $result = Invoke-DotfilesWinGet $arguments
        Write-Host $result.Output
        $code = Get-DotfilesExitCode $result
        if ($item.Action -eq 'upgrade' -and $code -eq 2316632107L) { continue } # UPDATE_NOT_APPLICABLE
        if ($code -ne 0) { throw "WinGet $($item.Action) failed for $($item.Package.id) (0x$($code.ToString('X8'))). Configuration was not applied." }
        $check = Invoke-DotfilesWinGet @('list', '--id', $item.Package.id, '--exact', '--source', $item.Package.source, '--disable-interactivity')
        if ((Get-DotfilesExitCode $check) -ne 0) { throw "Installation verification failed for $($item.Package.id)." }
    }
}

function Assert-DotfilesDestination {
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Refusing redirected destination: $current" }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Get-DotfilesTextHash {
    param([AllowEmptyString()][string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))) }
    finally { $sha.Dispose() }
}

function Read-DotfilesState {
    param([string]$Path)
    Assert-DotfilesDestination $Path
    $state = @{}
    if (Test-Path -LiteralPath $Path) {
        $data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if ($data.schemaVersion -ne 1) { throw 'Unsupported Windows state schema.' }
        foreach ($entry in $data.files) { $state[[string]$entry.path] = [string]$entry.hash }
    }
    return $state
}

function Get-DotfilesFileChange {
    param([string]$Path, [AllowEmptyString()][string]$Content, [hashtable]$State, [switch]$MergeProfile)
    Assert-DotfilesDestination $Path
    $exists = Test-Path -LiteralPath $Path
    if ($exists -and -not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Expected a file: $Path" }
    $old = if ($exists) { [IO.File]::ReadAllText($Path) } else { $null }
    $before = if ($exists) { Get-DotfilesTextHash $old } else { $null }
    $hash = Get-DotfilesTextHash $Content
    $action = if (-not $exists) { 'create' } elseif ($before -eq $hash) { 'keep' }
              elseif ($MergeProfile -or ($State.ContainsKey($Path) -and $State[$Path] -eq $before)) { 'update' } else { 'conflict' }
    [pscustomobject]@{ Path = $Path; Content = $Content; Before = $before; Hash = $hash; Action = $action }
}

function Get-DotfilesProfileContent {
    param([AllowEmptyString()][string]$Existing, [string]$LoaderPath)
    $begin = '# BEGIN pabu-dotfiles windows'; $end = '# END pabu-dotfiles windows'
    $starts = [regex]::Matches($Existing, '(?m)^' + [regex]::Escape($begin) + '\r?$')
    $ends = [regex]::Matches($Existing, '(?m)^' + [regex]::Escape($end) + '\r?$')
    if ($starts.Count -ne $ends.Count -or $starts.Count -gt 1 -or ($starts.Count -and $starts[0].Index -ge $ends[0].Index)) { throw 'Malformed managed PowerShell profile markers.' }
    $newline = if ($Existing.Contains("`r`n")) { "`r`n" } else { "`n" }
    $quoted = $LoaderPath.Replace("'", "''")
    $block = "$begin$newline. '$quoted'$newline$end"
    if ($starts.Count) {
        $pattern = '(?ms)^' + [regex]::Escape($begin) + '\r?\n.*?^' + [regex]::Escape($end) + '(?=\r?$)'
        return [regex]::Replace($Existing, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $block })
    }
    $separator = if ($Existing.Length -eq 0 -or $Existing.EndsWith("`n")) { '' } else { $newline }
    return $Existing + $separator + $block + $newline
}

function Get-DotfilesWindowsStarship {
    param([string]$Source)
    $commands = @{
        date = 'command = "Get-Date -Format ''ddd dd MMM''"'
        git_cap = 'command = "''''"'
        nogit_cap = 'command = "''''"'
        git_to_date_sep = 'command = "''''"'
    }
    $yes = 'when = "(git rev-parse --is-inside-work-tree 2>$null) -eq ''true''"'
    $no = 'when = "-not ((git rev-parse --is-inside-work-tree 2>$null) -eq ''true'')"'
    $pattern = '(?ms)^\[custom\.(date|git_cap|nogit_cap|git_to_date_sep)\]\r?\n(.*?)(?=^\[|\z)'
    if ([regex]::Matches($Source, $pattern).Count -ne 4) { throw 'Shared Starship custom modules changed; review the Windows adaptation.' }
    return [regex]::Replace($Source, $pattern, [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $name = $match.Groups[1].Value
        $body = [regex]::Replace($match.Groups[2].Value, '(?m)^command = .*$', [Text.RegularExpressions.MatchEvaluator]{ param($line) $commands[$name] })
        if ($name -ne 'date') {
            $when = if ($name -eq 'nogit_cap') { $no } else { $yes }
            $body = [regex]::Replace($body, '(?m)^when = .*$', [Text.RegularExpressions.MatchEvaluator]{ param($line) $when })
        }
        "[custom.$name]`n" + 'shell = ["pwsh", "-NoLogo", "-NoProfile", "-Command"]' + "`n$body"
    })
}

function Get-DotfilesConfigPlan {
    param([string]$Repo, [string]$LocalAppData, [string]$AppData, [string]$ProfilePath,
          [hashtable]$State, [switch]$IncludeTrials)
    $root = Join-Path $LocalAppData 'pabu-dotfiles/windows'
    $mappings = @(
        @{ Source = 'nvim/.config/nvim'; Target = (Join-Path $LocalAppData 'nvim') },
        @{ Source = 'yazi/.config/yazi'; Target = (Join-Path $AppData 'yazi/config') }
    )
    foreach ($mapping in $mappings) {
        $source = Join-Path $Repo $mapping.Source
        foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse -Force) {
            if ($file.Name -match '^(README|LICENSE|COPYING|\.git)' -or $file.FullName -match '[/\\]\.git[/\\]') { continue }
            $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
            Get-DotfilesFileChange (Join-Path $mapping.Target $relative) ([IO.File]::ReadAllText($file.FullName)) $State
        }
    }
    $starship = Get-DotfilesWindowsStarship ([IO.File]::ReadAllText((Join-Path $Repo 'starship/.config/starship.toml')))
    Get-DotfilesFileChange (Join-Path $root 'starship.toml') $starship $State
    Get-DotfilesFileChange (Join-Path $root 'profile.ps1') ([IO.File]::ReadAllText((Join-Path $Repo 'windows/profile.ps1'))) $State
    $existing = if (Test-Path -LiteralPath $ProfilePath -PathType Leaf) { [IO.File]::ReadAllText($ProfilePath) } else { '' }
    $profile = Get-DotfilesProfileContent $existing (Join-Path $root 'profile.ps1')
    Get-DotfilesFileChange $ProfilePath $profile $State -MergeProfile
    $fragment = Join-Path $LocalAppData 'Microsoft/Windows Terminal/Fragments/pabu-dotfiles/profiles.json'
    Get-DotfilesFileChange $fragment ([IO.File]::ReadAllText((Join-Path $Repo 'windows/terminal-fragment.json'))) $State
    if ($IncludeTrials) {
        Get-DotfilesFileChange (Join-Path $AppData 'herdr/config.toml') ([IO.File]::ReadAllText((Join-Path $Repo 'herdr/.config/herdr/config.toml'))) $State
    }
}

function Write-DotfilesAtomicText {
    param([string]$Path, [AllowEmptyString()][string]$Content)
    Assert-DotfilesDestination $Path
    $parent = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $temporary = Join-Path $parent ('.dotfiles-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText($temporary, $Content, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $Path, $true)
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}

function Invoke-DotfilesConfigPlan {
    param([object[]]$Plan, [hashtable]$State, [string]$StatePath, [string]$BackupRoot, [switch]$BackupConflicts)
    if (@($Plan | Where-Object { $_.Action -eq 'conflict' }).Count -and -not $BackupConflicts) { throw 'Configuration conflicts require -BackupConflicts.' }
    # Recheck all destinations before the first write, including unchanged files.
    foreach ($item in $Plan) {
        Assert-DotfilesDestination $item.Path
        $current = if (Test-Path -LiteralPath $item.Path) { Get-DotfilesTextHash ([IO.File]::ReadAllText($item.Path)) } else { $null }
        if ($current -ne $item.Before) { throw "Configuration changed since planning: $($item.Path)" }
    }
    $backup = Join-Path $BackupRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
    $records = [Collections.Generic.List[object]]::new()
    foreach ($item in $Plan) {
        if ($item.Action -eq 'keep') { continue }
        if ($null -ne $item.Before) {
            Assert-DotfilesDestination $backup
            [IO.Directory]::CreateDirectory($backup) | Out-Null
            $saved = Join-Path $backup ((Get-DotfilesTextHash $item.Path) + '.backup')
            Copy-Item -LiteralPath $item.Path -Destination $saved
            $records.Add([pscustomobject]@{ original = $item.Path; backup = $saved })
            Write-DotfilesAtomicText (Join-Path $backup 'manifest.json') (ConvertTo-Json -InputObject @($records.ToArray()) -Depth 4)
        }
        Write-DotfilesAtomicText $item.Path $item.Content
        $State[$item.Path] = $item.Hash
        # Save after each write so a later failure can be retried safely.
        $files = @($State.Keys | Sort-Object | ForEach-Object { @{ path = $_; hash = $State[$_] } })
        Write-DotfilesAtomicText $StatePath (ConvertTo-Json @{ schemaVersion = 1; files = $files } -Depth 5)
    }
    if ($records.Count) { Write-Host "Backups: $backup" }
}

function Invoke-DotfilesTrialInstaller {
    param($Trial)
    if ($Trial.url -notmatch '^https://raw\.githubusercontent\.com/herdrdev/herdr/[a-f0-9]{40}/distribution/install\.ps1$' -or
        $Trial.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Invalid pinned trial installer.' }
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('pabu-dotfiles-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($temporary) | Out-Null
    $installer = Join-Path $temporary 'install.ps1'
    try {
        Invoke-WebRequest -Uri $Trial.url -OutFile $installer
        if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $Trial.sha256) { throw 'Herdr installer checksum mismatch.' }
        $PSNativeCommandUseErrorActionPreference = $false
        & (Join-Path $PSHOME 'pwsh.exe') -NoLogo -NoProfile -File $installer @($Trial.arguments)
        if ($LASTEXITCODE -ne 0) { throw "Herdr installer failed ($LASTEXITCODE)." }
    } finally { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
