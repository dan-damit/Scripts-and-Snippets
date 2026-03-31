<#
.SYNOPSIS
    Unblock recently edited PDF files in a directory tree.
.DESCRIPTION
    This script searches for PDF files under a specified root path that have
    been modified within a certain time frame (default 30 minutes). For each
    such file, it checks if the file is currently locked/in use (e.g. still
    being copied). If the file is not locked and has a Zone.Identifier alternate
    data stream (indicating it was downloaded from the internet), the script
    attempts to unblock the file by removing the MOTW/Zone.Identifier stream.
    The script logs its actions and any errors to a specified log file.
.PARAMETER RootPath
    The root directory to search for PDF files. Default is "D:\SHARED\Data".
.PARAMETER LookBackMinutes
    The time frame in minutes to look back for modified PDF files. Default is 30
    minutes
.PARAMETER LogPath
    The path to the log file where actions and errors will be recorded. Default
    is "C:\Logs\UnblockPDFs.log".
.EXAMPLE
    .\Unblock-NewPDFs.ps1 -RootPath "D:\SHARED\Data
    -LookBackMinutes 60
    This example will search for PDF files under D:\SHARED\Data that have been
    modified in the last 60 minutes and attempt to unblock them if they are not
    locked.
.NOTES
    -Author: Dan.Damit (https://github.com/dan-damit/)
#>

param(
    [string]$RootPath = "D:\SHARED\Data",
    [int]$LookBackMinutes = 30,
    [string]$LogPath = "C:\Logs\UnblockPDFs.log"
)

# Ensure log directory exists
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

$since = (Get-Date).AddMinutes(-$LookBackMinutes)
Add-Content -LiteralPath $LogPath -Value ("{0} START Root={1} LookBackMinutes={2}" -f (Get-Date -Format s), $RootPath, $LookBackMinutes)

function Test-FileUnlocked {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $fs.Close()
        return $true
    }
    catch {
        return $false
    }
}

Get-ChildItem -Path $RootPath -Recurse -Filter *.pdf -File -ErrorAction SilentlyContinue |
Where-Object { $_.LastWriteTime -ge $since } |
ForEach-Object {
    $path = $_.FullName

    # Skip files still being copied/locked
    if (-not (Test-FileUnlocked -Path $path)) {
        Add-Content -LiteralPath $LogPath -Value ("{0} SKIP Locked/InUse: {1}" -f (Get-Date -Format s), $path)
        return
    }

    # Only touch files that actually have MOTW/Zone.Identifier
    $zi = Get-Item -LiteralPath $path -Stream Zone.Identifier -ErrorAction SilentlyContinue
    if ($null -ne $zi) {
        try {
            Unblock-File -LiteralPath $path -ErrorAction Stop
            Add-Content -LiteralPath $LogPath -Value ("{0} OK   Unblocked: {1}" -f (Get-Date -Format s), $path)
        }
        catch {
            Add-Content -LiteralPath $LogPath -Value ("{0} FAIL Unblock: {1}  {2}: {3}" -f (Get-Date -Format s), $path, $_.Exception.GetType().Name, $_.Exception.Message)
        }
    }
}
Add-Content -LiteralPath $LogPath -Value ("{0} END" -f (Get-Date -Format s))