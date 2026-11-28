# Loaded from a small managed block in the user's PowerShell 7 profile.
$env:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml'

function global:ll { & eza --icons --group-directories-first -lA @args }

function global:y {
    $temporary = [IO.Path]::GetTempFileName()
    $status = 1
    try {
        & yazi @args "--cwd-file=$temporary"
        $status = $LASTEXITCODE
        $cwd = [IO.File]::ReadAllText($temporary).TrimEnd([char[]]"`r`n")
        if ($cwd -and (Test-Path -LiteralPath $cwd -PathType Container)) { Set-Location -LiteralPath $cwd }
    } finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = $status
    }
}

# Add only known tool directories, never Git's complete Unix bin directory.
$toolPaths = @(
    (Join-Path $env:ProgramFiles '7-Zip'),
    (Join-Path $env:LOCALAPPDATA 'Programs/7-Zip')
)
if (Test-Path -LiteralPath $env:ProgramFiles) {
    $toolPaths += @(Get-ChildItem -LiteralPath $env:ProgramFiles -Directory -Filter 'ImageMagick-*' -ErrorAction SilentlyContinue | ForEach-Object FullName)
}
foreach ($directory in $toolPaths) {
    if ((Test-Path -LiteralPath $directory -PathType Container) -and $directory -notin ($env:PATH -split [IO.Path]::PathSeparator)) {
        $env:PATH = $directory + [IO.Path]::PathSeparator + $env:PATH
    }
}

if (-not $env:YAZI_FILE_ONE -or -not (Test-Path -LiteralPath $env:YAZI_FILE_ONE -PathType Leaf)) {
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $roots = @()
    if ($git) {
        $roots += Split-Path -Parent $git.Source
        $execPath = & $git.Source --exec-path 2>$null
        if ($LASTEXITCODE -eq 0 -and $execPath) { $roots += $execPath }
    }
    foreach ($start in $roots) {
        $directory = $start
        for ($level = 0; $level -lt 6 -and $directory; $level++) {
            $candidate = Join-Path $directory 'usr/bin/file.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $env:YAZI_FILE_ONE = $candidate; break }
            $directory = Split-Path -Parent $directory
        }
        if ($env:YAZI_FILE_ONE -and (Test-Path -LiteralPath $env:YAZI_FILE_ONE -PathType Leaf)) { break }
    }
}

if (Get-Command zoxide -CommandType Application -ErrorAction SilentlyContinue) { Invoke-Expression (& zoxide init powershell | Out-String) }
if (Get-Command starship -CommandType Application -ErrorAction SilentlyContinue) { Invoke-Expression (& starship init powershell | Out-String) }
Remove-Variable toolPaths, directory, git, roots, execPath, start, candidate, level -ErrorAction SilentlyContinue
