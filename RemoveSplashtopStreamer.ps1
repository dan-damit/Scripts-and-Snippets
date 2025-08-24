# Author: Dan.Damit
# e: Dan@thedamits.com
#
# Description: This script removes Splashtop Streamer
# Date Created: 20250219
# Date Last Modified: 20250220
#-----------------------------------------------------------------
#
#
# Uninstall Splashtop Streamer using the product name
$application = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name = 'Splashtop Streamer'" | Select-Object -ExpandProperty IdentifyingNumber
if ($application) {
    $application | ForEach-Object { msiexec.exe /x $_ /quiet /norestart }
    Write-Host "Splashtop Streamer has been uninstalled."
} else {
    Write-Host "Splashtop Streamer is not installed on this system."
}

Write-Host "Cleanup complete."
