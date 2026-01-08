
# =====================================================================
# Main script: Purge-ComplianceSearch.ps1
# Purpose: Orchestrates user input and flow; uses PurviewTools module.

# Follow prompts:
# - UPN
# - Case name
# - (optional) original search to clone or new KQL

# The script will:
#   1) Connect with EnableSearchOnlySession (good for purge)  [3](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/new-compliancesearchaction?view=exchange-ps)[4](https://techcommunity.microsoft.com/blog/microsoft-security-blog/search-and-purge-using-the-security-and-compliance-powershell-cmdlets/4429472)
#   2) Create/clone a mailbox-only search inside the case
#   3) Wait until Status=Completed and Items>0
#   4) Submit HardDelete purge action
#   5) Monitor to completion

# =====================================================================
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Import the module from relative path (adjust if installed it system-wide)
$modulePath = Join-Path $PSScriptRoot '..\PurviewTools.psm1'
Import-Module $modulePath -Force

# Configure log file
$logFile = Join-Path $env:TEMP ("PurviewPurgeLog_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Set-LogFile -Path $logFile
Write-Log "[Log] Actions will be logged to: $logFile"

try {
    Write-Host "[Info] ExchangeOnlineManagement module version: $((Get-Module ExchangeOnlineManagement).Version)" -ForegroundColor Cyan
    Import-ExchangeOnlineModule
    $upn = Read-Host "Enter UPN (e.g., user@domain.com)"
    Connect-SearchSession -UserPrincipalName $upn

    $caseName = Read-Host "Enter eDiscovery Case Name/ID"
    $searchName = Read-Host "Enter original Compliance Search Name/ID in case '$caseName' (or press Enter to create new)"

    $cloneName = Resolve-OrCreateSearch -CaseName $caseName -OriginalSearchName $searchName

    $searchObj = Wait-ForSearchCompletion -SearchName $cloneName -CaseName $caseName
    if ($searchObj.Items -le 0) { throw "Search returned 0 mailbox items. Purge aborted." }

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
