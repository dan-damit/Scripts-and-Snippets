<# Author: Dan.Damit (https://github.com/dan-damit)

Connects to IPPSSession in Search-Only mode, lists the top 10 compliance searches,
then prompts for a Search Name/ID and runs a HardDelete purge with confirmation.

Enhancement:
- If the selected search is in "NotStarted" status, the script will prompt to start it.
- If approved, Start-ComplianceSearch is executed before the purge workflow continues.

Run in Windows PowerShell or PowerShell 7 with ExchangeOnlineManagement module.
Requires appropriate permissions in Microsoft 365 Compliance / EOP.
#>

# Helper: Ensure ExchangeOnlineManagement module is available
function Import-ExchangeOnlineModule {
    try {
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            Write-Host "ExchangeOnlineManagement module not found. Attempting to install..." -ForegroundColor Yellow
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

# Execute purge action with auto-start logic
function Invoke-HardDeletePurge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName
    )

    # Validate search exists
    try {
        $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
    }
    catch {
        Write-Error "Search '$SearchName' not found or inaccessible: $($_.Exception.Message)"
        return
    }

    # Auto-start if NotStarted
    if ($search.Status -eq 'NotStarted') {
        Write-Host "`nSearch '$SearchName' is currently in 'NotStarted' status." -ForegroundColor Yellow
        $startConfirm = Read-Host "Start the compliance search now? (Y to start)"

        if ($startConfirm -match '^[Yy]$') {
            try {
                Write-Host "Starting compliance search..." -ForegroundColor Cyan
                Start-ComplianceSearch -Identity $SearchName -ErrorAction Stop
                Write-Host "Search started." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to start compliance search: $($_.Exception.Message)"
                return
            }

            # Optional wait loop for status change
            Write-Host "Waiting for search to begin processing..." -ForegroundColor Cyan
            for ($i = 1; $i -le 10; $i++) {
                Start-Sleep -Seconds 3
                $status = (Get-ComplianceSearch -Identity $SearchName).Status
                if ($status -ne 'NotStarted') {
                    Write-Host "Search status is now: $status" -ForegroundColor Green
                    break
                }
                if ($i -eq 10) {
                    Write-Host "Search is still NotStarted after waiting. Cannot continue." -ForegroundColor Red
                    return
                }
            }
        }
        else {
            Write-Host "Search was not started. Purge cannot continue." -ForegroundColor Red
            return
        }
    }

    # Purge confirmation
    Write-Host "`nYou are about to run a **HardDelete purge** for search: '$SearchName'." -ForegroundColor Yellow
    Write-Host "This action permanently deletes matching items (non-recoverable)." -ForegroundColor Yellow
    $confirm = Read-Host "Type 'YES' to confirm, or anything else to cancel"

    if ($confirm -ne 'YES') {
        Write-Host "Cancelled. No purge was performed." -ForegroundColor Cyan
        return
    }

    # Execute purge
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
    # Import Exchange Online module
    Import-ExchangeOnlineModule
    # Prompt for UPN and connect
    $upn = Read-Host "Enter UPN (e.g., username@companydomain.com)"
    if ([string]::IsNullOrWhiteSpace($upn)) { throw "UPN cannot be empty." }
    # Connect to Exchange Online
    Connect-SearchOnlySession -UserPrincipalName $upn
    # Show recent compliance searches
    Show-RecentComplianceSearches
    # Prompt for search to purge
    $searchName = Read-Host "Enter the Compliance Search Name/ID to purge"
    if ([string]::IsNullOrWhiteSpace($searchName)) { throw "Search Name/ID cannot be empty." }
    # Invoke purge
    Invoke-HardDeletePurge -SearchName $searchName
}
catch { } # Error handling is done in functions
# === Disconnect session prompt ===
finally {
    $disconnectSession = Read-Host "Disconnect session now? (Y to disconnect)"
    if ($disconnectSession -match '^[Yy]$') {
        Disconnect-ExchangeOnline -Confirm:$false
        Write-Host "Disconnected from Exchange Online." -ForegroundColor Green
    } else {
        Write-Host "Session remains connected." -ForegroundColor Yellow
    }
}