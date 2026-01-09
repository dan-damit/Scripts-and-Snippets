<#  Author: Dan.Damit

    Script backsup website directory to a zip archive
    Task Scheduler runs weekly
    Cleanup only keeps the 6 most recent backups
    
#>

# Define the source directory
$sourceDir = "C:\Users\dan\Scripts-and-Snippets\Website"

# Generate today's date in yyyy-MM-dd format
$date = Get-Date -Format "yyyy-MM-dd"

# Define the backup zip file name and path
$backupZip = Join-Path $sourceDir "website_bk_$date.zip"

# Get all items to include — exclude previous backups, but preserve structure
$itemsToZip = Get-ChildItem -Path $sourceDir -Recurse | Where-Object {
    $_.FullName -notlike "*\website_bk_*.zip"
}

# Create a temporary staging folder to preserve structure
$tempStaging = Join-Path $env:TEMP "WebsiteBackupStaging"
Remove-Item $tempStaging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tempStaging | Out-Null

# Copy items to staging folder, preserving structure
foreach ($item in $itemsToZip) {
    $relativePath = $item.FullName.Substring($sourceDir.Length).TrimStart("\")
    $destinationPath = Join-Path $tempStaging $relativePath

    if ($item.PSIsContainer) {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
    } else {
        $destDir = Split-Path $destinationPath
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Copy-Item -Path $item.FullName -Destination $destinationPath -Force
    }
}

# Create the zip archive from the staging folder
if (Test-Path $backupZip) {
    Remove-Item $backupZip -Force
}
Compress-Archive -Path $tempStaging\* -DestinationPath $backupZip
Write-Output "Backup created: $backupZip"

# Cleanup staging folder
Remove-Item $tempStaging -Recurse -Force

# Cleanup: keep only the 6 most recent backups
$existingBackups = Get-ChildItem -Path $sourceDir -Filter "website_bk_*.zip" | Sort-Object LastWriteTime -Descending
$backupsToDelete = $existingBackups | Select-Object -Skip 6
foreach ($file in $backupsToDelete) {
    Remove-Item $file.FullName -Force
    Write-Output "Deleted old backup: $($file.Name)"
}