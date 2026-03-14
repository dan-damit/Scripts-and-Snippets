# Path to the GraphicsDrivers registry key
$TdrPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

Write-Host "Configuring TDR timeout values..." -ForegroundColor Cyan

# Backup existing values if they exist
$Backup = @{}

foreach ($key in @("TdrDelay", "TdrDdiDelay")) {
    if (Get-ItemProperty -Path $TdrPath -Name $key -ErrorAction SilentlyContinue) {
        $Backup[$key] = (Get-ItemProperty -Path $TdrPath -Name $key).$key
        Write-Host "Backed up existing $key = $($Backup[$key])"
    }
}

# Create or update TdrDelay (GPU response timeout)
New-ItemProperty -Path $TdrPath -Name "TdrDelay" -Value 10 -PropertyType DWORD -Force | Out-Null
Write-Host "Set TdrDelay = 10 seconds"

# Create or update TdrDdiDelay (driver-level timeout)
New-ItemProperty -Path $TdrPath -Name "TdrDdiDelay" -Value 20 -PropertyType DWORD -Force | Out-Null
Write-Host "Set TdrDdiDelay = 10 seconds"

# Save backup to a JSON file for easy restore
$BackupPath = "$env:USERPROFILE\TDR_Backup.json"
$Backup | ConvertTo-Json | Out-File $BackupPath
Write-Host "Backup saved to $BackupPath" -ForegroundColor Yellow

Write-Host "`nTDR timeout configuration complete. Please reboot to apply changes." -ForegroundColor Green