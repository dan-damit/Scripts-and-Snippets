
<# Author: Dan.Damit (https://github.com/dan-damit)

Connects to IPPSSession in Search-Only mode, lists the top 10 compliance searches,
then prompts for a Search Name/ID and runs a HardDelete purge with confirmation.

- Prompts for UPN and connects via Connect-IPPSSession -EnableSearchOnlySession.
- Displays top 10 searches with local CreatedTime.
- Prompts for SearchName/ID and requests final confirmation.
- Executes New-ComplianceSearchAction -Purge -PurgeType HardDelete.

Run in Windows PowerShell or PowerShell 7 with ExchangeOnlineManagement module.
Requires appropriate permissions in Microsoft 365 Compliance / EOP.
#>

# Helper: Ensure ExchangeOnlineManagement module is available
function Import-ExchangeOnlineModule {
    try {
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            Write-Host "ExchangeOnlineManagement module not found. Attempting to install..." -ForegroundColor Yellow
            # Install for current user to avoid admin requirement
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
        }
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to install/import ExchangeOnlineManagement: $($_.Exception.Message)"
        throw
    }
}

# Connect to IPPSSession
function Connect-SearchOnlySession {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    try {
        Write-Host "Connecting to Security & Compliance PowerShell (Search-Only session)..." -ForegroundColor Cyan
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -EnableSearchOnlySession -ErrorAction Stop
        Write-Host "Connected." -ForegroundColor Green
    }
    catch {
        Write-Error "Connection failed: $($_.Exception.Message)"
        throw
    }
}

# Show recent compliance searches
function Show-RecentComplianceSearches {
    try {
        Write-Host "`nTop 10 most recent compliance searches:" -ForegroundColor Cyan
        $searches = Get-ComplianceSearch |
            Sort-Object -Property CreatedTime -Descending |
            Select-Object -First 10 `
                @{Name='Name';Expression={$_.Name}},
                @{Name='CreatedTime_LocalTime';Expression={ $_.CreatedTime.ToLocalTime() }},
                @{Name='Status';Expression={$_.Status}}

        if ($null -eq $searches -or $searches.Count -eq 0) {
            Write-Warning "No compliance searches found."
        } else {
            $searches | Format-Table -AutoSize
        }
    }
    catch {
        Write-Error "Failed to list compliance searches: $($_.Exception.Message)"
        throw
    }
}

# Execute purge action
function Invoke-HardDeletePurge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName
    )

    Write-Host "`nYou are about to run a **HardDelete purge** for search: '$SearchName'." -ForegroundColor Yellow
    Write-Host "This action permanently deletes matching items (non-recoverable)." -ForegroundColor Yellow
    $confirm = Read-Host "Type 'YES' to confirm, or anything else to cancel"

    if ($confirm -ne 'YES') {
        Write-Host "Cancelled. No purge was performed." -ForegroundColor Cyan
        return
    }

    try {
        Write-Host "Submitting purge action..." -ForegroundColor Cyan
        $result = New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType HardDelete -ErrorAction Stop
        Write-Host "Purge action submitted successfully." -ForegroundColor Green
        $result | Format-List
    }
    catch {
        Write-Error "Purge action failed: $($_.Exception.Message)"
        throw
    }
}

# --------------------------
# Main script execution flow
# --------------------------
try {
    #1) Import module
    Import-ExchangeOnlineModule
    #1.1) Prompt for UPN
    $upn = Read-Host "Enter UPN (e.g., username@companydomain.com)"
    if ([string]::IsNullOrWhiteSpace($upn)) {
        throw "UPN cannot be empty."
    }
    #2) Connect to Search-Only session
    Connect-SearchOnlySession -UserPrincipalName $upn
    #3) Show recent searches
    Show-RecentComplianceSearches
    #4) Prompt for Search Name/ID and execute purge
    $searchName = Read-Host "Enter the Compliance Search Name/ID to purge"
    if ([string]::IsNullOrWhiteSpace($searchName)) {
        throw "Search Name/ID cannot be empty."
    }
    #5) Invoke HardDelete purge
    Invoke-HardDeletePurge -SearchName $searchName
}
catch {
    Write-Error "Script terminated due to error: $($_.Exception.Message)"
}
finally {
    # Optional: Disconnect the session
    # Disconnect-ExchangeOnline -Confirm:$false
}

