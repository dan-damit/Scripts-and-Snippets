
<#
.SYNOPSIS
Refactored Purview/Compliance PowerShell script to list, start, wait, and purge searches
— supports tenant-wide and eDiscovery case-scoped operations, with export and soft/hard delete.

.DESCRIPTION
- Connects to Security & Compliance PowerShell (IPPSSession) using ExchangeOnlineManagement module.
- Enumerates tenant-wide searches OR searches inside a specified eDiscovery case.
- Starts searches that are in "Created" state, waits for completion, then executes user-chosen action:
  * Export (evidence),
  * SoftDelete (recoverable),
  * HardDelete (permanent).
- Adds confirmations and clear status output.

.NOTES
Requires appropriate roles to run searches and purge (e.g., Organization Management, Compliance Management,
or role assignment that includes the Search and Purge capability). Also requires that the account is licensed
to access Purview eDiscovery (for case-scoped operations).
#>

# --------------------------
# Helper: Ensure ExchangeOnlineManagement module is available
# --------------------------
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

# --------------------------
# Connect to full IPPS session (NO Search-Only flag)
# --------------------------
function Connect-ComplianceSession {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    try {
        Write-Host "Connecting to Security & Compliance PowerShell..." -ForegroundColor Cyan
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
        Write-Host "Connected." -ForegroundColor Green
    }
    catch {
        Write-Error "Connection failed: $($_.Exception.Message)"
        throw
    }
}

# --------------------------
# List top N tenant-wide compliance searches
# --------------------------
function Show-RecentComplianceSearches {
    param(
        [int]$Top = 10
    )
    try {
        Write-Host "`nTop $Top most recent TENANT-WIDE compliance searches:" -ForegroundColor Cyan
        $searches = Get-ComplianceSearch |
            Sort-Object -Property CreatedTime -Descending |
            Select-Object -First $Top `
                @{Name='Name';Expression={$_.Name}},
                @{Name='Created_Local';Expression={ $_.CreatedTime.ToLocalTime() }},
                @{Name='Status';Expression={$_.Status}},
                @{Name='Items';Expression={$_.Items}}

        if (-not $searches -or $searches.Count -eq 0) {
            Write-Warning "No tenant-wide compliance searches found."
        } else {
            $searches | Format-Table -AutoSize
        }
    }
    catch {
        Write-Error "Failed to list tenant-wide searches: $($_.Exception.Message)"
        throw
    }
}

# --------------------------
# Case helpers: find a case and list its searches
# --------------------------
function Get-ComplianceCaseByName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CaseName
    )
    try {
        $case = Get-ComplianceCase | Where-Object { $_.Name -eq $CaseName -or $_.Identity -eq $CaseName }
        if (-not $case) { throw "Compliance case '$CaseName' not found." }
        return $case
    }
    catch {
        throw "Failed to retrieve compliance case '$CaseName': $($_.Exception.Message)"
    }
}

function Show-CaseComplianceSearches {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CaseName,
        [int]$Top = 15
    )
    try {
        Write-Host "`nTop $Top searches in case '$CaseName':" -ForegroundColor Cyan
        $searches = Get-ComplianceSearch -Case $CaseName |
            Sort-Object -Property CreatedTime -Descending |
            Select-Object -First $Top `
                @{Name='Name';Expression={$_.Name}},
                @{Name='Case';Expression={$_.Case}},
                @{Name='Created_Local';Expression={ $_.CreatedTime.ToLocalTime() }},
                @{Name='Status';Expression={$_.Status}},
                @{Name='Items';Expression={$_.Items}}

        if (-not $searches -or $searches.Count -eq 0) {
            Write-Warning "No searches found in case '$CaseName'."
        } else {
            $searches | Format-Table -AutoSize
        }
    }
    catch {
        Write-Error "Failed to list searches for case '$CaseName': $($_.Exception.Message)"
        throw
    }
}

# --------------------------
# Start search if needed (tenant-wide)
# --------------------------
function Start-ComplianceSearchIfNeeded {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName
    )
    try {
        $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
    }
    catch {
        throw "Compliance search '$SearchName' not found. Check the name/ID and try again."
    }

    Write-Host "Search '$SearchName' current status: $($search.Status)" -ForegroundColor Cyan

    switch ($search.Status) {
        'Created' {
            Write-Host "Search is created but not started. Starting now..." -ForegroundColor Yellow
            try {
                Start-ComplianceSearch -Identity $SearchName -ErrorAction Stop
                Write-Host "Start command issued." -ForegroundColor Green
            }
            catch {
                throw "Failed to start compliance search '$SearchName': $($_.Exception.Message)"
            }
        }
        'Starting' { Write-Host "Search is starting. Will wait for it to complete..." -ForegroundColor Yellow }
        'InProgress' { Write-Host "Search is already in progress. Will wait for it to complete..." -ForegroundColor Yellow }
        'Completed' { Write-Host "Search is already completed. Proceeding..." -ForegroundColor Green }
        default { Write-Warning "Search is in status '$($search.Status)'. Proceeding cautiously." }
    }
}

# --------------------------
# Start search if needed (case-scoped)
# --------------------------
function Start-CaseComplianceSearchIfNeeded {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName,
        [Parameter(Mandatory = $true)]
        [string]$CaseName
    )
    try {
        $search = Get-ComplianceSearch -Identity $SearchName -Case $CaseName -ErrorAction Stop
    }
    catch {
        throw "Search '$SearchName' not found in case '$CaseName'."
    }

    Write-Host "Search '$SearchName' (case '$CaseName') status: $($search.Status)" -ForegroundColor Cyan
    if ($search.Status -eq 'Created') {
        Write-Host "Starting search..." -ForegroundColor Yellow
        Start-ComplianceSearch -Identity $SearchName -Case $CaseName -ErrorAction Stop
        Write-Host "Start command issued." -ForegroundColor Green
    }
}

# --------------------------
# Wait for completion (tenant-wide)
# --------------------------
function Wait-ForComplianceSearchCompletion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName,
        [int]$PollSeconds = 10,
        [int]$TimeoutMinutes = 30
    )

    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    Write-Host "Waiting for search '$SearchName' to reach 'Completed'..." -ForegroundColor Cyan
    Write-Host "Polling every $PollSeconds seconds; timeout after $TimeoutMinutes minutes." -ForegroundColor Cyan

    while ((Get-Date) -lt $deadline) {
        try {
            $search = Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
        }
        catch {
            throw "Failed to retrieve search status for '$SearchName': $($_.Exception.Message)"
        }

        $status = $search.Status
        Write-Host ("[{0}] Status: {1}" -f (Get-Date).ToString("HH:mm:ss"), $status)

        if ($status -eq 'Completed') {
            Write-Host "Search completed." -ForegroundColor Green
            return
        }

        Start-Sleep -Seconds $PollSeconds
    }

    throw "Timed out waiting for search '$SearchName' to complete after $TimeoutMinutes minutes."
}

# --------------------------
# Wait for completion (case-scoped)
# --------------------------
function Wait-ForCaseComplianceSearchCompletion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName,
        [Parameter(Mandatory = $true)]
        [string]$CaseName,
        [int]$PollSeconds = 10,
        [int]$TimeoutMinutes = 30
    )

    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    Write-Host "Waiting for '$SearchName' in case '$CaseName' to reach 'Completed'..." -ForegroundColor Cyan
    Write-Host "Polling every $PollSeconds seconds; timeout after $TimeoutMinutes minutes." -ForegroundColor Cyan

    while ((Get-Date) -lt $deadline) {
        try {
            $search = Get-ComplianceSearch -Identity $SearchName -Case $CaseName -ErrorAction Stop
        }
        catch {
            throw "Failed to retrieve search status for '$SearchName' (case '$CaseName'): $($_.Exception.Message)"
        }

        $status = $search.Status
        Write-Host ("[{0}] Status: {1}" -f (Get-Date).ToString("HH:mm:ss"), $status)

        if ($status -eq 'Completed') {
            Write-Host "Search completed." -ForegroundColor Green
            return
        }

        Start-Sleep -Seconds $PollSeconds
    }

    throw "Timed out waiting for '$SearchName' (case '$CaseName') to complete after $TimeoutMinutes minutes."
}

# --------------------------
# Action: Export (tenant or case)
# --------------------------
function Invoke-ComplianceExport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName,
        [string]$CaseName
    )
    try {
        Write-Host "Submitting Export action for search '$SearchName' $(
            if ($CaseName) { "in case '$CaseName'" } else { "(tenant-wide)" }
        )..." -ForegroundColor Cyan

        if ($CaseName) {
            $result = New-ComplianceSearchAction -SearchName $SearchName -Case $CaseName -Export -ErrorAction Stop
        } else {
            $result = New-ComplianceSearchAction -SearchName $SearchName -Export -ErrorAction Stop
        }

        Write-Host "Export action submitted." -ForegroundColor Green
        $result | Format-List
    }
    catch {
        Write-Error "Export action failed: $($_.Exception.Message)"
        throw
    }
}

# --------------------------
# Action: Purge (Soft/Hard; tenant or case)
# --------------------------
function Invoke-CompliancePurge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName,
        [ValidateSet('SoftDelete','HardDelete')]
        [string]$PurgeType,
        [string]$CaseName
    )

    Write-Host "`nYou are about to run a **$PurgeType purge** for search: '$SearchName' $(
        if ($CaseName) { "in case '$CaseName'" } else { "(tenant-wide)" }
    )." -ForegroundColor Yellow
    if ($PurgeType -eq 'HardDelete') {
        Write-Host "This action permanently deletes matching items (non-recoverable)." -ForegroundColor Red
    } else {
        Write-Host "This action moves items to Recoverable Items (soft delete)." -ForegroundColor Yellow
    }
    $confirm = Read-Host "Type 'YES' to confirm, or anything else to cancel"

    if ($confirm -ne 'YES') {
        Write-Host "Cancelled. No purge was performed." -ForegroundColor Cyan
        return
    }

    try {
        Write-Host "Submitting purge action..." -ForegroundColor Cyan
        if ($CaseName) {
            $result = New-ComplianceSearchAction -SearchName $SearchName -Case $CaseName -Purge -PurgeType $PurgeType -ErrorAction Stop
        } else {
            $result = New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType $PurgeType -ErrorAction Stop
        }

        Write-Host "Purge action submitted successfully." -ForegroundColor Green
        $result | Format-List
    }
    catch {
        Write-Error "Purge action failed: $($_.Exception.Message)"
        throw
    }
}

# --------------------------
# Optional: Create a search (tenant or case) — handy if not created yet
# --------------------------
function New-OptionalComplianceSearch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchName,
        [Parameter(Mandatory = $true)]
        [string]$ContentMatchQuery,
        [string[]]$ExchangeLocations = @('All'),
        [string]$CaseName
    )

    try {
        Write-Host "Creating search '$SearchName' $(
            if ($CaseName) { "in case '$CaseName'" } else { "(tenant-wide)" }
        )..." -ForegroundColor Cyan

        if ($CaseName) {
            New-ComplianceSearch -Name $SearchName -Case $CaseName `
                -ExchangeLocation $ExchangeLocations `
                -ContentMatchQuery $ContentMatchQuery `
                -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        } else {
            New-ComplianceSearch -Name $SearchName `
                -ExchangeLocation $ExchangeLocations `
                -ContentMatchQuery $ContentMatchQuery `
                -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        }

        Write-Host "Search created." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create search '$SearchName': $($_.Exception.Message)"
        throw
    }
}

# --------------------------
# Main script execution flow
# --------------------------
try {
    # 1) Import module
    Import-ExchangeOnlineModule

    # 1.1) Prompt for UPN
    $upn = Read-Host "Enter UPN (e.g., username@companydomain.com)"
    if ([string]::IsNullOrWhiteSpace($upn)) {
        throw "UPN cannot be empty."
    }

    # 2) Connect to full Compliance session (required for purge/export)
    Connect-ComplianceSession -UserPrincipalName $upn

    # 3) Choose scope: Tenant-wide or Case-scoped
    Write-Host "`nChoose scope:" -ForegroundColor Cyan
    Write-Host "  1) Tenant-wide (Compliance searches not in a case)"
    Write-Host "  2) eDiscovery Case-scoped"
    $scopeChoice = Read-Host "Enter 1 or 2"
    if ($scopeChoice -notin @('1','2')) { throw "Invalid scope selection." }

    $caseName = $null
    if ($scopeChoice -eq '1') {
        # TENANT-WIDE
        Show-RecentComplianceSearches -Top 10

        $searchName = Read-Host "Enter the Compliance Search Name/ID to start and act on"
        if ([string]::IsNullOrWhiteSpace($searchName)) { throw "Search Name/ID cannot be empty." }

        Start-ComplianceSearchIfNeeded -SearchName $searchName
        Wait-ForComplianceSearchCompletion -SearchName $searchName -PollSeconds 10 -TimeoutMinutes 30
    }
    else {
        # CASE-SCOPED
        $caseName = Read-Host "Enter the eDiscovery Case Name/ID (e.g., INC-128959)"
        if ([string]::IsNullOrWhiteSpace($caseName)) { throw "Case cannot be empty." }
        # Validate case exists
        $case = Get-ComplianceCaseByName -CaseName $caseName

        Show-CaseComplianceSearches -CaseName $caseName -Top 15

        $searchName = Read-Host "Enter the Compliance Search Name/ID (inside case '$caseName')"
        if ([string]::IsNullOrWhiteSpace($searchName)) { throw "Search Name/ID cannot be empty." }

        Start-CaseComplianceSearchIfNeeded -SearchName $searchName -CaseName $caseName
        Wait-ForCaseComplianceSearchCompletion -SearchName $searchName -CaseName $caseName -PollSeconds 10 -TimeoutMinutes 30
    }

    # 4) Choose action: Export, SoftDelete, HardDelete
    Write-Host "`nChoose action for search '$searchName' $(
        if ($caseName) { "in case '$caseName'" } else { "(tenant-wide)" }
    ):" -ForegroundColor Cyan
    Write-Host "  1) Export (evidence)"
    Write-Host "  2) Purge - SoftDelete (recoverable)"
    Write-Host "  3) Purge - HardDelete (permanent)"
    $actionChoice = Read-Host "Enter 1, 2 or 3"

    switch ($actionChoice) {
        '1' { Invoke-ComplianceExport -SearchName $searchName -CaseName $caseName }
        '2' { Invoke-CompliancePurge -SearchName $searchName -PurgeType SoftDelete -CaseName $caseName }
        '3' { Invoke-CompliancePurge -SearchName $searchName -PurgeType HardDelete -CaseName $caseName }
        default { throw "Invalid action selection." }
    }
}
catch {
    # Let functions print detailed errors; provide a simple final note here
    Write-Host "`nScript terminated due to an error. See messages above for details." -ForegroundColor Red
}
finally {
    # Optional: Disconnect session
    $disconnectSession = Read-Host "`nDo you want to disconnect the session now? (Y to disconnect, any other key to keep connected)"
    if ($disconnectSession -eq 'Y' -or $disconnectSession -eq 'y') {
        Disconnect-ExchangeOnline -Confirm:$false
        Write-Host "Disconnected from Exchange Online." -ForegroundColor Green
    } else {
        Write-Host "Session remains connected." -ForegroundColor Yellow
    }
}
