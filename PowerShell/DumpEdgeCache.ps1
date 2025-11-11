# Kill Edge processes to avoid file locks
Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "msedgewebview2" -Force -ErrorAction SilentlyContinue

# Base path for Edge user data
$edgeUserData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"

# Profile folders: Default, Profile 1, Profile 2, etc.
$profiles = Get-ChildItem -Path $edgeUserData -Directory | Where-Object {
    $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$"
}

foreach ($prof in $profiles) {
    $profileName = $profile.Name
    $profilePath = $profile.FullName

    # Targeted paths
    $cachePath   = Join-Path $profilePath "Cache"
    $cookiesPath = Join-Path $profilePath "Cookies"

    # Clear Cache
    if (Test-Path $cachePath) {
        Remove-Item "$cachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Cleared cache for profile: $profileName"
    }

    # Clear Cookies (SQLite DB file)
    if (Test-Path $cookiesPath) {
        Remove-Item $cookiesPath -Force -ErrorAction SilentlyContinue
        Write-Host "🍪 Cleared cookies for profile: $profileName"
    }
}