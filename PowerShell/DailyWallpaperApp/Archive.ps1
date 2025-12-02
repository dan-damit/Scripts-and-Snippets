# ================================
# Bing Wallpaper Archive Script
# ================================

# Load config
$configPath = Join-Path $PSScriptRoot "config.json"
if (!(Test-Path $configPath)) {
    Write-Error "Missing config.json. Please create one."
    exit
}
$config = Get-Content $configPath | ConvertFrom-Json

$archiveDir = $config.ArchiveDir
$limitGB = $config.LimitGB
$limitBytes = $limitGB * 1GB
$market = $config.Market

# Ensure archive directory exists
if (!(Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir | Out-Null
}

# Favorites file
$favoritesFile = Join-Path $archiveDir "favorites.txt"
if (!(Test-Path $favoritesFile)) { New-Item -ItemType File -Path $favoritesFile | Out-Null }
$favorites = Get-Content $favoritesFile

# Bing API endpoint
$bingApi = "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$market"

try {
    $response = Invoke-RestMethod -Uri $bingApi -ErrorAction Stop
    $imageUrl = "https://www.bing.com" + $response.images[0].url
}
catch {
    Write-Error "Failed to fetch Bing wallpaper metadata: $_"
    exit
}

# Date-stamped filename
$dateStamp = (Get-Date).ToString("yyyy-MM-dd")
$archiveFile = Join-Path $archiveDir ("Bing_" + $dateStamp + ".jpg")

# Download image if not already archived
if (!(Test-Path $archiveFile)) {
    try {
        Invoke-WebRequest -Uri $imageUrl -OutFile $archiveFile -ErrorAction Stop
        Write-Host "Archived new wallpaper: $archiveFile"
    }
    catch {
        Write-Error "Failed to download Bing wallpaper: $_"
    }
}
else {
    Write-Host "Wallpaper for $dateStamp already archived."
}

# --- Archive size management ---
function Get-FolderSize($path) {
    (Get-ChildItem $path -Recurse | Measure-Object -Property Length -Sum).Sum
}

$folderSize = Get-FolderSize $archiveDir
if ($folderSize -gt $limitBytes) {
    Write-Host "Archive exceeds $limitGB GB. Cleaning up oldest non-favorites..."
    Get-ChildItem $archiveDir -Filter *.jpg | Sort-Object CreationTime | ForEach-Object {
        if ((Get-FolderSize $archiveDir) -le $limitBytes) { return }
        if ($favorites -contains $_.Name) {
            Write-Host "Skipping favorite: $($_.Name)"
        }
        else {
            Write-Host "Deleting: $($_.Name)"
            Remove-Item $_.FullName -Force
        }
    }
}