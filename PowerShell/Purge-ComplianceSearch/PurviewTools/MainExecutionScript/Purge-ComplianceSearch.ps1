
# =====================================================================
# Main script: Purge-ComplianceSearch.ps1
# Purpose: Orchestrates user input and flow; uses PurviewTools module.
# =====================================================================
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Import the module from relative path (adjust if installed it system-wide)
$modulePath = Join-Path $PSScriptRoot '..\PurviewTools\PurviewTools.psd1'
Import-Module $modulePath -Force

try {
    Import-ExchangeOnlineModule
    $upn = Read-Host "Enter UPN (e.g., user@domain.com)"
    if ([string]::IsNullOrWhiteSpace($upn)) { throw "UPN cannot be empty." }

    $sessionMode = Connect-SearchSession -UserPrincipalName $upn

    Write-Host "`nChoose scope:" -ForegroundColor Cyan
    Write-Host " 1) Tenant-wide (Compliance searches not in a case)"
    Write-Host " 2) eDiscovery Case-scoped"
    $scopeChoice = Read-Host "Enter 1 or 2"
    if ($scopeChoice -notin @('1','2')) { throw "Invalid scope selection." }

    $caseName = $null
    if ($scopeChoice -eq '1') {
        # Tenant-wide path
        Show-RecentComplianceSearches -Top 10
        $searchName = Read-Host "Enter the Compliance Search Name/ID (tenant-wide)"
        if ([string]::IsNullOrWhiteSpace($searchName)) { throw "Search Name/ID cannot be empty." }

        $searchObj = Get-SearchDetails -SearchName $searchName -CaseName $null
        $hasNonMailbox = Test-HasNonMailboxWorkloads -SearchObj $searchObj
        if ($hasNonMailbox) {
            Write-Warning "This search includes SharePoint/OneDrive sources. Purge supports Exchange mailboxes only."
            $cloneName = Read-Host "Create mailbox-only clone? Enter new search name (or press Enter to skip)"
            if (-not [string]::IsNullOrWhiteSpace($cloneName)) {
                try {
                    Get-ComplianceSearch -Identity $cloneName -ErrorAction Stop | Out-Null
                    Write-Warning "Search '$cloneName' already exists. Appending timestamp."
                    $cloneName = '{0}-{1}' -f $cloneName, (Get-Date -Format 'yyyyMMddHHmmss')
                } catch { }
                $cloneParams = @{ OriginalSearchName = $searchName; NewSearchName = $cloneName; CaseName = $null }
                $searchName = New-MailboxOnlyClone @cloneParams
            }
        }
        $searchName = ([string]$searchName).Trim()
        Invoke-GuidedPurge -SearchName $searchName -CaseName $caseName -SessionMode $sessionMode -UserPrincipalName $upn
    }
    else {
        # Case-scoped path
        $caseName = Read-Host "Enter the eDiscovery Case Name/ID (e.g., #INC-128959)"
        if ([string]::IsNullOrWhiteSpace($caseName)) { throw "Case cannot be empty." }
        Get-ComplianceCaseByName -CaseName $caseName | Out-Null
        Show-CaseComplianceSearches -CaseName $caseName -Top 15
        $searchName = Read-Host "Enter the Compliance Search Name/ID (inside case '$caseName')"
        if ([string]::IsNullOrWhiteSpace($searchName)) { throw "Search Name/ID cannot be empty." }
        $searchObj = Get-SearchDetails -SearchName $searchName -CaseName $caseName
        $hasNonMailbox = Test-HasNonMailboxWorkloads -SearchObj $searchObj
        if ($hasNonMailbox) {
            Write-Warning "This case search includes SharePoint/OneDrive sources. Purge supports Exchange mailboxes only."
            $cloneName = Read-Host "Create mailbox-only clone in this case? Enter new search name (or press Enter to skip)"
            if (-not [string]::IsNullOrWhiteSpace($cloneName)) {
                try {
                    Get-ComplianceSearch -Identity $cloneName -Case $caseName -ErrorAction Stop | Out-Null
                    Write-Warning "Search '$cloneName' already exists. Appending timestamp."
                    $cloneName = '{0}-{1}' -f $cloneName, (Get-Date -Format 'yyyyMMddHHmmss')
                } catch { }
                $cloneParams = @{ OriginalSearchName = $searchName; NewSearchName = $cloneName; CaseName = $caseName }
                $searchName = New-MailboxOnlyClone @cloneParams
            }
        }
        $searchName = ([string]$searchName).Trim()
        Invoke-GuidedPurge -SearchName $searchName -CaseName $caseName -SessionMode $sessionMode -UserPrincipalName $upn
    }
}
catch {
    Write-Host "`n[ERROR] $($_.Exception.GetType().FullName): $($_.Exception.Message)" -ForegroundColor Red
    if ($_.InvocationInfo) {
        Write-Host ("At {0}:{1}" -f $_.InvocationInfo.ScriptName, $_.InvocationInfo.ScriptLineNumber) -ForegroundColor DarkRed
        Write-Host "Line: $($_.InvocationInfo.Line.Trim())" -ForegroundColor DarkRed
    }
}
finally {
    $disconnect = Read-Host "`nDisconnect session now? (Y to disconnect)"
    if ($disconnect -match '^[Yy]$') {
        Disconnect-ExchangeOnline -Confirm:$false
        Write-Host "Disconnected." -ForegroundColor Green
    } else {
        Write-Host "Session remains connected." -ForegroundColor Yellow
    }
}
