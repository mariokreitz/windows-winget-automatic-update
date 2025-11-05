<#
.SYNOPSIS
  Elevate and run winget update + winget upgrade --all with UTF-8, sanitized console output and UTF-8 logs.

.DESCRIPTION
  - If not running elevated, relaunches itself as Administrator (UAC prompt).
  - Runs: winget update
  - Runs: winget upgrade --all --accept-source-agreements --accept-package-agreements
  - Writes a timestamped log to %USERPROFILE%\Documents\winget-update-<timestamp>.log (UTF-8).
  - Sanitizes progress/art characters for user-friendly console output while preserving raw output in the log.
#>

# Fail fast for non-terminating errors
$ErrorActionPreference = 'Stop'

# Force console and file output to UTF-8 so umlauts render properly
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
    $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
    $PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'
} catch {
    # not fatal
}

function Test-IsAdministrator {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Resolve the script path robustly (used when relaunching elevated)
$scriptPath = $PSCommandPath
if (-not $scriptPath -or $scriptPath -eq '') {
    $scriptPath = $MyInvocation.MyCommand.Definition
}

# Prepare logging
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $env:USERPROFILE 'Documents'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
$logFile = Join-Path $logDir "winget-update-$timestamp.log"

function Write-RawLog {
    param([string]$Text)
    try {
        Add-Content -Path $logFile -Value $Text -Encoding UTF8
    } catch {
        $Text | Out-File -FilePath $logFile -Append -Encoding utf8
    }
}

function Sanitize-Line {
    param([string]$line)
    if ($null -eq $line) { return $null }
    $s = $line.TrimEnd()
    if ($s -eq '') { return $s }

    # Skip spinner-only lines like "-", "/", "\" or "|"
    if ($s -match '^[\s\-\|\\/]+$') { return $null }

    # Convert "NNN KB / N.NN MB" patterns to a readable progress line
    if ($s -match '(\d+(?:[\.,]\d+)?\s*(?:B|KB|MB|GB)\s*/\s*\d+(?:[\.,]\d+)?\s*(?:B|KB|MB|GB))') {
        return "Progress: $($matches[1])"
    }

    # Remove box-drawing / block-character ranges that often corrupt terminals
    $s = $s -replace '[\u2500-\u26FF\u2700-\u27BF]+', ''

    # Collapse repeated whitespace
    $s = $s -replace '\s{2,}', ' '
    return $s.Trim()
}

function Run-Process-AndLog {
    param(
        [string]$exe,
        [string[]]$arguments
    )

    Write-Host "=== Running: $exe $($arguments -join ' ') ===" -ForegroundColor Cyan

    # Build argument string safely: quote individual args that contain spaces.
    if ($null -eq $arguments -or $arguments.Count -eq 0) {
        $argString = ''
    } else {
        $argString = ( $arguments | ForEach-Object {
            if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
        } ) -join ' '
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = $argString
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    # Tell .NET these streams are UTF-8 (may fail on very old runtimes; that's fine)
    try {
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
    } catch {}

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdOut = $proc.StandardOutput
    $stdErr = $proc.StandardError

    while (-not $proc.HasExited -or -not $stdOut.EndOfStream -or -not $stdErr.EndOfStream) {
        while (-not $stdOut.EndOfStream) {
            $line = $stdOut.ReadLine()
            if ($line -ne $null) {
                Write-RawLog $line
                $san = Sanitize-Line $line
                if ($san) { Write-Host $san }
            }
        }
        while (-not $stdErr.EndOfStream) {
            $line = $stdErr.ReadLine()
            if ($line -ne $null) {
                Write-RawLog $line
                $san = Sanitize-Line $line
                if ($san) { Write-Host $san -ForegroundColor Red }
            }
        }
        Start-Sleep -Milliseconds 80
    }

    # Drain remaining buffered output
    while (-not $stdOut.EndOfStream) {
        $line = $stdOut.ReadLine()
        if ($line -ne $null) {
            Write-RawLog $line
            $san = Sanitize-Line $line
            if ($san) { Write-Host $san }
        }
    }
    while (-not $stdErr.EndOfStream) {
        $line = $stdErr.ReadLine()
        if ($line -ne $null) {
            Write-RawLog $line
            $san = Sanitize-Line $line
            if ($san) { Write-Host $san -ForegroundColor Red }
        }
    }

    $exit = $proc.ExitCode
    Write-Host "Exit code: $exit" -ForegroundColor DarkGray
    Write-RawLog ("Exit code: " + $exit)
    return $exit
}

try {
    Write-RawLog ("=== Script start: " + (Get-Date -Format 'u'))
    Write-RawLog ("Logging to: " + $logFile)
    Write-Host "Script start. Logging to: $logFile"

    if (-not (Test-IsAdministrator)) {
        Write-Host "Not running as Administrator. Relaunching elevated (UAC)..." -ForegroundColor Yellow
        $elevArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
        Start-Process -FilePath 'powershell.exe' -ArgumentList $elevArgs -Verb RunAs -WindowStyle Normal -Wait
        Write-RawLog "Elevated instance launched; exiting non-elevated process."
        exit 0
    }

    Write-Host "Running as Administrator." -ForegroundColor Green

    # 1) winget update
    $updateArgs = @('update')
    $rc1 = Run-Process-AndLog -exe 'winget' -arguments $updateArgs
    if ($rc1 -ne 0) {
        Write-Host "Warning: 'winget update' exit code $rc1" -ForegroundColor Yellow
    }

    # 2) winget upgrade --all --accept-source-agreements --accept-package-agreements
    $upgradeArgs = @('upgrade', '--all', '--accept-source-agreements', '--accept-package-agreements')
    $rc2 = Run-Process-AndLog -exe 'winget' -arguments $upgradeArgs
    if ($rc2 -ne 0) {
        Write-Host "Warning: 'winget upgrade --all' exit code $rc2" -ForegroundColor Yellow
    } else {
        Write-Host "winget upgrade completed." -ForegroundColor Green
    }

    Write-RawLog ("Summary: update exit: $rc1 ; upgrade exit: $rc2")
}
catch {
    $err = $_ | Out-String
    Write-RawLog ("UNHANDLED ERROR: " + $err)
    Write-Host "An error occurred. See log: $logFile" -ForegroundColor Red
}
finally {
    Write-RawLog ("Finished at: " + (Get-Date -Format 'u'))
    Write-Host ""
    Write-Host "Log file: $logFile" -ForegroundColor Cyan
    Write-Host "Press Enter to close this window..."
    try { [Console]::ReadLine() | Out-Null } catch {}
}