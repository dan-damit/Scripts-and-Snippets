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