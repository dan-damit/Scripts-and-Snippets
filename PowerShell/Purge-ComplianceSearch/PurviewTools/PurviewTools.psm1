
# =====================================================================
# Module: PurviewTools
# Purpose: Helpers for Purview Compliance Search: listing, cloning,
#          waiting, and guided purge actions.
# Author : Dan Damit (https://github.com/dan-damit)
# Moved from initial script to module on 2026.1.2
# =====================================================================
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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

function Connect-SearchSession {
    [CmdletBinding()] param([Parameter(Mandatory = $true)][string]$UserPrincipalName)
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

function Show-RecentComplianceSearches {
    [CmdletBinding()] param([int]$Top = 10)
    Write-Host "`nTop $Top most recent TENANT-WIDE compliance searches:" -ForegroundColor Cyan
    $searches = Get-ComplianceSearch |
    Sort-Object -Property CreatedTime -Descending |
    Select-Object -First $Top `
        Name, Status,
    @{ N = 'Items'; E = { if ($_.PSObject.Properties['ItemsFound'] -and $null -ne $_.ItemsFound) { $_.ItemsFound } else { $_.Items } } },
    @{ N = 'Created_Local'; E = { $_.CreatedTime.ToLocalTime() } }
    if (-not $searches) { Write-Warning "No tenant-wide searches." } else { $searches | Format-Table -AutoSize }
}

function Get-ComplianceCaseByName {
    [CmdletBinding()] param([Parameter(Mandatory = $true)][string]$CaseName)
    $case = Get-ComplianceCase | Where-Object { $_.Name -eq $CaseName -or $_.Identity -eq $CaseName }
    if (-not $case) { throw "Compliance case '$CaseName' not found." }
    return $case
}

function Show-CaseComplianceSearches {
    [CmdletBinding()] param([Parameter(Mandatory = $true)][string]$CaseName, [int]$Top = 15)
    Write-Host "`nTop $Top searches in case '$CaseName':" -ForegroundColor Cyan
    $searches = Get-ComplianceSearch -Case $CaseName |
    Sort-Object -Property CreatedTime -Descending |
    Select-Object -First $Top `
        Name, Status,
    @{ N = 'Items'; E = { if ($_.PSObject.Properties['ItemsFound'] -and $null -ne $_.ItemsFound) { $_.ItemsFound } else { $_.Items } } },
    @{ N = 'Created_Local'; E = { $_.CreatedTime.ToLocalTime() } }
    if (-not $searches) { Write-Warning "No searches in case '$CaseName'." } else { $searches | Format-Table -AutoSize }
}

function Get-SearchDetails {
    [CmdletBinding()] param([Parameter(Mandatory = $true)][string]$SearchName, [string]$CaseName)
    if ([string]::IsNullOrWhiteSpace($CaseName)) {
        return Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
    }
    else {
        return Get-ComplianceSearch -Identity $SearchName -Case $CaseName -ErrorAction Stop
    }
}

function Test-HasNonMailboxWorkloads {
    [CmdletBinding()] param([Parameter(Mandatory = $true)]$SearchObj)
    $hasSP = $false
    $hasOD = $false
    $spProps = @('SharePointLocation', 'SharePointLocationExclusion')
    $odProps = @('OneDriveLocation', 'OneDriveLocationExclusion')
    foreach ($p in $spProps) { if ($SearchObj.PSObject.Properties[$p] -and $SearchObj.$p) { $hasSP = $true } }
    foreach ($p in $odProps) { if ($SearchObj.PSObject.Properties[$p] -and $SearchObj.$p) { $hasOD = $true } }
    return ($hasSP -or $hasOD)
}

function Get-MailboxSourcesFromSearch {
    [CmdletBinding()] param([Parameter(Mandatory = $true)]$SearchObj)
    if ($SearchObj.PSObject.Properties['ExchangeLocation'] -and $SearchObj.ExchangeLocation) {
        return $SearchObj.ExchangeLocation
    }
    else {
        return @('All')
    }
}

function Wait-ForSearchCompletion {
    [CmdletBinding()] param([Parameter(Mandatory = $true)][string]$SearchName, [string]$CaseName)
    Write-Host "[Wait] Ensuring search '$SearchName' reaches 'Completed'..." -ForegroundColor Cyan
    for ($i = 1; $i -le 40; $i++) {
        $s = Get-SearchDetails -SearchName $SearchName -CaseName $CaseName
        Write-Host ("Status: {0} (attempt {1}/40)" -f $s.Status, $i) -ForegroundColor Yellow
        if ($s.Status -eq 'Completed') { Write-Host "Search is Completed." -ForegroundColor Green; return $true }
        Start-Sleep 5
    }
    Write-Host "Search never reached Completed. Cannot continue." -ForegroundColor Red
    return $false
}

function New-MailboxOnlyClone {
    [CmdletBinding()] param(
        [Parameter(Mandatory = $true)][string]$OriginalSearchName,
        [string]$CaseName,
        [Parameter(Mandatory = $true)][string]$NewSearchName
    )
    Write-Host ("[Clone] Creating mailbox-only search '{0}' from '{1}'..." -f $NewSearchName, $OriginalSearchName) -ForegroundColor Cyan
    $orig = Get-SearchDetails -SearchName $OriginalSearchName -CaseName $CaseName
    $query = $orig.PSObject.Properties['ContentMatchQuery'] ? $orig.ContentMatchQuery : $null
    $mailboxes = Get-MailboxSourcesFromSearch -SearchObj $orig
    if ([string]::IsNullOrWhiteSpace($query)) {
        Write-Warning "[Clone] Original search has no ContentMatchQuery; you'll be prompted to confirm."
        $query = Read-Host "Enter ContentMatchQuery (KQL)"
        if ([string]::IsNullOrWhiteSpace($query)) { throw "[Clone] ContentMatchQuery is required." }
    }
    if ([string]::IsNullOrWhiteSpace($CaseName)) {
        New-ComplianceSearch -Name $NewSearchName `
            -ExchangeLocation $mailboxes `
            -ContentMatchQuery $query `
            -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
    }
    else {
        New-ComplianceSearch -Name $NewSearchName -Case $CaseName `
            -ExchangeLocation $mailboxes `
            -ContentMatchQuery $query `
            -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
    }
    Write-Host "[Clone] Search created." -ForegroundColor Green
    Start-ComplianceSearch -Identity $NewSearchName -ErrorAction Stop
    Write-Host "[Clone] Start issued. Waiting for completion..." -ForegroundColor Yellow
    Wait-ForSearchCompletion -SearchName $NewSearchName -CaseName $CaseName | Out-Null
    $s = Get-SearchDetails -SearchName $NewSearchName -CaseName $CaseName
    $count = $s.PSObject.Properties['ItemsFound'] ? $s.ItemsFound : $s.Items
    Write-Host ("[Clone] Completed. Items={0}" -f $count) -ForegroundColor Green
    return [string]$NewSearchName
}

function Wait-ForPurgeCompletion {
    [CmdletBinding()] param(
        [Parameter(Mandatory = $true)][string]$SearchName,
        [string]$CaseName,
        [int]$TimeoutSeconds = 600,
        [int]$PollSeconds = 5,
        [switch]$VerboseLog
    )
    $expectedPrefix = "{0}_Purge" -f $SearchName
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $attempt = 0
    [bool]$seenAny = $false
    while ((Get-Date) -lt $deadline) {
        $attempt++
        try {
            $actions = if ([string]::IsNullOrWhiteSpace($CaseName)) {
                Get-ComplianceSearchAction -SearchName $SearchName -ErrorAction SilentlyContinue
            }
            else {
                Get-ComplianceSearchAction -SearchName $SearchName -ErrorAction SilentlyContinue
            }
            if ($actions) {
                if (-not $seenAny) { $seenAny = $true; if ($VerboseLog) { Write-Host "[Watch] Actions have appeared for this search." -ForegroundColor Cyan } }
                $purgeAction = $actions |
                Where-Object { $_.PSObject.Properties['Action'] -and $_.Action -eq 'Purge' -and $_.PSObject.Properties['Identity'] -and $_.Identity -like "$expectedPrefix*" } |
                Sort-Object -Property CreatedTime -Descending |
                Select-Object -First 1
                if ($purgeAction) {
                    $status = $purgeAction.Status
                    if ($VerboseLog) { Write-Host ("[Watch] Attempt {0}: {1} Status={2}" -f $attempt, $purgeAction.Identity, $status) -ForegroundColor Yellow }
                    switch ($status) {
                        'Completed' { Write-Host ("[Purge] Action '{0}' Completed." -f $purgeAction.Identity) -ForegroundColor Green; return $true }
                        'Failed' { $msg = $purgeAction.PSObject.Properties['ErrorMessage'] ? $purgeAction.ErrorMessage : $null; Write-Host ("[Purge] Action '{0}' Failed. {1}" -f $purgeAction.Identity, ($msg ?? '')) -ForegroundColor Red; return $false }
                        default { }
                    }
                }
                else {
                    if ($VerboseLog) { Write-Host "[Watch] No purge action found yet for this search." -ForegroundColor DarkYellow }
                }
            }
            else {
                if ($VerboseLog) { Write-Host "[Watch] Actions not visible yet; waiting..." -ForegroundColor DarkYellow }
            }
        }
        catch {
            if ($VerboseLog) { Write-Host ("[Watch] Lookup error: {0}" -f $_.Exception.Message) -ForegroundColor DarkRed }
        }
        Start-Sleep -Seconds $PollSeconds
        if ($attempt -eq 10 -and $PollSeconds -lt 10) { $PollSeconds = 10 }
        if ($attempt -eq 30 -and $PollSeconds -lt 20) { $PollSeconds = 20 }
    }
    Write-Host "[Purge] Timed out waiting for completion." -ForegroundColor Red
    return $false
}

function Submit-Purge {
    [CmdletBinding(SupportsShouldProcess)] param(
        [Parameter(Mandatory = $true)][string]$SearchName,
        [ValidateSet('SoftDelete', 'HardDelete')][string]$PurgeType,
        [string]$SessionMode,
        [string]$UserPrincipalName
    )
    Write-Host ("[Purge] Submitting {0}..." -f $PurgeType) -ForegroundColor Cyan
    $confirm = Read-Host "Type 'YES' to confirm"
    if ($confirm -ne 'YES') { Write-Host "[Purge] Cancelled by user." -ForegroundColor Yellow; return $false }
    if ($PSCmdlet.ShouldProcess("Search $SearchName", "Purge ($PurgeType)")) {
        $attempt = 0
        $maxAttempts = 2
        while ($attempt -lt $maxAttempts) {
            $attempt++
            try {
                $action = New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType $PurgeType -ErrorAction Stop
                Write-Host ("[Purge] Submitted: {0}" -f $action.Identity) -ForegroundColor Green
                $ok = Wait-ForPurgeCompletion -SearchName $SearchName -CaseName $null -TimeoutSeconds 900 -PollSeconds 5 -VerboseLog
                if ($ok) { return $true } else { throw "Purge action did not complete successfully." }
            }
            catch {
                $msg = $_.Exception.Message
                Write-Host "[Purge] Failed: $msg" -ForegroundColor Red
                $canFallback = ($SessionMode -eq "SearchOnly") -and ($attempt -eq 1) -and (
                    $msg -match "Search-Only" -or $msg -match "not permitted" -or $msg -match "full compliance session"
                )
                if ($canFallback) {
                    Write-Host "[Purge] Fallback to Full IPPSSession..." -ForegroundColor Yellow
                    Disconnect-ExchangeOnline -Confirm:$false
                    Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
                    $SessionMode = "Full"
                    continue
                }
                throw
            }
        }
        Write-Host "[Purge] All attempts failed." -ForegroundColor Red
        return $false
    }
}

function Invoke-GuidedPurge {
    [CmdletBinding()] param(
        [Parameter(Mandatory = $true)][string]$SearchName,
        [string]$CaseName,
        [string]$SessionMode,
        [string]$UserPrincipalName
    )
    if (-not (Wait-ForSearchCompletion -SearchName $SearchName -CaseName $CaseName)) { return }
    $s = Get-SearchDetails -SearchName $SearchName -CaseName $CaseName
    $count = $s.PSObject.Properties['ItemsFound'] ? $s.ItemsFound : $s.Items
    Write-Host ("[Info] Search '{0}' Completed. Items={1}" -f $SearchName, $count) -ForegroundColor Cyan
    $doPreview = Read-Host "Run Preview action first? (Y/N)"
    if ($doPreview -match '^[Yy]$') {
        Write-Host "[Preview] Submitting preview..." -ForegroundColor Cyan
        $previewAction = New-ComplianceSearchAction -SearchName $SearchName -Preview -ErrorAction Stop
        Write-Host "[Preview] Submitted: $($previewAction.Identity)" -ForegroundColor Green
        $pa = Get-ComplianceSearchAction -Identity $previewAction.Identity -ErrorAction SilentlyContinue
        if ($pa) {
            $pCount = $pa.PSObject.Properties['ItemsFound'] ? $pa.ItemsFound : $pa.Items
            Write-Host ("[Preview] Items={0} Status={1}" -f $pCount, $pa.Status) -ForegroundColor Cyan
        }
    }
    $soft = Read-Host "Proceed with SoftDelete purge? (Y/N)"
    if ($soft -match '^[Yy]$') {
        if (-not (Submit-Purge -SearchName $SearchName -PurgeType 'SoftDelete' -SessionMode $SessionMode -UserPrincipalName $UserPrincipalName)) {
            Write-Warning "[SoftDelete] Failed or cancelled."
            return
        }
    }
    $hard = Read-Host "Proceed with HardDelete purge (permanent)? (Y/N)"
    if ($hard -match '^[Yy]$') {
        Submit-Purge -SearchName $SearchName -PurgeType 'HardDelete' -SessionMode $SessionMode -UserPrincipalName $UserPrincipalName | Out-Null
    }
}

Export-ModuleMember -Function `
    Import-ExchangeOnlineModule, `
    Connect-SearchSession, `
    Show-RecentComplianceSearches, `
    Get-ComplianceCaseByName, `
    Show-CaseComplianceSearches, `
    New-MailboxOnlyClone, `
    Wait-ForSearchCompletion, `
    Wait-ForPurgeCompletion, `
    Submit-Purge, `
    Invoke-GuidedPurge
