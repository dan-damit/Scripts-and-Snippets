# Robust self-elevate + diagnostic wrapper
$log = Join-Path $env:TEMP "Launch-MatrixShell.log"

# Easy logger
function _Log {
    param($msg)
    "$((Get-Date).ToString('o')) `t $msg" | Out-File -FilePath $log -Append -Encoding utf8
}

# Ensure we have a reliable script path
$scriptPath = $PSCommandPath
if (-not $scriptPath) {
    $scriptPath = $MyInvocation.MyCommand.Path
}
if (-not $scriptPath) {
    _Log "ERROR: Could not determine script path. Aborting."
    Write-Host "Could not determine script path. See $log" -ForegroundColor Red
    Pause
    exit 1
}

# Only relaunch if not already elevated
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
} catch {
    _Log "ERROR: elevation check failed: $_"
    $isAdmin = $false
}

if (-not $isAdmin) {
    _Log "Launching elevated copy: $scriptPath"
    $arg = "-NoExit -ExecutionPolicy Bypass -File `"$scriptPath`""
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $arg -Verb RunAs -WindowStyle Normal
        _Log "Start-Process returned; exiting original process."
    } catch {
        _Log "ERROR: Start-Process failed: $_"
        Write-Host "Elevation failed. See $log" -ForegroundColor Red
        Pause
    }
    exit
}

# From here onward we are elevated — start a transcript to capture any errors
try {
    Start-Transcript -Path $log -Append -Force
    _Log "Running elevated. Transcript started."
} catch {
    _Log "WARNING: Start-Transcript failed: $_"
}
# Turn errors into exceptions to make them visible and logged
$ErrorActionPreference = 'Stop'
trap {
    _Log "UNHANDLED ERROR: $_"
    Stop-Transcript -ErrorAction SilentlyContinue
    Write-Host "`nAn error occurred. Details written to $log" -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}