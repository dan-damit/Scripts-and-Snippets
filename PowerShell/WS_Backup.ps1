<# 
Author: Dan.Damit 
e: dan@thedamits.com 

Description: PowerShell backup script with integrated progress tracking.

Created: 20250604 
Changed: 20250613
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
# Set console params
$scriptName = "Workstation Backup Tool v1.2.1"
$host.UI.RawUI.WindowTitle = $scriptName
$copyrightSymbol = [char]0x00A9
[console]::ForegroundColor = "DarkCyan"
Write-Host "`n`n`n`n`n`n`n`n"
Write-host "-----------------------------------------------"
Write-host "Advantage Technologies Workstation Backup Sript"
Write-host #
$ASCIILogo = "`n"+
    "`t            (((`n"+
    "`t           (((   *`n"+
    "`t          (((   ***`n"+
    "`t         (((     ***`n"+
    "`t        (((  ((   ***`n"+
    "`t       (((((((((   ***`n"+
    "`n"

Write-host "$ASCIILogo"
Write-host "      Copyright $copyrightSymbol 2025 Author: Dan.Damit"
Write-host "-----------------------------------------------"
Write-host #

[console]::ForegroundColor = "Yellow"
# Define backup destination and username
$share = Read-Host "Enter the path to the backup directory (local or UNC)"
$user = Read-Host "Enter the source username"
$backupPath = "$share\$user"
[console]::ForegroundColor = "DarkCyan"
Write-Host #

# Check if backup path exists
if (Test-Path $backupPath) {
    Write-Host "Path already exists. Please resolve or choose another name."
    Pause
    Exit
} else {
    New-Item -ItemType Directory -Path $backupPath | Out-Null
}
# Create subdirectories
$otherPath = "$backupPath\OTHER"
$appDataPath = "$backupPath\appdata"
New-Item -ItemType Directory -Path $otherPath | Out-Null
New-Item -ItemType Directory -Path $appDataPath | Out-Null

Write-Host #
Write-Host "Please be patient. Copying will take a while depending on local profile size." -ForegroundColor Red
Write-Host #

# Initialize progress tracking
$progressStep = 0
$totalSteps = 19
$progressIncrement = [math]::Round(100 / $totalSteps)

# Gather system information
$techInfoPath = "$otherPath\tech info.txt"
Get-Date | Out-File -Append $techInfoPath
Write-Output "-------------------`nNETWORK DRIVES" | Out-File -Append $techInfoPath
Get-PSDrive -PSProvider FileSystem | Out-File -Append $techInfoPath
Write-Output "-------------------`nPRINTERS" | Out-File -Append $techInfoPath
Get-Printer | Select-Object Name, PrinterStatus, DriverName, PortName | Out-File -Append $techInfoPath
Write-Output "-------------------`nIP AND NETWORK INFORMATION" | Out-File -Append $techInfoPath
Get-NetIPConfiguration -Detailed | Out-File -Append $techInfoPath
Write-Output "-------------------`nSHARED RESOURCE INFO" | Out-File -Append $techInfoPath
Get-SmbShare | Out-File -Append $techInfoPath

# Close applications
$appsToClose = @("firefox.exe", "chrome.exe", "outlook.exe", "StikyNot.exe", "MicrosoftEdge.exe", "MicrosoftEdgeCP.exe")
foreach ($app in $appsToClose) {
    Stop-Process -Name $app -Force -ErrorAction SilentlyContinue
}
# Backup main user profile directories with progress bar
$directories = @("contacts", "desktop", "documents", "downloads", "favorites", "links", "music", "pictures", "saved games", "searches", "videos")
foreach ($dir in $directories) {
    $source = "$env:USERPROFILE\$dir"
    $destination = "$backupPath\$dir"
	# Increment progress and update bar
    $progressStep += $progressIncrement
    Write-Progress -Activity "Backing up user profile data" -Status "Copying: $dir" -PercentComplete $progressStep
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $destination -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Copied '$dir' successfully!" -ForegroundColor Green
    } else {
        Write-Host "Skipping '$dir' (Path not found)" -ForegroundColor Yellow
    }
}
# Backup specific application data with progress tracking
$appDataDirs = @{
    "appdata\local\dymo" = "$appDataPath\local\dymo"
    "appdata\local\google" = "$appDataPath\local\google"
    "appdata\local\google\chrome\user data\default" = "$appDataPath\local\google\chrome\user data\default"
    "appdata\local\mozilla" = "$appDataPath\local\mozilla"
    "appdata\local\microsoft\outlook" = "$appDataPath\local\microsoft\outlook"
    "appdata\roaming\mozilla" = "$appDataPath\roaming\mozilla"
    "appdata\roaming\microsoft\signatures" = "$appDataPath\roaming\microsoft\signatures"
    "appdata\local\Microsoft\Edge\User Data" = "$appDataPath\local\Microsoft\Edge\User Data"
    "appdata\local\Microsoft\Edge\User Data\Default" = "$appDataPath\local\Microsoft\Edge\User Data\Default"
}
foreach ($key in $appDataDirs.Keys) {
    $source = "$env:USERPROFILE\$key"
    $destination = $appDataDirs[$key]
	# Increment progress and update bar
    $progressStep += $progressIncrement
    Write-Progress -Activity "Backing up application data" -Status "Copying: $key" -PercentComplete $progressStep
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $destination -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Copied '$key' successfully!" -ForegroundColor Green
    } else {
        Write-Host "Skipping '$key' (Path not found)" -ForegroundColor Yellow
    }
}
Write-host #
# Export registry hive and grab SID of User profile being backed up for HKCU registry restore on new workstation.
$User = New-Object System.Security.Principal.NTAccount($env:UserName)
$SID = $User.Translate([System.Security.Principal.SecurityIdentifier]).Value
Write-Host "User SID: $SID"
$RegistryBackupPath = "$backupPath\HKCU_Backup_$SID.reg"
reg export HKCU $RegistryBackupPath /y
Write-host "User Settings registry hive backed up to $backupPath"
# Finalize progress
Write-Progress -Activity "Backup process" -Status "Backup Complete!" -PercentComplete 100
Write-Host "Backup complete! Your files are located under $backupPath" -BackgroundColor Green -ForegroundColor Black
Pause