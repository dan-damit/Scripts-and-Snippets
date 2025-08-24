# Define desktop and target folder paths
$desktopPath = [Environment]::GetFolderPath("Desktop")
$targetFolder = Join-Path $desktopPath "Zipped Files"

# Create the target folder if it doesn't exist
if (-not (Test-Path $targetFolder)) {
    New-Item -Path $targetFolder -ItemType Directory | Out-Null
}

# Get all .zip files on the desktop
$zipFiles = Get-ChildItem -Path $desktopPath -Filter *.zip -File

# Move each .zip file to the target folder
foreach ($file in $zipFiles) {
    Move-Item -Path $file.FullName -Destination $targetFolder
}