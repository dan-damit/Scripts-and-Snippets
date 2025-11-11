<# PSScriptInfo

Author: Dan.Damit
e: dan@thedamits.com

DESCRIPTION:
	This script will prompt for initial size and max size of pagefile.sys
	Also, it will disable automatic management of the pagefile.sys
		
Date Created: 20250401
Date last modified: 20250402
	
#>


# Function to check for administrator privileges
Function Test-Administrator {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for admin privileges
if (-not (Test-Administrator)) {
    Write-Host "This script requires administrative privileges. Restarting as admin in 5 seconds..." -ForegroundColor Red
    
    # Countdown timer
    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "$i..." -NoNewline
        Start-Sleep -Seconds 1
        Write-Host "`r" -NoNewline # Clear the line for countdown effect
    }
    Write-Host ""
    
    # Restart the script as administrator
    Start-Process powershell -ArgumentList "-File $($MyInvocation.MyCommand.Path)" -Verb RunAs
    exit
}

# Prompt the user for the initial size
$InitialSize = Read-Host "Enter the initial pagefile size in MB"

# Prompt the user for the maximum size
$MaximumSize = Read-Host "Enter the maximum pagefile size in MB"

# Disable automatic management of the pagefile
$computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$computersys.AutomaticManagedPagefile = $False
$computersys.Put()

# Apply the custom pagefile size
$pagefile = Get-WmiObject -Query "Select * From Win32_PageFileSetting Where Name like '%pagefile.sys'"
$pagefile.InitialSize = [int]$InitialSize
$pagefile.MaximumSize = [int]$MaximumSize
$pagefile.Put()

# Confirm success
Write-Host "Pagefile sizes have been updated successfully."

# Prompt the user for restart
$response = Read-Host "Would you like to reboot now? y/n?"

if ($response -eq "y") {
    Write-Host "Rebooting now..." -ForegroundColor Green
    Restart-Computer -Force
} else {
    Write-Host "You can reboot later to apply the changes." -ForegroundColor Yellow
Pause
}