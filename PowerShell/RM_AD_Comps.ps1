<#

Author: Dan.Damit
e: dan@thedamits.com

 This script deletes computers from a user-defined OU that haven't 
 checked in for a user-defined amount of days

-----------------------------------------------------------------------------------------

#>
Import-Module ActiveDirectory

# Prompt user for input
$OU = Read-Host "Enter the Distinguished Name of the OU (e.g., OU=Computers,DC=example,DC=com)"
$DaysInactive = Read-Host "Enter the number of days to check for inactivity"

# Calculate the cutoff date
$CutOffDate = (Get-Date).AddDays(-[int]$DaysInactive)

# Get inactive computer accounts
$InactiveComputers = Get-ADComputer -Filter {LastLogonDate -lt $CutOffDate} -SearchBase $OU

# Confirm deletion
Write-Host "The following computers will be removed:"
foreach ($Computer in $InactiveComputers) {
    Write-Host $Computer.Name
}

$Confirm = Read-Host "Type 'Yes' to confirm deletion of these accounts"
if ($Confirm -eq "Yes") {
    # Loop through and delete them
    foreach ($Computer in $InactiveComputers) {
        Remove-ADComputer -Identity $Computer.DistinguishedName -Confirm:$false
        Write-Host "$($Computer.Name) has been removed."
    }
} else {
    Write-Host "Operation canceled by user."
}