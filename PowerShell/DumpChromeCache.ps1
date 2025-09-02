# Kill Chrome processes to avoid file locks
Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue

# Base path for Chrome user data
$chromeUserData = "$env:LOCALAPPDATA\Google\Chrome\User Data"

# Profile folders: Default, Profile 1, Profile 2, etc.
$profiles = Get-ChildItem -Path $chromeUserData -Directory | Where-Object {
    $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$"
}

foreach ($profile in $profiles) {
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