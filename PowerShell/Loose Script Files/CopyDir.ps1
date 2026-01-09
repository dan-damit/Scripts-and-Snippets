<# Short Script to copy a dir to anther dir #>

# Author Dan.Damit (https://github.com/dan-damit)

# Prompt for source and destination
$Source = Read-Host "Enter the source path (e.g. \\Server\Share\Folder\Source)"
$DestinationRoot = Read-Host "Enter the destination path (e.g. \\Server\Share\Destination)"

# Derive folder name from source path
$FolderName = Split-Path $Source -Leaf
$Destination = Join-Path $DestinationRoot $FolderName

# Ensure log directory exists
$LogRoot = "C:\Logs"
if (!(Test-Path $LogRoot)) {
    New-Item -ItemType Directory -Path $LogRoot | Out-Null
}
$LogFile = Join-Path $LogRoot "$FolderName-to-Management.log"

Write-Host "Starting Robocopy from $Source to $Destination..."

# Build Robocopy command
$cmd = @(
    "robocopy",
    "`"$Source`"",
    "`"$Destination`"",
    "/E",        # copy all subfolders including empty
    "/COPYALL",  # preserve permissions, timestamps, attributes
    "/R:2",      # retry twice on failure
    "/W:5",      # wait 5 seconds between retries
    "/LOG:$LogFile"
) -join " "

# Run Robocopy
Invoke-Expression $cmd

Write-Host "Finished copying $FolderName. Log saved to $LogFile."