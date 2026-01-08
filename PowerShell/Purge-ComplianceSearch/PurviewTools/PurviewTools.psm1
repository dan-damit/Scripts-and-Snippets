
# =====================================================================
# PurviewTools Module
# Version: 1.1.2
# Date   : 2026-01-07
# Author : Dan Damit (https://github.com/dan-damit)
#
# Changes in 1.1.2:
# - Hardened parameter handling: all SearchName params accept [object]
#   and normalize via Resolve-SearchName (supports string/array/PSObject).
# - Case-scoped operations aligned: use -Case only with Get-* cmdlets;
#   removed -Case from New-ComplianceSearchAction.
# - Invoke-HardDelete: added regex confirmation (YES/Y), try/catch,
#   and identity-based monitoring when available.
# - Wait-ForPurgeCompletion: logs terminal states only, guards props,
#   appends (items: N) from Get-ComplianceSearch on success.
# - Removed redundant New-MailboxOnlySearch.
# - Minor UX/logging refinements for clean console + solid audit trail.
# =====================================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Log {
    param([Parameter(Mandatory = $true, Position = 0)][string]$Message)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry = "[{0}] {1}" -f $timestamp, $Message
    Add-Content -Path $script:logFile -Value $entry
    Write-Host $Message
}

function Set-LogFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    $script:logFile = $Path
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

function Resolve-OrCreateSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CaseName,
        [string]$OriginalSearchName
    )

    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'

    if ([string]::IsNullOrWhiteSpace($OriginalSearchName)) {
        Write-Log "[Info] No search name provided. Prompting for KQL query..."
        $customQuery = Read-Host "Enter KQL query"
        if ([string]::IsNullOrWhiteSpace($customQuery)) { throw "Custom query cannot be empty." }

        $newSearchName = "CMS-$timestamp"
        Write-Log "[Custom] Creating mailbox-only search '$newSearchName'..."
        New-ComplianceSearch -Name $newSearchName -Case $CaseName -ExchangeLocation All -ContentMatchQuery $customQuery -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $newSearchName
        return [string]$newSearchName
    }

    try {
        Get-ComplianceSearch -Identity $OriginalSearchName -Case $CaseName -ErrorAction Stop | Out-Null
        Write-Log "[Info] Found existing search '$OriginalSearchName'. Cloning mailbox-only version..."

        $orig = Get-ComplianceSearch -Identity $OriginalSearchName -Case $CaseName -ErrorAction Stop
        $query = $orig.ContentMatchQuery
        if ([string]::IsNullOrWhiteSpace($query)) { throw "Original search has no ContentMatchQuery." }

        $cloneName = "$OriginalSearchName-MO-$timestamp"
        New-ComplianceSearch -Name $cloneName -Case $CaseName -ExchangeLocation All -ContentMatchQuery $query -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $cloneName
        return [string]$cloneName
    }
    catch {
        Write-Log "[Warning] Search '$OriginalSearchName' not found. Prompting for KQL query..."
        $customQuery = Read-Host "Enter KQL query"
        if ([string]::IsNullOrWhiteSpace($customQuery)) { throw "Custom query cannot be empty." }

        $newSearchName = "CMS-$timestamp"
        New-ComplianceSearch -Name $newSearchName -Case $CaseName -ExchangeLocation All -ContentMatchQuery $customQuery -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $newSearchName
        return [string]$newSearchName
    }
}

function Get-SearchDetails {
    param([object]$SearchName, [string]$CaseName)
    Get-ComplianceSearch -Identity $SearchName -Case $CaseName -ErrorAction Stop
}

function Resolve-SearchName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$SearchName
    )

    if ($null -eq $SearchName) {
        throw "Resolve-SearchName: SearchName is null."
    }
    if ($SearchName -is [string]) {
        return $SearchName.Trim()
    }
    if ($SearchName -is [array]) {
        return (Resolve-SearchName -SearchName $SearchName[0])
    }
    if ($SearchName.PSObject -and $SearchName.PSObject.Properties['Name']) {
        $n = [string]$SearchName.Name
        if (-not [string]::IsNullOrWhiteSpace($n)) { return $n.Trim() }
    }
    $s = $SearchName.ToString()
    if ($s -match '^Microsoft\.Exchange\.Compliance.*ComplianceSearch\s(.+)$') {
        return $Matches[1].Trim()
    }

    throw "Resolve-SearchName: Unable to resolve a search name from input type '$($SearchName.GetType().FullName)'. Pass the search name string."
}

function Wait-ForSearchCompletion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$SearchName,
        [string]$CaseName,
        [int]$MaxAttempts = 40,
        [int]$DelaySec = 10
    )

    $name = Resolve-SearchName -SearchName $SearchName
    Write-Log "[Wait] Waiting for search '$name' to reach Completed..."

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        $s = Get-ComplianceSearch -Identity $name -Case $CaseName -ErrorAction Stop
        Write-Log ("Status: {0} (attempt {1}/{2})" -f $s.Status, $i, $MaxAttempts)
        if ($s.Status -eq 'Completed') {
            Write-Log "Search Completed."
            Write-Host "[Success] Search Completed." -ForegroundColor Green
            return $s
        }
        Start-Sleep -Seconds $DelaySec
    }

    throw "Search did not complete in time."
}

function Invoke-HardDelete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$SearchName,
        [Parameter(Mandatory = $true)][string]$CaseName
    )

    $SearchName = Resolve-SearchName -SearchName $SearchName
    Write-Host "[Purge] Preparing to submit HardDelete for search '$SearchName' in case '$CaseName'." -ForegroundColor Cyan
    Write-Host "This will permanently delete all items found by the search." -ForegroundColor Yellow
    $confirm = Read-Host "Type 'YES' to confirm HardDelete purge"
    if ($confirm -notmatch '^(?i)(YES|Y)$') { throw "Cancelled by user." }

    try {
        $action = New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType HardDelete -ErrorAction Stop
        if ($action -and $action.Identity) {
            Write-Host "[Purge] Submitted: $($action.Identity)" -ForegroundColor Green
            Wait-ForPurgeCompletion -ActionIdentity $action.Identity -CaseName $CaseName
        }
        else {
            Write-Host "[Purge] Submitted (no Identity returned)" -ForegroundColor Green
            Wait-ForPurgeCompletion -SearchName $SearchName -CaseName $CaseName
        }
    }
    catch {
        throw "Failed to submit HardDelete purge for '$SearchName' in case '$CaseName'. Details: $($_.Exception.Message)"
    }
}


function Wait-ForPurgeCompletion {
    [CmdletBinding(DefaultParameterSetName = 'BySearch')]
    param(
        [Parameter(ParameterSetName = 'BySearch', Mandatory = $true)][object]$SearchName,
        [Parameter(ParameterSetName = 'ByAction', Mandatory = $true)][string]$ActionIdentity,
        [string]$CaseName,
        [int]$TimeoutSeconds = 1200,
        [int]$PollSeconds = 5
    )

    $name = $null
    if ($PSCmdlet.ParameterSetName -eq 'BySearch') {
        $name = Resolve-SearchName -SearchName $SearchName
    }

    $targetDesc = $PSCmdlet.ParameterSetName -eq 'ByAction' ? "action '$ActionIdentity'" : "search '$name'"
    Write-Host "[Watch] Monitoring purge $targetDesc..." -ForegroundColor Cyan
    Write-Log  "[Watch] Monitoring purge $targetDesc..."

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        $action = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByAction') {
            $params = @{ Identity = $ActionIdentity }
            if ($CaseName) { $params.Case = $CaseName }
            $action = Get-ComplianceSearchAction @params -ErrorAction SilentlyContinue
        }
        else {
            $params = @{}
            if ($CaseName) { $params.Case = $CaseName }
            $action = Get-ComplianceSearchAction -Purge @params -ErrorAction SilentlyContinue |
            Where-Object { $_.SearchName -eq $name } |
            Sort-Object CreatedTime -Descending |
            Select-Object -First 1
        }

        if ($action) {
            $status = $action.PSObject.Properties['Status'] ? $action.Status : 'Unknown'
            Write-Log ("Status={0}" -f $status)

            switch ($status) {
                'Completed' {
                    $items = $null
                    try {
                        $searchId = $name
                        if (-not $searchId) { $searchId = $action.PSObject.Properties['SearchName'] ? $action.SearchName : $null }
                        if ($searchId) {
                            $searchObj = Get-ComplianceSearch -Identity $searchId -Case $CaseName -ErrorAction Stop
                            $items = $searchObj.PSObject.Properties['Items'] ? $searchObj.Items : $null
                        }
                    }
                    catch { $items = $null }

                    $suffix = ($null -ne $items) ? " (items: $items)" : ""
                    Write-Log "[Purge] Completed successfully.$suffix"
                    Write-Host "[Purge] Completed successfully.$suffix" -ForegroundColor Green
                    return
                }
                'PartiallySucceeded' {
                    $errMsg = $action.PSObject.Properties['ErrorMessage'] ? $action.ErrorMessage : 'No error details'
                    Write-Log "[Purge] Partially succeeded: $errMsg"
                    Write-Host "[Purge] Partially succeeded: $errMsg" -ForegroundColor Yellow
                    return
                }
                'Failed' {
                    $errMsg = $action.PSObject.Properties['ErrorMessage'] ? $action.ErrorMessage : 'No error details'
                    Write-Log "[Purge] Failed: $errMsg"
                    Write-Host "[Purge] Failed: $errMsg" -ForegroundColor Red
                    return
                }
            }
        }
        else {
            Write-Host "[Watch] No purge action found yet..." -ForegroundColor DarkYellow
            Write-Log  "[Watch] No purge action found yet..."
        }
        Start-Sleep -Seconds $PollSeconds
    }
    Write-Log  "[Purge] Timed out waiting for completion."
    Write-Host "[Purge] Timed out waiting for completion." -ForegroundColor Red
}

Export-ModuleMember -Function `
    Import-ExchangeOnlineModule, `
    Connect-SearchSession, `
    Get-SearchDetails, `
    Wait-ForSearchCompletion, `
    Invoke-HardDelete, `
    Wait-ForPurgeCompletion, `
    Resolve-OrCreateSearch, `
    Resolve-SearchName
# End of PurviewTools.psm1