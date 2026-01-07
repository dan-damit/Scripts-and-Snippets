
# =====================================================================
# Main script: Purge-ComplianceSearch.ps1
# Purpose: Orchestrates user input and flow; uses PurviewTools module.
# =====================================================================
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Import the module from relative path (adjust if installed it system-wide)
$modulePath = Join-Path $PSScriptRoot '..\PurviewTools.psm1'
Import-Module $modulePath -Force

# Configure log file
$logFile = Join-Path $env:TEMP ("PurviewPurgeLog_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Write-Host "[Log] Actions will be logged to: $logFile" -ForegroundColor Cyan

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
    }
    else {
        Write-Log "Session remains connected."
    }
}