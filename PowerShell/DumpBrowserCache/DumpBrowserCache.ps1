<# 
.SYNOPSIS
    Clear cache and cookies for Chrome and Edge profiles (Default, Profile N).

.DESCRIPTION
    - Stops running Chrome/Edge processes (optional), waits briefly to release locks.
    - Clears cache content across common cache directories.
    - Removes cookie SQLite DBs from modern and legacy locations.
    - Supports -Browser, -Profiles, -IncludeCookies/-IncludeCache, -SkipLocalStorage,
      -WhatIf, -Verbose, and logging.
    - Returns structured objects for automation.

.NOTES
    Author: Dan.Damit (https://github.com/dan-damit)
    Tested on Windows 10/11 with Chromium-based Chrome and Edge.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Chrome', 'Edge', 'All')]
    [string]$Browser = 'All',

    [string[]]$Profiles,

    [bool]$IncludeCookies = $true,
    [bool]$IncludeCache   = $true,
    [bool]$SkipLocalStorage = $false,

    [bool]$KillProcesses  = $true,
    [int] $SleepAfterKillMs = 1500,

    [string]$LogPath
)

# ---------- Helpers ----------
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$ts][$Level] $Message"
    Write-Host $line
    if ($LogPath) {
        try {
            $dir = Split-Path -Path $LogPath -Parent
            if ($dir -and -not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            Add-Content -LiteralPath $LogPath -Value $line
        } catch {
            Write-Host "[$ts][WARN] Failed to write log: $($_.Exception.Message)"
        }
    }
}

function Get-UserDataPath {
    param([Parameter(Mandatory)][ValidateSet('Chrome','Edge')][string]$Browser)
    switch ($Browser) {
        'Chrome' { Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data' }
        'Edge'   { Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data' }
    }
}

function Stop-BrowserProcesses {
    param([Parameter(Mandatory)][ValidateSet('Chrome','Edge')][string]$Browser)
    $name = if ($Browser -eq 'Chrome') { 'chrome' } else { 'msedge' }
    try {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Log "Stopping $(($procs | Measure-Object).Count) $Browser process(es)..." 'INFO'
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            if ($SleepAfterKillMs -gt 0) { Start-Sleep -Milliseconds $SleepAfterKillMs }
        } else {
            Write-Log "No $Browser processes found." 'INFO'
        }
    } catch {
        Write-Log "Failed to stop $Browser processes: $($_.Exception.Message)" 'WARN'
    }
}

function Get-ProfileFolders {
    param([Parameter(Mandatory)][string]$UserDataPath)

    if (-not (Test-Path -LiteralPath $UserDataPath)) {
        Write-Log "User Data path not found: $UserDataPath" 'ERROR'
        return @()
    }

    Get-ChildItem -Path $UserDataPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile \d+$' }
}

function Clear-CacheForProfile {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory)][string]$ProfilePath)

    $cacheTargets = @(
        (Join-Path $ProfilePath 'Cache'),
        (Join-Path $ProfilePath 'Code Cache'),
        (Join-Path $ProfilePath 'GPUCache'),
        (Join-Path $ProfilePath 'Service Worker'),
        (Join-Path $ProfilePath 'Application Cache'),
        (Join-Path $ProfilePath 'Network\Cache')
    )

    foreach ($cachePath in $cacheTargets) {
        try {
            if (Test-Path -LiteralPath $cachePath) {
                if ($PSCmdlet.ShouldProcess($cachePath, 'Clear cache contents')) {
                    Remove-Item -LiteralPath (Join-Path $cachePath '*') -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleared cache content: $cachePath" 'SUCCESS'
                }
            } else {
                Write-Log "Cache path not present: $cachePath" 'INFO'
            }
        } catch {
            Write-Log "Error clearing cache at '$cachePath': $($_.Exception.Message)" 'WARN'
        }
    }
}

function Clear-CookiesForProfile {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory)][string]$ProfilePath)

    $cookieTargets = @(
        (Join-Path $ProfilePath 'Network\Cookies'),
        (Join-Path $ProfilePath 'Network\Cookies-journal'),
        (Join-Path $ProfilePath 'Cookies'),
        (Join-Path $ProfilePath 'Cookies-journal')
    )

    foreach ($cookiesPath in $cookieTargets) {
        try {
            if (Test-Path -LiteralPath $cookiesPath) {
                if ($PSCmdlet.ShouldProcess($cookiesPath, 'Delete cookie DB')) {
                    Remove-Item -LiteralPath $cookiesPath -Force -ErrorAction SilentlyContinue
                    Write-Log "Removed cookie DB: $cookiesPath" 'SUCCESS'
                }
            } else {
                Write-Log "Cookie DB not present: $cookiesPath" 'INFO'
            }
        } catch {
            Write-Log "Error removing cookies DB '$cookiesPath': $($_.Exception.Message)" 'WARN'
        }
    }

    if (-not $SkipLocalStorage) {
        $localStoragePath = Join-Path $ProfilePath 'Local Storage'
        if (Test-Path -LiteralPath $localStoragePath) {
            try {
                if ($PSCmdlet.ShouldProcess($localStoragePath, 'Clear Local Storage')) {
                    Remove-Item -LiteralPath (Join-Path $localStoragePath '*') -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleared Local Storage: $localStoragePath" 'SUCCESS'
                }
            } catch {
                Write-Log "Error clearing Local Storage: $($_.Exception.Message)" 'WARN'
            }
        }
    }
}

# ---------- Main ----------
$results = New-Object System.Collections.Generic.List[object]

$targetBrowsers = switch ($Browser) {
    'Chrome' { @('Chrome') }
    'Edge'   { @('Edge') }
    'All'    { @('Chrome','Edge') }
}

# --- DRY RUN SUMMARY ---
if ($WhatIfPreference) {
    Write-Host "=== DRY RUN SUMMARY ==="
    Write-Host "Browsers: $($targetBrowsers -join ', ')"
    Write-Host "Include Cache: $IncludeCache"
    Write-Host "Include Cookies: $IncludeCookies"
    Write-Host "Skip Local Storage: $SkipLocalStorage"
    Write-Host "Kill Processes: $KillProcesses"
    Write-Host "Profiles filter: $($Profiles -join ', ')"
    Write-Host "======================="
}

foreach ($b in $targetBrowsers) {
    Write-Log "=== Processing $b ===" 'INFO'

    if ($KillProcesses) { Stop-BrowserProcesses -Browser $b }

    $userData = Get-UserDataPath -Browser $b
    $profileDirs = Get-ProfileFolders -UserDataPath $userData

    Write-Log "Discovered profiles: $($profileDirs.Name -join ', ')" 'INFO'

    if ($Profiles) {
        $profileDirs = $profileDirs | Where-Object { $Profiles -contains $_.Name }
        Write-Log "Filtered profiles: $($profileDirs.Name -join ', ')" 'INFO'
    }

    foreach ($prof in $profileDirs) {
        $profileName = $prof.Name
        $profilePath = $prof.FullName

        Write-Log "Profile: '$profileName' ($profilePath)" 'INFO'

        if ($IncludeCache)   { Clear-CacheForProfile   -ProfilePath $profilePath }
        if ($IncludeCookies) { Clear-CookiesForProfile -ProfilePath $profilePath }

        Write-Log "Finished: $profileName" 'INFO'

        $results.Add([PSCustomObject]@{
            Browser             = $b
            Profile             = $profileName
            CacheCleared        = $IncludeCache
            CookiesCleared      = $IncludeCookies
            LocalStorageCleared = (-not $SkipLocalStorage)
            Timestamp           = (Get-Date)
        })
    }

    Write-Log "=== Completed $b ===" 'SUCCESS'
}

Write-Log "All requested browser profile cleanup completed." 'SUCCESS'

return $results