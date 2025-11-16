<#
Author: Dan.Damit
e: dan@thedamits.com

Description:
    Script joins the computer to a domain

Created: 20250502
Changed: 20250502

#>

[console]::ForegroundColor = "DarkCyan"
Start-Sleep -Seconds 1
Write-Host #
Write-Host "----------------------------------------------------------"
Write-Host "!!!*Starting Domain Join process*!!!" -ForegroundColor Magenta
Write-Host "----------------------------------------------------------"
Write-Host #

# Function to validate domain existence using nltest
function Get-Domain {
    param($DomainName)
    $DomainExists = $false

    try {
        $result = nltest /dsgetdc:$DomainName 2>&1
        if ($result -match "DSGetDcName failed") {
            Write-Host "Domain '$DomainName' not found or could not be contacted. Please enter a valid domain name." -ForegroundColor Red
        } else {
            $DomainExists = $true
        }
    } catch {
        Write-Host "Error validating domain: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $DomainExists
}

# Define retry parameters
$MaxRetries = 5
$RetryCount = 0
$DomainJoined = $false

# Prompt for domain name with retry logic
do {
    $DomainName = Read-Host "Enter the domain name (type NONE or NULL to skip domain join)"
    if ($DomainName -eq "NONE" -or $DomainName -eq "NULL") {
        Write-Host "Skipping domain join as requested." -ForegroundColor Cyan
        exit
    }

    $DomainValid = Validate-Domain $DomainName
    if (-not $DomainValid) {
        $RetryCount++
        if ($RetryCount -lt $MaxRetries) {
            Write-Host "Retrying domain validation... Attempt $RetryCount of $MaxRetries" -ForegroundColor Yellow
        } else {
            Write-Host "Maximum retry attempts reached. Please check the domain settings and try again later." -ForegroundColor Red
            exit
        }
    }
} while (-not $DomainValid)

# Reset retry counter for domain join process
$RetryCount = 0

Write-host #

# Attempt to join the domain with retry mechanism
do {
    $Credential = Get-Credential -Message "Enter credentials for the domain"

    try {
        Add-Computer -DomainName $DomainName -Credential $Credential -ErrorAction Stop
        Write-Host "The computer has been successfully joined to the domain." -ForegroundColor Green
        $DomainJoined = $true
    } catch {
        Write-Host "Error joining the domain: $($_.Exception.Message)" -ForegroundColor Red
        $RetryCount++

        if ($RetryCount -lt $MaxRetries) {
            Write-Host "Retrying domain join... Attempt $RetryCount of $MaxRetries." -ForegroundColor Yellow
            Write-Host "Re-enter domain and credentials before retrying." -ForegroundColor Cyan
            Write-Host #
            $DomainName = Read-Host "Enter the domain name (type NONE or NULL to skip domain join)"
            if ($DomainName -eq "NONE" -or $DomainName -eq "NULL") {
                Write-Host "Skipping domain join as requested." -ForegroundColor Cyan
                exit
            }
        } else {
            Write-Host "Maximum retry attempts reached. Please verify credentials and network access." -ForegroundColor Red
            exit
        }
    }
} while (-not $DomainJoined -and $RetryCount -lt $MaxRetries)

Write-Host #

# Confirm domain join status
$CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
if ($DomainJoined -and $CurrentDomain -eq $DomainName) {
    Write-Host "The computer is now confirmed as part of '$DomainName'." -ForegroundColor Cyan
} else {
    Write-Host "Domain join failed or not confirmed. Please retry with valid credentials or network settings." -ForegroundColor Yellow
}
Pause