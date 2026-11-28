#Requires -Version 7.2
# No Pester/module downloads required. Run with pwsh -NoProfile -File this-file.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows/bootstrap-functions.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$temporaryBase = if ($IsMacOS) { '/private/tmp' } else { [IO.Path]::GetTempPath() }
$testRoot = Join-Path $temporaryBase ('dotfiles-windows-test-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$script:passed = 0
function Assert-True { param($Value, [string]$Message = 'Assertion failed'); if (-not $Value) { throw $Message } }
function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action } catch { if ($_.ToString() -notmatch $Pattern) { throw }; return }
    throw "Expected error matching $Pattern"
}
function Test-Case {
    param([string]$Name, [scriptblock]$Action)
    $script:commands = [Collections.Generic.List[object]]::new()
    $script:installed = @{}; $script:available = @{}; $script:queryFailure = 0; $script:installFailure = 0
    $script:upgradeCode = 0
    try { & $Action; $script:passed++; Write-Host "PASS $Name" }
    catch { throw "FAIL $Name`: $_`n$($_.ScriptStackTrace)" }
}
function Find-DotfilesApplication { param([string]$Name); if ($script:available.ContainsKey($Name)) { return $script:available[$Name] }; return $null }
function Invoke-DotfilesWinGet {
    param([string[]]$Arguments)
    $script:commands.Add(@($Arguments))
    $id = $Arguments[[array]::IndexOf($Arguments, '--id') + 1]
    $code = 0
    switch ($Arguments[0]) {
        list { $code = if ($script:queryFailure) { $script:queryFailure } elseif ($script:installed.ContainsKey($id)) { 0 } else { -1978335212 } }
        install { $code = $script:installFailure; if (-not $code) { $script:installed[$id] = $true } }
        upgrade { $code = $script:upgradeCode }
        default { throw 'Unexpected WinGet mutation.' }
    }
    [pscustomobject]@{ ExitCode = $code; Output = 'stubbed manager result' }
}
$packages = @(Read-DotfilesPackages (Join-Path $PSScriptRoot 'windows/packages.json'))
$gitPackage = @($packages | Where-Object name -eq 'git')

try {
    Test-Case 'PowerShell files parse' {
        $files = @((Join-Path $PSScriptRoot 'bootstrap-windows.ps1'), (Join-Path $PSScriptRoot 'windows/bootstrap-functions.ps1'), (Join-Path $repo 'windows/profile.ps1'))
        foreach ($file in $files) {
            $tokens = $null; $parseErrors = $null
            $null = [Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors)
            Assert-True ($parseErrors.Count -eq 0) "$file has parse errors."
        }
    }
    Test-Case 'Core selection excludes optional apps, previews, trials, gaming' {
        $selected = @(Select-DotfilesPackages $packages)
        Assert-True ($selected.Count -eq @($packages | Where-Object group -eq 'core').Count)
        Assert-True ('resvg' -notin $selected.name -and 'handy' -notin $selected.name -and 'wezterm' -notin $selected.name)
    }
    Test-Case 'Independent optional groups and exclusions' {
        $selected = @(Select-DotfilesPackages $packages -IncludePreviews -IncludeTrials -Apps keeper -Gaming -SkipPackages font,wezterm)
        foreach ($name in @('resvg','keeper','steam')) { Assert-True ($name -in $selected.name) }
        foreach ($name in @('font','wezterm','handy','zen')) { Assert-True ($name -notin $selected.name) }
        Assert-Throws { Select-DotfilesPackages $packages -SkipPackages typo } 'Unknown package'
    }
    Test-Case 'Offline preview never invokes WinGet or accepts agreements' {
        $plan = @(Get-DotfilesPackagePlan $packages -Architecture x64 -Offline -AcceptAgreements)
        Assert-True ($script:commands.Count -eq 0)
        Assert-True ($plan.Count -eq $packages.Count)
    }
    Test-Case 'Missing and installed are detected by exit code' {
        $plan = @(Get-DotfilesPackagePlan $gitPackage -Architecture x64)
        Assert-True ($plan[0].Action -eq 'install')
        $script:installed['Git.Git'] = $true
        $plan = @(Get-DotfilesPackagePlan $gitPackage -Architecture x64)
        Assert-True ($plan[0].Action -eq 'keep')
    }
    Test-Case 'Policy and source failures are not treated as missing packages' {
        $script:queryFailure = -1978335174 # BLOCKED_BY_POLICY
        Assert-Throws { Get-DotfilesPackagePlan $gitPackage -Architecture x64 } 'could not inspect'
        Assert-True (@($script:commands | Where-Object { $_[0] -eq 'install' }).Count -eq 0)
    }
    Test-Case 'Unmanaged executables retained, even with explicit upgrade' {
        $script:available['git'] = 'C:\custom\git.exe'
        $plan = @(Get-DotfilesPackagePlan $gitPackage -Architecture x64 -Upgrade)
        Assert-True ($plan[0].Action -eq 'external')
        Invoke-DotfilesPackagePlan $plan
        Assert-True ($script:commands.Count -eq 1)
    }
    Test-Case 'Install uses exact ID, source, no-upgrade, and user scope' {
        $plan = @(Get-DotfilesPackagePlan $gitPackage -Architecture x64)
        Invoke-DotfilesPackagePlan $plan
        $install = @($script:commands | Where-Object { $_[0] -eq 'install' })[0]
        foreach ($value in @('--id','Git.Git','--exact','--source','winget','--no-upgrade','--scope','user')) { Assert-True ($value -in $install) }
        Assert-True ('--accept-package-agreements' -notin $install)
        $again = @(Get-DotfilesPackagePlan $gitPackage -Architecture x64)
        Assert-True ($again[0].Action -eq 'keep')
    }
    Test-Case 'Explicit machine scope and agreements' {
        $plan = @(Get-DotfilesPackagePlan $gitPackage -Architecture x64 -MachinePackages git -AcceptAgreements)
        Invoke-DotfilesPackagePlan $plan -AcceptAgreements
        $install = @($script:commands | Where-Object { $_[0] -eq 'install' })[0]
        Assert-True ('machine' -in $install -and '--accept-package-agreements' -in $install)
    }
    Test-Case 'Upgrades are scoped and no-update status is successful' {
        $script:installed['Git.Git'] = $true; $script:upgradeCode = -1978335189
        $plan = @(Get-DotfilesPackagePlan $gitPackage -Architecture x64 -Upgrade)
        Invoke-DotfilesPackagePlan $plan
        Assert-True (@($script:commands | Where-Object { $_[0] -eq 'upgrade' }).Count -eq 1)
        foreach ($command in $script:commands) { Assert-True ('--all' -notin $command) }
    }
    Test-Case 'Install failure stops before the next package' {
        $plan = @(Get-DotfilesPackagePlan @($packages[1], $packages[2]) -Architecture x64)
        $script:installFailure = 5
        Assert-Throws { Invoke-DotfilesPackagePlan $plan } 'failed'
        Assert-True (@($script:commands | Where-Object { $_[0] -eq 'install' }).Count -eq 1)
    }
    Test-Case 'Known machine-only packages are deferred without elevation consent' {
        $node = @($packages | Where-Object name -eq 'node')
        $plan = @(Get-DotfilesPackagePlan $node -Architecture x64)
        Assert-True ($plan[0].Action -eq 'deferred-scope')
        Invoke-DotfilesPackagePlan $plan
        Assert-True ($script:commands.Count -eq 1)
        $plan = @(Get-DotfilesPackagePlan $node -Architecture x64 -MachinePackages node)
        Assert-True ($plan[0].Action -eq 'install' -and $plan[0].Scope -eq 'machine')
    }
    Test-Case 'Existing machine-only runtimes remain usable without machine opt-in' {
        $node = @($packages | Where-Object name -eq 'node')
        $script:installed['OpenJS.NodeJS.LTS'] = $true
        $plan = @(Get-DotfilesPackagePlan $node -Architecture x64)
        Assert-True ($plan[0].Action -eq 'keep')
    }
    Test-Case 'Architecture unsupported is explicit without losing existing tools' {
        $eza = @($packages | Where-Object name -eq 'eza')
        $plan = @(Get-DotfilesPackagePlan $eza -Architecture arm64)
        Assert-True ($plan[0].Action -eq 'unsupported')
        $script:installed['eza-community.eza'] = $true
        $plan = @(Get-DotfilesPackagePlan $eza -Architecture arm64)
        Assert-True ($plan[0].Action -eq 'keep')
    }
    Test-Case 'Profile preserves personal content, CRLF, and quoted paths' {
        $original = "# mine`r`nfunction personal { 'retained' }`r`n"
        $content = Get-DotfilesProfileContent $original "C:\Users\O'Brien\profile.ps1"
        Assert-True ($content.StartsWith($original))
        Assert-True ($content.Contains("O''Brien"))
        Assert-True ((Get-DotfilesProfileContent $content "C:\Users\O'Brien\profile.ps1") -ceq $content)
        Assert-Throws { Get-DotfilesProfileContent '# BEGIN pabu-dotfiles windows' 'x' } 'Malformed'
    }
    Test-Case 'Configuration plan is read-only and trial configuration is conditional' {
        $local = Join-Path $testRoot 'local with spaces ä'; $roaming = Join-Path $testRoot 'roaming'
        $profile = Join-Path $testRoot 'redirected Documents/Profile.ps1'
        $plan = @(Get-DotfilesConfigPlan $repo $local $roaming $profile @{})
        Assert-True (-not (Test-Path -LiteralPath $local))
        Assert-True (@($plan | Where-Object { $_.Path -like '*herdr*' }).Count -eq 0)
        $trials = @(Get-DotfilesConfigPlan $repo $local $roaming $profile @{} -IncludeTrials)
        Assert-True (@($trials | Where-Object { $_.Path -like '*herdr*' }).Count -eq 1)
    }
    Test-Case 'Conflicts block all copies until backups are authorized' {
        $base = Join-Path $testRoot 'conflicts'; [IO.Directory]::CreateDirectory($base) | Out-Null
        $old = Join-Path $base 'old.toml'; [IO.File]::WriteAllText($old, 'personal')
        $new = Join-Path $base 'new.toml'; $statePath = Join-Path $base 'state.json'
        $plan = @((Get-DotfilesFileChange $new 'new' @{}), (Get-DotfilesFileChange $old 'managed' @{}))
        Assert-Throws { Invoke-DotfilesConfigPlan $plan @{} $statePath (Join-Path $base 'backups') } 'BackupConflicts'
        Assert-True (-not (Test-Path -LiteralPath $new))
        Invoke-DotfilesConfigPlan $plan @{} $statePath (Join-Path $base 'backups') -BackupConflicts
        $manifest = Get-ChildItem (Join-Path $base 'backups') -Filter manifest.json -Recurse | Get-Content -Raw | ConvertFrom-Json
        Assert-True ([IO.File]::ReadAllText($manifest[0].backup) -ceq 'personal')
        Assert-True ([IO.File]::ReadAllText($old) -ceq 'managed')
    }
    Test-Case 'Managed updates back up and local edits require approval' {
        $base = Join-Path $testRoot 'updates'; $file = Join-Path $base 'config.toml'; $statePath = Join-Path $base 'state.json'
        Invoke-DotfilesConfigPlan @((Get-DotfilesFileChange $file 'v1' @{})) @{} $statePath (Join-Path $base 'backups')
        $state = Read-DotfilesState $statePath
        $change = Get-DotfilesFileChange $file 'v2' $state
        Assert-True ($change.Action -eq 'update')
        Invoke-DotfilesConfigPlan @($change) $state $statePath (Join-Path $base 'backups')
        [IO.File]::WriteAllText($file, 'local edit')
        Assert-True ((Get-DotfilesFileChange $file 'v3' (Read-DotfilesState $statePath)).Action -eq 'conflict')
    }
    Test-Case 'Full configuration apply is idempotent and keeps runtime files' {
        $local = Join-Path $testRoot 'full/local'; $roaming = Join-Path $testRoot 'full/roaming'; $profile = Join-Path $testRoot 'full/Documents/Profile.ps1'
        $statePath = Join-Path $local 'pabu-dotfiles/windows/state.json'; $backups = Join-Path $local 'pabu-dotfiles/windows/backups'
        $plan = @(Get-DotfilesConfigPlan $repo $local $roaming $profile @{})
        Invoke-DotfilesConfigPlan $plan @{} $statePath $backups
        $runtime = Join-Path $roaming 'yazi/config/session.log'; [IO.File]::WriteAllText($runtime, 'keep runtime')
        $state = Read-DotfilesState $statePath
        $again = @(Get-DotfilesConfigPlan $repo $local $roaming $profile $state)
        Assert-True (@($again | Where-Object Action -ne 'keep').Count -eq 0)
        $stateBefore = [IO.File]::ReadAllText($statePath)
        Invoke-DotfilesConfigPlan $again $state $statePath $backups
        Assert-True ([IO.File]::ReadAllText($statePath) -ceq $stateBefore)
        Assert-True ([IO.File]::ReadAllText($runtime) -ceq 'keep runtime')
    }
    Test-Case 'Concurrent file edits abort before the first copy' {
        $base = Join-Path $testRoot 'race'; [IO.Directory]::CreateDirectory($base) | Out-Null
        $first = Join-Path $base 'first'; $last = Join-Path $base 'last'
        $plan = @((Get-DotfilesFileChange $first 'a' @{}), (Get-DotfilesFileChange $last 'b' @{}))
        [IO.File]::WriteAllText($last, 'raced')
        Assert-Throws { Invoke-DotfilesConfigPlan $plan @{} (Join-Path $base 'state.json') (Join-Path $base 'backups') } 'changed since planning'
        Assert-True (-not (Test-Path -LiteralPath $first))
    }
    Test-Case 'Redirected target ancestors are rejected without changing owner' {
        $owner = Join-Path $testRoot 'owner'; [IO.Directory]::CreateDirectory($owner) | Out-Null
        $link = Join-Path $testRoot 'redirected'
        $type = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $type -Path $link -Target $owner | Out-Null
        Assert-Throws { Get-DotfilesFileChange (Join-Path $link 'file') 'no' @{} } 'redirected'
        Assert-True (@(Get-ChildItem $owner).Count -eq 0)
        Remove-Item -LiteralPath $link -Force
    }
    Test-Case 'Starship adaptation uses PowerShell without Unix commands' {
        $content = Get-DotfilesWindowsStarship ([IO.File]::ReadAllText((Join-Path $repo 'starship/.config/starship.toml')))
        Assert-True (-not $content.Contains('/dev/null') -and -not $content.Contains('printf'))
        Assert-True ($content.Contains('Get-Date') -and $content.Contains('shell = ["pwsh"'))
        Write-DotfilesAtomicText (Join-Path $testRoot 'starship.toml') $content
    }
    Test-Case 'An invalid trial checksum stops before executing downloaded code' {
        function Invoke-WebRequest { param($Uri, $OutFile); [IO.File]::WriteAllText($OutFile, 'not the reviewed installer') }
        $trial = (Get-Content (Join-Path $PSScriptRoot 'windows/trials.json') -Raw | ConvertFrom-Json).scripts[0]
        Assert-Throws { Invoke-DotfilesTrialInstaller $trial } 'checksum mismatch'
    }
    Test-Case 'Yazi wrapper changes to Unicode paths and preserves the child exit code' {
        $originalLocation = Get-Location
        $env:ProgramFiles = Join-Path $testRoot 'programs'
        $env:LOCALAPPDATA = Join-Path $testRoot 'profile-local'
        $script:yaziDestination = Join-Path $testRoot 'directory with spaces ä'
        [IO.Directory]::CreateDirectory($script:yaziDestination) | Out-Null
        function Get-Command {
            param($Name, $CommandType, $ErrorAction)
            # Prevent profile initialization from running the host's real tools.
            return $null
        }
        function global:yazi {
            $fileArgument = @($args | Where-Object { $_ -like '--cwd-file=*' })[0]
            $script:yaziTemporary = $fileArgument.Substring('--cwd-file='.Length)
            [IO.File]::WriteAllText($script:yaziTemporary, $script:yaziDestination + "`n")
            $global:LASTEXITCODE = 7
        }
        try {
            . (Join-Path $repo 'windows/profile.ps1')
            y
            Assert-True ((Get-Location).Path -ceq $script:yaziDestination)
            Assert-True ($LASTEXITCODE -eq 7)
            Assert-True (-not (Test-Path -LiteralPath $script:yaziTemporary))
        } finally {
            Set-Location $originalLocation
            Remove-Item Function:yazi, Function:y, Function:ll -ErrorAction SilentlyContinue
        }
    }
    Test-Case 'Git file detection uses the real install root and preserves a valid override' {
        $base = Join-Path $testRoot 'Portable Git ä'
        [IO.Directory]::CreateDirectory((Join-Path $base 'cmd')) | Out-Null
        [IO.Directory]::CreateDirectory((Join-Path $base 'usr/bin')) | Out-Null
        $expected = Join-Path $base 'usr/bin/file.exe'
        [IO.File]::WriteAllText($expected, '')
        $script:fakeGit = Join-Path $base 'cmd/git.ps1'
        $execPath = (Join-Path $base 'mingw64/libexec/git-core').Replace("'", "''")
        [IO.File]::WriteAllText($script:fakeGit, "'$execPath'`n")
        function Get-Command {
            param($Name, $CommandType, $ErrorAction)
            if ($Name -eq 'git') { return [pscustomobject]@{ Source = $script:fakeGit } }
            return $null
        }
        $env:ProgramFiles = Join-Path $testRoot 'programs'
        $env:LOCALAPPDATA = Join-Path $testRoot 'profile-local'
        $env:YAZI_FILE_ONE = ''
        . (Join-Path $repo 'windows/profile.ps1')
        Assert-True ($env:YAZI_FILE_ONE -ceq $expected)
        Assert-True ((Join-Path $base 'usr/bin') -notin ($env:PATH -split [IO.Path]::PathSeparator))
        $override = Join-Path $testRoot 'custom-file.exe'; [IO.File]::WriteAllText($override, '')
        $env:YAZI_FILE_ONE = $override
        . (Join-Path $repo 'windows/profile.ps1')
        Assert-True ($env:YAZI_FILE_ONE -ceq $override)
        Remove-Item Function:y, Function:ll -ErrorAction SilentlyContinue
    }
    Write-Host "$script:passed Windows bootstrap tests passed. Package managers were stubbed."
} finally { Remove-Item -LiteralPath $testRoot -Recurse -Force }
