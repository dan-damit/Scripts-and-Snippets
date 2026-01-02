
# ============================================================
# Enhanced Compliance Search HardDelete Purge Script
# Author: Dan.Damit (https://github.com/dan-damit)
#
# New Enhancements:
# - Adds -ForceFullSession parameter for deterministic behavior.
# - Adds automatic fallback to full session if purge fails due to session limitations.
# - Adds retry logic for purge (1 retry max).
# - Adds clear audit logging for fallback events.
# ============================================================

param(
    [switch]$ForceFullSession
)

# --------------------------
# Helper: Ensure EXO module
# --------------------------
function Import-ExchangeOnlineModule {
    try {
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            Write-Host "ExchangeOnlineManagement module not found. Installing..." -ForegroundColor Yellow
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
        }
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to install/import ExchangeOnlineManagement: $($_.Exception.Message)"
        throw
    }
}

# --------------------------
# Connect to IPPSSession
# --------------------------
function Connect-SearchSession {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        [switch]$ForceFullSession
    )

    if ($ForceFullSession) {
        Write-Host "Forcing full IPPSSession connection..." -ForegroundColor Cyan
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
        Write-Host "Connected using full IPPSSession." -ForegroundColor Green
        return "Full"
    }

    Write-Host "Connecting using Search-Only session..." -ForegroundColor Cyan

    try {
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -EnableSearchOnlySession -ErrorAction Stop
        Write-Host "Connected using Search-Only session." -ForegroundColor Green
        return "SearchOnly"
    }
    catch {
        Write-Host "Search-Only session failed. Falling back to full session..." -ForegroundColor Yellow
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
        Write-Host "Connected using full IPPSSession." -ForegroundColor Green
        return "Full"
    }
}

# --------------------------
# Show recent searches
# --------------------------
function Show-RecentComplianceSearches {
    try {
        Write-Host "`nTop 10 most recent compliance searches:" -ForegroundColor Cyan

        $searches = Get-ComplianceSearch |
            Sort-Object -Property CreatedTime -Descending |
            Select-Object -First 10 `
                @{Name='Name';Expression={$_.Name}},
                @{Name='CreatedTime_LocalTime';Expression={ $_.CreatedTime.ToLocalTime() }},
                @{Name='Status';Expression={$_.Status}},
                @{Name='Items';Expression={$_.Items}}

        if (-not $searches) {
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

# --------------------------
# Wait for search to reach Completed
# --------------------------
function Wait-ForSearchCompletion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName
    )

    Write-Host "`nEnsuring search '$SearchName' reaches 'Completed'..." -ForegroundColor Cyan

    for ($i = 1; $i -le 40; $i++) {
        $status = (Get-ComplianceSearch -Identity $SearchName).Status

        Write-Host "Status: $status (attempt $i/40)" -ForegroundColor Yellow

        if ($status -eq 'Completed') {
            Write-Host "Search is Completed." -ForegroundColor Green
            return $true
        }

        Start-Sleep -Seconds 5
    }

    Write-Host "Search never reached Completed. Cannot continue." -ForegroundColor Red
    return $false
}

# --------------------------
# Monitor purge action
# --------------------------
function Watch-PurgeAction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ActionIdentity
    )

    Write-Host "`nMonitoring purge action..." -ForegroundColor Cyan

    for ($i = 1; $i -le 30; $i++) {
        $action = Get-ComplianceSearchAction -Identity $ActionIdentity -ErrorAction SilentlyContinue

        if ($null -eq $action) {
            Write-Host "Action not found yet..." -ForegroundColor Yellow
        }
        else {
            Write-Host "Action status: $($action.Status)" -ForegroundColor Yellow

            if ($action.Status -eq 'Completed') {
                Write-Host "Purge action completed successfully." -ForegroundColor Green
                return
            }
        }

        Start-Sleep -Seconds 10
    }

    Write-Host "Purge action did not complete within expected time." -ForegroundColor Red
}

# --------------------------
# Execute purge with retry logic
# --------------------------
function Invoke-HardDeletePurge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName,
        [string]$SessionMode,
        [string]$UserPrincipalName
    )

    $retryPerformed = $false

PurgeAttempt:

    Write-Host "`n=== Purge Attempt (Session: $SessionMode) ===" -ForegroundColor Cyan

    # Validate search exists
    try {
        $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
    }
    catch {
        Write-Error "Search '$SearchName' not found: $($_.Exception.Message)"
        return
    }

    # Auto-start if NotStarted
    if ($search.Status -eq 'NotStarted') {
        Write-Host "`nSearch '$SearchName' is NotStarted." -ForegroundColor Yellow
        $startConfirm = Read-Host "Start the search now? (Y to start)"

        if ($startConfirm -match '^[Yy]$') {
            try {
                Write-Host "Starting search..." -ForegroundColor Cyan
                Start-ComplianceSearch -Identity $SearchName -ErrorAction Stop
                Write-Host "Search started." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to start search: $($_.Exception.Message)"
                return
            }
        }
        else {
            Write-Host "Search not started. Cannot continue." -ForegroundColor Red
            return
        }
    }

    # Ensure search reaches Completed
    if (-not (Wait-ForSearchCompletion -SearchName $SearchName)) {
        return
    }

    # Validate result count
    $search = Get-ComplianceSearch -Identity $SearchName
    if ($search.Items -eq 0) {
        Write-Warning "Search contains 0 items. Purge will not delete anything."
    }

    # Purge confirmation
    Write-Host "`nYou are about to run a HARD DELETE purge for '$SearchName'." -ForegroundColor Yellow
    Write-Host "This permanently deletes matching items (non-recoverable)." -ForegroundColor Yellow
    $confirm = Read-Host "Type 'YES' to confirm"

    if ($confirm -ne 'YES') {
        Write-Host "Cancelled." -ForegroundColor Cyan
        return
    }

    # Execute purge
    try {
        Write-Host "Submitting purge action..." -ForegroundColor Cyan
        $result = New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType HardDelete -ErrorAction Stop
        Write-Host "Purge action submitted." -ForegroundColor Green
        $result | Format-List

        Watch-PurgeAction -ActionIdentity $result.Identity
    }
    catch {
        $errorMessage = $_.Exception.Message

        # Detect session limitation errors
        if ($SessionMode -eq "SearchOnly" -and -not $retryPerformed -and
            ($errorMessage -match "not allowed in a Search-Only session" -or
             $errorMessage -match "not permitted in this session" -or
             $errorMessage -match "full compliance session")) {

            Write-Host "`n[Fallback] Purge failed due to Search-Only session limitations." -ForegroundColor Yellow
            Write-Host "Reconnecting using full IPPSSession and retrying purge..." -ForegroundColor Cyan

            Disconnect-ExchangeOnline -Confirm:$false
            Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop

            $SessionMode = "Full"
            $retryPerformed = $true
            goto PurgeAttempt
        }

        Write-Error "Purge failed: $errorMessage"
        throw
    }
}

# --------------------------
# Main Execution
# --------------------------
try {
    Import-ExchangeOnlineModule

    $upn = Read-Host "Enter UPN (e.g., user@domain.com)"
    if ([string]::IsNullOrWhiteSpace($upn)) { throw "UPN cannot be empty." }

    $sessionMode = Connect-SearchSession -UserPrincipalName $upn -ForceFullSession:$ForceFullSession

    Show-RecentComplianceSearches

    $searchName = Read-Host "Enter the Compliance Search Name/ID to purge"
    if ([string]::IsNullOrWhiteSpace($searchName)) { throw "Search Name/ID cannot be empty." }

    Invoke-HardDeletePurge -SearchName $searchName -SessionMode $sessionMode -UserPrincipalName $upn
}
catch { }
finally {
    $disconnect = Read-Host "Disconnect session now? (Y to disconnect)"
    if ($disconnect -match '^[Yy]$') {
        Disconnect-ExchangeOnline -Confirm:$false
        Write-Host "Disconnected." -ForegroundColor Green
    }
    else {
        Write-Host "Session remains connected." -ForegroundColor Yellow
    }
}