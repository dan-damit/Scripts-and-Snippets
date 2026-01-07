
# ============================================================
# Purview Compliance Search Purge (Case-scoped, HardDelete only)
# Author: Dan.Damit (https://github.com/dan-damit)

# Refactored for mailbox-only purge workflow
# Added timestamped search clones to avoid name conflicts
# Added logging to temp file

# Usage:
#   1) Start an eDiscovery Case in Purview
#   2) Reference that case number in the Script during runtime
#   3) Script will then run a mailbox-only search
#   4) Wait for search completion
#   5) Submit HardDelete purge and monitor until completion
# ============================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Configure log file
$logFile = Join-Path $env:TEMP ("PurviewPurgeLog_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Write-Host "[Log] Actions will be logged to: $logFile" -ForegroundColor Cyan

function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry = "[{0}] {1}" -f $timestamp, $Message
    Add-Content -Path $logFile -Value $entry
    Write-Host $Message
}

function Import-ExchangeOnlineModule {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Log "Installing ExchangeOnlineManagement module..."
        Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    Write-Log "ExchangeOnlineManagement module imported."
}

function Connect-SearchSession {
    param([Parameter(Mandatory=$true)][string]$UserPrincipalName)
    Write-Log "Connecting using Search-Only session..."
    Connect-IPPSSession -UserPrincipalName $UserPrincipalName -EnableSearchOnlySession -ErrorAction Stop
    Write-Log "Connected successfully."
}

function Get-SearchDetails {
    param([string]$SearchName,[string]$CaseName)
    Get-ComplianceSearch -Identity $SearchName -Case $CaseName -ErrorAction Stop
}

function Wait-ForSearchCompletion {
    param([string]$SearchName,[string]$CaseName,[int]$MaxAttempts=40,[int]$DelaySec=10)
    Write-Log "[Wait] Waiting for search '$SearchName' to reach Completed..."
    for ($i=1;$i -le $MaxAttempts;$i++) {
        $s = Get-ComplianceSearch -Identity $SearchName -Case $CaseName
        Write-Log ("Status: {0} (attempt {1}/{2})" -f $s.Status,$i,$MaxAttempts)
        if ($s.Status -eq 'Completed') {
            Write-Log "Search Completed."
            return $s
        }
        Start-Sleep -Seconds $DelaySec
    }
    throw "Search did not complete in time."
}

function New-MailboxOnlySearch {
    param([string]$CaseName,[string]$OriginalSearchName)
    $orig = Get-SearchDetails -SearchName $OriginalSearchName -CaseName $CaseName
    $query = $orig.ContentMatchQuery
    if ([string]::IsNullOrWhiteSpace($query)) { throw "Original search has no query." }
    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
    $newSearchName = "$OriginalSearchName-MailboxOnly-$timestamp"
    Write-Log "[Clone] Creating mailbox-only search '$newSearchName'..."
    New-ComplianceSearch -Name $newSearchName -Case $CaseName `
        -ExchangeLocation All `
        -ContentMatchQuery $query `
        -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
    Start-ComplianceSearch -Identity $newSearchName
    Write-Log "[Clone] Search started."
    return $newSearchName
}

function Invoke-HardDelete {
    param([string]$SearchName,[string]$CaseName)
    $confirm = Read-Host "Type 'YES' to confirm HardDelete purge"
    if ($confirm -ne 'YES') { throw "Cancelled by user." }
    Write-Log "[Purge] Submitting HardDelete..."
    $action = New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType HardDelete -Case $CaseName
    Write-Log "[Purge] Submitted: $($action.Identity)"
    Wait-ForPurgeCompletion -SearchName $SearchName -CaseName $CaseName
}

function Wait-ForPurgeCompletion {
    param([string]$SearchName,[string]$CaseName,[int]$TimeoutSeconds=900,[int]$PollSeconds=5)
    Write-Log "[Watch] Monitoring purge action for '$SearchName'..."
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $action = Get-ComplianceSearchAction -SearchName $SearchName -Case $CaseName -ErrorAction SilentlyContinue |
                  Where-Object { $_.Action -eq 'Purge' } |
                  Sort-Object CreatedTime -Descending |
                  Select-Object -First 1
        if ($action) {
            Write-Log ("[Watch] Status={0}, Progress={1}" -f $action.Status,$action.Progress)
            switch ($action.Status) {
                'Completed' { Write-Log "[Purge] Completed successfully."; return }
                'Failed'    { Write-Log "[Purge] Failed: $($action.ErrorMessage)"; return }
            }
        } else {
            Write-Log "[Watch] No purge action found yet..."
        }
        Start-Sleep -Seconds $PollSeconds
    }
    Write-Log "[Purge] Timed out waiting for completion."
}

# ---------------- MAIN ----------------
try {
    Import-ExchangeOnlineModule
    $upn = Read-Host "Enter UPN (e.g., user@domain.com)"
    Connect-SearchSession -UserPrincipalName $upn

    $caseName = Read-Host "Enter eDiscovery Case Name/ID"
    $searchName = Read-Host "Enter original Compliance Search Name/ID in case '$caseName'"

    # Create mailbox-only search with timestamp
    $cloneName = New-MailboxOnlySearch -CaseName $caseName -OriginalSearchName $searchName

    # Wait for completion
    $searchObj = Wait-ForSearchCompletion -SearchName $cloneName -CaseName $caseName
    if ($searchObj.Items -le 0) { throw "Search returned 0 mailbox items. Purge aborted." }

    # Purge HardDelete with watcher
    Invoke-HardDelete -SearchName $cloneName -CaseName $caseName

    Write-Log "[Done] All actions completed. Log saved to $logFile"
}
catch {
    Write-Log "[ERROR] $($_.Exception.Message)"
}
finally {
    $disconnect = Read-Host "Disconnect session now? (Y/N)"
    if ($disconnect -match '^[Yy]$') {
        Disconnect-ExchangeOnline -Confirm:$false
        Write-Log "Disconnected."
    } else {
        Write-Log "Session remains connected."
    }
}
