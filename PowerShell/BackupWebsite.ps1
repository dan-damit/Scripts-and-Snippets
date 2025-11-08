# Define the source directory
$sourceDir = "C:\Users\dan\Scripts-and-Snippets\Website"

# Generate today's date in yyyy-MM-dd format
$date = Get-Date -Format "yyyy-MM-dd"

# Define the backup zip file name and path
$backupZip = Join-Path $sourceDir "website_bk_$date.zip"

# Get all items in the source directory excluding previous backups
$itemsToZip = Get-ChildItem -Path $sourceDir -Recurse | Where-Object {
    $_.FullName -notlike "*\website_bk_*.zip"
}

# Create the zip archive
if (Test-Path $backupZip) {
    Remove-Item $backupZip -Force
}
Compress-Archive -Path $itemsToZip.FullName -DestinationPath $backupZip
Write-Output "Backup created: $backupZip"

# Cleanup: keep only the 6 most recent backups
$existingBackups = Get-ChildItem -Path $sourceDir -Filter "website_bk_*.zip" | Sort-Object LastWriteTime -Descending
$backupsToDelete = $existingBackups | Select-Object -Skip 6
foreach ($file in $backupsToDelete) {
    Remove-Item $file.FullName -Force
    Write-Output "Deleted old backup: $($file.Name)"
}