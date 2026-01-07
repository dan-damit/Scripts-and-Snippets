
# =====================================================================
# Module: PurviewTools
# Purpose: Helpers for Purview Compliance Search and Purge operations
# Author : Dan Damit (https://github.com/dan-damit)

# Moved from initial script to module on 2026.1.2
# In-line comments are in the ORIGINAL_SCRIPT.ps1 file.

# Refactored version date: 2026.01.07
# Version: 1.1.0
# Only requires a eDiscover case to be created and a Search generated.
# All searches and purges will be case-scoped and handled withing the script now.
# =====================================================================
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry = "[{0}] {1}" -f $timestamp, $Message
    Add-Content -Path $logFile -Value $entry
    Write-Host $Message
}

function Import-ExchangeOnlineModule {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
        Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
}

function Connect-SearchSession {
    param([Parameter(Mandatory = $true)][string]$UserPrincipalName)
    Write-Host "Connecting using Search-Only session..." -ForegroundColor Cyan
    Connect-IPPSSession -UserPrincipalName $UserPrincipalName -EnableSearchOnlySession -ErrorAction Stop
    Write-Host "Connected." -ForegroundColor Green
}

function Update-ResolveOrCreateSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CaseName,
        [Parameter(Mandatory = $false)][string]$OriginalSearchName
    )

    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'

    if ([string]::IsNullOrWhiteSpace($OriginalSearchName)) {
        Write-Log "[Info] No search name provided. Prompting for KQL query..."
        $customQuery = Read-Host "Enter KQL query (e.g., from:\"someone@domain.com\" AND subject:\"confidential\")"
        if ([string]::IsNullOrWhiteSpace($customQuery)) { throw "Custom query cannot be empty." }

        $newSearchName = "CustomMailboxSearch-$timestamp"
        Write-Log "[Custom] Creating mailbox-only search '$newSearchName' with custom query..."
        New-ComplianceSearch -Name $newSearchName -Case $CaseName `
            -ExchangeLocation All `
            -ContentMatchQuery $customQuery `
            -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $newSearchName
        return $newSearchName
    }

    try {
        Get-ComplianceSearch -Identity $OriginalSearchName -Case $CaseName -ErrorAction Stop | Out-Null
        Write-Log "[Info] Found existing search '$OriginalSearchName'. Cloning mailbox-only version..."
        $cloneName = "$OriginalSearchName-MailboxOnly-$timestamp"
        $cloneName = New-MailboxOnlySearch -CaseName $CaseName -OriginalSearchName $OriginalSearchName
        return $cloneName
    }
    catch {
        Write-Log "[Warning] Search '$OriginalSearchName' not found. Prompting for KQL query..."
        $customQuery = Read-Host "Enter KQL query"
        if ([string]::IsNullOrWhiteSpace($customQuery)) { throw "Custom query cannot be empty." }

        $newSearchName = "CustomMailboxSearch-$timestamp"
        Write-Log "[Custom] Creating mailbox-only search '$newSearchName' with custom query..."
        New-ComplianceSearch -Name $newSearchName -Case $CaseName `
            -ExchangeLocation All `
            -ContentMatchQuery $customQuery `
            -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $newSearchName
        return $newSearchName
    }
}

function Get-SearchDetails {
    param([string]$SearchName, [string]$CaseName)
    Get-ComplianceSearch -Identity $SearchName -Case $CaseName -ErrorAction Stop
}

function Wait-ForSearchCompletion {
    param([string]$SearchName, [string]$CaseName, [int]$MaxAttempts = 40, [int]$DelaySec = 10)
    Write-Host "[Wait] Waiting for search '$SearchName' to reach Completed..." -ForegroundColor Cyan
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        $s = Get-ComplianceSearch -Identity $SearchName -Case $CaseName
        Write-Host ("Status: {0} (attempt {1}/{2})" -f $s.Status, $i, $MaxAttempts) -ForegroundColor Yellow
        if ($s.Status -eq 'Completed') {
            Write-Host "Search Completed." -ForegroundColor Green
            return $s
        }
        Start-Sleep -Seconds $DelaySec
    }
    throw "Search did not complete in time."
}

function New-MailboxOnlySearch {
    param([string]$CaseName, [string]$OriginalSearchName, [string]$NewSearchName)
    $orig = Get-SearchDetails -SearchName $OriginalSearchName -CaseName $CaseName
    $query = $orig.ContentMatchQuery
    if ([string]::IsNullOrWhiteSpace($query)) { throw "Original search has no query." }
    Write-Host "[Clone] Creating mailbox-only search '$NewSearchName'..." -ForegroundColor Cyan
    New-ComplianceSearch -Name $NewSearchName -Case $CaseName `
        -ExchangeLocation All `
        -ContentMatchQuery $query `
        -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
    Start-ComplianceSearch -Identity $NewSearchName
    return $NewSearchName
}

function Invoke-HardDelete {
    param([string]$SearchName, [string]$CaseName)
    $confirm = Read-Host "Type 'YES' to confirm HardDelete purge"
    if ($confirm -ne 'YES') { throw "Cancelled by user." }
    Write-Host "[Purge] Submitting HardDelete..." -ForegroundColor Cyan
    $action = New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType HardDelete -Case $CaseName
    Write-Host "[Purge] Submitted: $($action.Identity)" -ForegroundColor Green
    Wait-ForPurgeCompletion -SearchName $SearchName -CaseName $CaseName
}

function Wait-ForPurgeCompletion {
    param([string]$SearchName, [string]$CaseName, [int]$TimeoutSeconds = 900, [int]$PollSeconds = 5)
    Write-Host "[Watch] Monitoring purge action for '$SearchName'..." -ForegroundColor Cyan
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $action = Get-ComplianceSearchAction -SearchName $SearchName -Case $CaseName -ErrorAction SilentlyContinue |
        Where-Object { $_.Action -eq 'Purge' } |
        Sort-Object CreatedTime -Descending |
        Select-Object -First 1
        if ($action) {
            Write-Host ("[Watch] Status={0}, Progress={1}" -f $action.Status, $action.Progress) -ForegroundColor Yellow
            switch ($action.Status) {
                'Completed' { Write-Host "[Purge] Completed successfully." -ForegroundColor Green; return }
                'Failed' { Write-Host "[Purge] Failed: $($action.ErrorMessage)" -ForegroundColor Red; return }
            }
        }
        else {
            Write-Host "[Watch] No purge action found yet..." -ForegroundColor DarkYellow
        }
        Start-Sleep -Seconds $PollSeconds
    }
    Write-Host "[Purge] Timed out waiting for completion." -ForegroundColor Red
}

Export-ModuleMember -Function `
    Import-ExchangeOnlineModule, `
    Connect-SearchSession, `
    Get-SearchDetails, `
    Wait-ForSearchCompletion, `
    New-MailboxOnlySearch, `
    Invoke-HardDelete, `
    Wait-ForPurgeCompletion, `
    Update-ResolveOrCreateSearch, `
    Write-Log
# End of PurviewTools.psm1