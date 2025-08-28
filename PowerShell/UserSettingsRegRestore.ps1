<#  
 Author: Dan.Damit  
 e: dan@thedamits.com
 
 Description: Automated HKCU restore process  
 Created: 20250613  
#>
# Check for admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Restarting as admin..." -ForegroundColor Yellow
    $ScriptPath = $MyInvocation.MyCommand.Definition
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`"" -Verb RunAs
    Start-Sleep -Seconds 2
    Exit
}
# Setup Console Params
[console]::ForegroundColor = "DarkCyan"
$copyrightSymbol = [char]0x00A9
Write-Host "----------------------------------"
Write-Host " BEGINNING USER SETTINGS RESTORE"
Write-Host "----------------------------------"
Write-host "Copyright $copyrightSymbol 2025 Author: Dan.Damit"
Write-Host "----------------------------------"
Write-Host `n

# Prompt for user profile to restore
$targetUser = Read-Host "Enter the username for the registry restore"
# Retrieve SID of the target user
$User = New-Object System.Security.Principal.NTAccount($targetUser)
$TargetSID = $User.Translate([System.Security.Principal.SecurityIdentifier]).Value
Write-Host "Target User SID: $TargetSID" -ForegroundColor Yellow

# Define backup location
$backupPath = Read-Host "Enter path to the backup directory containing registry backup"
$registryBackupPath = "$backupPath\HKCU_Backup_$TargetSID.reg"
# Verify backup file exists
if (!(Test-Path $registryBackupPath)) {
    Write-Host "ERROR: Backup file not found!" -ForegroundColor Red
    Pause
    Exit
}
Write-Host "Backup found. Proceeding with restoration..." -ForegroundColor Green

# Retrieve the correct profile path for the target user using SID
$profilePath = (Get-WmiObject Win32_UserProfile | Where-Object { $_.SID -eq $TargetSID }).LocalPath
# Verify that the profile was found
if ($profilePath) {
    Write-Host "Resolved profile path: $profilePath" -ForegroundColor Yellow
    $ntuserPath = "$profilePath\Ntuser.dat"
} else {
    Write-Host "ERROR: Unable to find profile for SID $TargetSID!" -ForegroundColor Red
    Pause
    Exit
}
# Verify Ntuser.dat exists before proceeding
if (!(Test-Path $ntuserPath)) {
    Write-Host "ERROR: Ntuser.dat file missing in $profilePath!" -ForegroundColor Red
    Pause
    Exit
}

Write-Host "Loading registry hive..." -ForegroundColor Yellow
reg load HKU\TempHive "$ntuserPath"
# Import backed-up registry data
Write-Host "Restoring registry settings..." -ForegroundColor Green
reg import $registryBackupPath
# Unload temporary hive after restore
Write-Host "Finalizing restore..." -ForegroundColor Yellow
reg unload HKU\TempHive
Write-Host #
Write-Host "Restore complete! Log in as $targetUser to verify settings." -ForegroundColor Green
Pause