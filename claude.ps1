param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$ErrorActionPreference = 'Stop'

function Resolve-Config {
    $root = $PSScriptRoot

    $latestCandidates = @(
        $env:CLAUDE_SWITCHER_LATEST,
        "$env:USERPROFILE\.local\bin\claude.exe",
        "$env:LOCALAPPDATA\Claude Code\claude.exe"
    ) | Where-Object { $_ }

    $latest = $null
    foreach ($candidate in $latestCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            $latest = $candidate
            break
        }
    }

    $old      = $null
    $oldLabel = 'pinned'

    # 1. Explicit env-var override
    if ($env:CLAUDE_SWITCHER_OLD -and (Test-Path -LiteralPath $env:CLAUDE_SWITCHER_OLD)) {
        $old      = $env:CLAUDE_SWITCHER_OLD
        $oldLabel = [System.IO.Path]::GetFileNameWithoutExtension($old) -replace '^claude-', ''
    }

    # 2. Any claude-v*.exe in versions/ (alphabetically first)
    if (-not $old) {
        $versionsDir = Join-Path $root 'versions'
        $found = Get-ChildItem $versionsDir -Filter 'claude-v*.exe' -ErrorAction SilentlyContinue |
            Sort-Object Name | Select-Object -First 1
        if ($found) {
            $old      = $found.FullName
            $oldLabel = [System.IO.Path]::GetFileNameWithoutExtension($found.Name) -replace '^claude-', ''
        }
    }

    # 3. Generic claude-old.exe
    if (-not $old) {
        $genericPath = Join-Path $root 'versions\claude-old.exe'
        if (Test-Path -LiteralPath $genericPath) {
            $old      = $genericPath
            $oldLabel = 'pinned'
        }
    }

    # 4. Legacy npm install fallback
    if (-not $old) {
        $npmPath = "$env:APPDATA\npm\claude.cmd"
        if (Test-Path -LiteralPath $npmPath) {
            $old      = $npmPath
            $oldLabel = 'npm'
        }
    }

    return [ordered]@{
        Root     = $root
        Latest   = $latest
        Old      = $old
        OldLabel = $oldLabel
    }
}

function Invoke-Claude {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Exe,
        [string[]]$Arguments = @()
    )

    if (-not (Test-Path -LiteralPath $Exe)) {
        throw "Claude executable not found: $Exe"
    }

    & $Exe @Arguments
    exit $LASTEXITCODE
}

function Show-Doctor {
    param($cfg)

    Write-Host ""
    Write-Host "Claude version picker diagnostics" -ForegroundColor Cyan
    Write-Host "Wrapper root:    $($cfg.Root)"
    Write-Host "Old binary:      $($cfg.Old)"
    Write-Host "Latest binary:   $($cfg.Latest)"
    Write-Host ""
    Write-Host 'where.exe claude:' -ForegroundColor Yellow
    try { & where.exe claude } catch { Write-Host 'Unable to run where.exe claude' }
    if ($cfg.Old) {
        Write-Host ""
        Write-Host "Old version ($($cfg.OldLabel)):" -ForegroundColor Yellow
        try { & $cfg.Old --version } catch { Write-Host $_.Exception.Message }
    }
    if ($cfg.Latest) {
        Write-Host ""
        Write-Host 'Latest version:' -ForegroundColor Yellow
        try { & $cfg.Latest --version } catch { Write-Host $_.Exception.Message }
    }
}

function Show-Help {
    param($cfg)
@"
Usage:
  claude              Ask which Claude Code version to launch
  claude old          Launch pinned binary
  claude latest       Launch current installed/latest binary
  claude doctor       Show diagnostics
  claude help         Show this help

Expected files:
  Pinned binary:      $($cfg.Old)
  Latest binary:      $($cfg.Latest)

Environment overrides:
  CLAUDE_SWITCHER_OLD=C:\path\to\pinned\claude.exe
  CLAUDE_SWITCHER_LATEST=C:\path\to\latest\claude.exe
"@ | Write-Host
}

function Show-Menu {
    param($cfg)

    $label = $cfg.OldLabel.PadRight(10)

    Write-Host ""
    Write-Host "Choose Claude Code version:" -ForegroundColor Cyan
    Write-Host "  1) $label Pinned daily-work version"
    Write-Host "  2) latest     Current installed version"
    Write-Host "  d) doctor     Diagnostics"
    Write-Host "  h) help       Help"
    Write-Host "  q) quit"
    $choice = Read-Host 'Choose'
    switch ($choice.Trim().ToLowerInvariant()) {
        '1'      { return @('old') }
        'old'    { return @('old') }
        '2'      { return @('latest') }
        'latest' { return @('latest') }
        'd'      { return @('doctor') }
        'doctor' { return @('doctor') }
        'h'      { return @('help') }
        'help'   { return @('help') }
        'q'      { exit 0 }
        'quit'   { exit 0 }
        default  {
            Write-Host 'Unrecognized choice.' -ForegroundColor Red
            exit 1
        }
    }
}

$cfg = Resolve-Config

if (-not $CliArgs -or $CliArgs.Count -eq 0) {
    $CliArgs = Show-Menu -cfg $cfg
}

$verb = $CliArgs[0].ToLowerInvariant()
$rest = if ($CliArgs.Count -gt 1) { $CliArgs[1..($CliArgs.Count - 1)] } else { @() }

switch ($verb) {
    'old' {
        if (-not $cfg.Old) {
            throw 'Pinned binary not found. Place it at versions\claude-old.exe or versions\claude-v<version>.exe, or set CLAUDE_SWITCHER_OLD.'
        }
        Invoke-Claude -Exe $cfg.Old -Arguments $rest
    }
    'latest' {
        if (-not $cfg.Latest) {
            throw 'Latest Claude binary not found. Install Claude Code or set CLAUDE_SWITCHER_LATEST.'
        }
        Invoke-Claude -Exe $cfg.Latest -Arguments $rest
    }
    'doctor' {
        Show-Doctor -cfg $cfg
        exit 0
    }
    'help' {
        Show-Help -cfg $cfg
        exit 0
    }
    default {
        if (-not $cfg.Latest) {
            throw 'Latest Claude binary not found. Install Claude Code or set CLAUDE_SWITCHER_LATEST.'
        }
        Invoke-Claude -Exe $cfg.Latest -Arguments $CliArgs
    }
}
