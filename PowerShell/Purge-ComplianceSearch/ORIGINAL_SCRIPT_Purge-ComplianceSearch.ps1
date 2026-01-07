
# ============================================================
# Purview Compliance Search: Workload-aware Preview & Purge
# Author: Dan.Damit (https://github.com/dan-damit)
# Enhancements:
# - Scope selection: Tenant-wide vs Case-scoped
# - Workload check (Exchange vs SharePoint/OneDrive sources)
# - Auto-create mailbox-only clone from original query
# - Guided Preview -> SoftDelete -> HardDelete flow
# - Search-Only session by default; fallback to Full only if needed
# - REMOVED: ForceFullSession parameter
# ============================================================

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --------------------------
# Module bootstrap
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
# Connect (Search-Only by default; fallback to Full)
# --------------------------
function Connect-SearchSession {
    param([Parameter(Mandatory = $true)][string]$UserPrincipalName)

    Write-Host "Connecting using Search-Only session..." -ForegroundColor Cyan
    try {
        # Required for purge actions in many tenants (EXO v3.9.0+)
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
# Listing helpers (tenant-wide & case)
# --------------------------
function Show-RecentComplianceSearches {
    param([int]$Top = 10)
    Write-Host "`nTop $Top most recent TENANT-WIDE compliance searches:" -ForegroundColor Cyan
    $searches = Get-ComplianceSearch |
    Sort-Object -Property CreatedTime -Descending |
    
    # Select ItemsFound if present; else fall back to Items
    Select-Object -First $Top `
        Name, Status,
    @{ N  = 'Items';
        E = { if ($_.PSObject.Properties['ItemsFound'] -and $null -ne $_.ItemsFound) { $_.ItemsFound }
            else {
                $_.Items
            }
        }
    },
    @{ N = 'Created_Local'; E = { $_.CreatedTime.ToLocalTime() } }
    if (-not $searches) { Write-Warning "No tenant-wide searches." } else { $searches | Format-Table -AutoSize }
}

function Get-ComplianceCaseByName {
    param([Parameter(Mandatory = $true)][string]$CaseName)
    $case = Get-ComplianceCase | Where-Object { $_.Name -eq $CaseName -or $_.Identity -eq $CaseName }
    if (-not $case) { throw "Compliance case '$CaseName' not found." }
    return $case
}

function Show-CaseComplianceSearches {
    param([Parameter(Mandatory = $true)][string]$CaseName, [int]$Top = 15)
    Write-Host "`nTop $Top searches in case '$CaseName':" -ForegroundColor Cyan
    $searches = Get-ComplianceSearch -Case $CaseName |
    Sort-Object -Property CreatedTime -Descending |

    # Select ItemsFound if present; else fall back to Items
    Select-Object -First $Top `
        Name, Status,
    @{ N  = 'Items';
        E = { if ($_.PSObject.Properties['ItemsFound'] -and $null -ne $_.ItemsFound) { $_.ItemsFound }
            else {
                $_.Items
            }
        }
    },
    @{ N = 'Created_Local'; E = { $_.CreatedTime.ToLocalTime() } }
    if (-not $searches) { Write-Warning "No searches in case '$CaseName'." } else { $searches | Format-Table -AutoSize }
}

# --------------------------
# Workload analysis
# --------------------------
function Get-SearchDetails {
    param([Parameter(Mandatory = $true)][string]$SearchName, [string]$CaseName)
    if ([string]::IsNullOrWhiteSpace($CaseName)) {
        return Get-ComplianceSearch -Identity $SearchName -ErrorAction Stop
    }
    else {
        return Get-ComplianceSearch -Identity $SearchName -Case $CaseName -ErrorAction Stop
    }
}

function Test-HasNonMailboxWorkloads {
    param([Parameter(Mandatory = $true)]$SearchObj)
    # Some tenants expose these properties; others may not. Treat non-empty as true.
    $hasSP = $false
    $hasOD = $false
    $spProps = @('SharePointLocation', 'SharePointLocationExclusion')
    $odProps = @('OneDriveLocation', 'OneDriveLocationExclusion')  # property names vary; check presence

    foreach ($p in $spProps) { if ($SearchObj.PSObject.Properties[$p] -and $SearchObj.$p) { $hasSP = $true } }
    foreach ($p in $odProps) { if ($SearchObj.PSObject.Properties[$p] -and $SearchObj.$p) { $hasOD = $true } }

    return ($hasSP -or $hasOD)
}

function Get-MailboxSourcesFromSearch {
    param([Parameter(Mandatory = $true)]$SearchObj)
    # If ExchangeLocation is present, return it; otherwise assume 'All'
    if ($SearchObj.PSObject.Properties['ExchangeLocation'] -and $SearchObj.ExchangeLocation) {
        return $SearchObj.ExchangeLocation
    }
    else {
        return @('All')
    }
}

# --------------------------
# Normalize search name input
# --------------------------
function Resolve-SearchName {
    param([Parameter(Mandatory=$true)]$SearchName)
    # If an object was passed, try to read .Name; otherwise use the string as-is
    if ($SearchName -is [string]) { return $SearchName }
    if ($SearchName.PSObject.Properties['Name']) { return $SearchName.Name }
    # Last resort: strip any type prefix if someone passed .ToString()
    if ($SearchName -is [object]) {
        $s = $SearchName.ToString()
        # Remove type name prefix like '...ComplianceSearch ' if present
        if ($s -match '\s#') { return ($s -replace '^.*ComplianceSearch\s','') }
        return $s
    }
}

# --------------------------
# Wait for search completion (case-aware)
# --------------------------
function Wait-ForSearchCompletion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$SearchName,
        [string]$CaseName,
        [int]$MaxAttempts = 40,
        [int]$DelaySec = 5
    )
    $name = Resolve-SearchName $SearchName
    Write-Host "[Wait] Ensuring search '$name' reaches 'Completed'..." -ForegroundColor Cyan

    for ($i=1; $i -le $MaxAttempts; $i++) {
        $s = Get-ComplianceSearch -Identity $name -Case $CaseName -ErrorAction Stop
        Write-Host ("Status: {0} (attempt {1}/{2})" -f $s.Status, $i, $MaxAttempts) -ForegroundColor Yellow
        if ($s.Status -eq 'Completed') { Write-Host "Search is Completed." -ForegroundColor Green; return $true }
        Start-Sleep -Seconds $DelaySec
    }
    Write-Host "Search never reached Completed. Cannot continue." -ForegroundColor Red
    return $false
}

# --------------------------
# Create mailbox-only clone (tenant or case)
# --------------------------
function New-MailboxOnlyClone {
    param(
        [Parameter(Mandatory = $true)][string]$OriginalSearchName,
        [string]$CaseName,
        [Parameter(Mandatory = $true)][string]$NewSearchName
    )

    Write-Host ("[Clone] Creating mailbox-only search '{0}' from '{1}'..." -f $NewSearchName, $OriginalSearchName) -ForegroundColor Cyan
    $orig = Get-SearchDetails -SearchName $OriginalSearchName -CaseName $CaseName

    # Try to read the query and mailbox sources
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

# --------------------------
# Guided purge (Preview -> SoftDelete -> HardDelete)
# --------------------------
function Invoke-GuidedPurge {
    param(
        [Parameter(Mandatory = $true)][string]$SearchName,
        [string]$CaseName,
        [string]$SessionMode,
        [string]$UserPrincipalName
    )

    # Ensure Completed
    if (-not (Wait-ForSearchCompletion -SearchName $SearchName -CaseName $CaseName)) { return }

    $s = Get-SearchDetails -SearchName $SearchName -CaseName $CaseName
    $count = $s.PSObject.Properties['ItemsFound'] ? $s.ItemsFound : $s.Items
    Write-Host ("[Info] Search '{0}' Completed. Items={1}" -f $SearchName, $count) -ForegroundColor Cyan

    # SoftDelete first?
    $soft = Read-Host "Proceed with SoftDelete purge? (Y/N)"
    if ($soft -match '^[Yy]$') {
        if (-not (Submit-Purge -SearchName $SearchName -PurgeType 'SoftDelete' -SessionMode $SessionMode -UserPrincipalName $UserPrincipalName)) {
            Write-Warning "[SoftDelete] Failed or cancelled."
            return
        }
    }

    # HardDelete?
    $hard = Read-Host "Proceed with HardDelete purge (permanent)? (Y/N)"
    if ($hard -match '^[Yy]$') {
        Submit-Purge -SearchName $SearchName -PurgeType 'HardDelete' -SessionMode $SessionMode -UserPrincipalName $UserPrincipalName | Out-Null
    }
}

# --------------------------
# Wait for purge completion
# --------------------------
function Wait-ForPurgeCompletion {
    param(
        [Parameter(Mandatory = $true)][string]$SearchName,
        [string]$CaseName,
        [int]$TimeoutSeconds = 600,   # 10 minutes default
        [int]$PollSeconds = 5,     # initial poll interval
        [switch]$VerboseLog
    )

    # Target action Identity pattern: <Search.Identity>_Purge
    $expectedPrefix = "{0}_Purge" -f $SearchName

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $attempt = 0
    [bool]$seenAny = $false

    while ((Get-Date) -lt $deadline) {
        $attempt++

        try {
            # Enumerate actions tied to the search; case-aware if provided
            $actions = if ([string]::IsNullOrWhiteSpace($CaseName)) {
                Get-ComplianceSearchAction -SearchName $SearchName -ErrorAction SilentlyContinue
            }
            else {
                Get-ComplianceSearchAction -SearchName $SearchName -ErrorAction SilentlyContinue
            }

            if ($actions) {
                $seenAny = $true
                $purgeAction =
                $actions |
                Where-Object {
                    $_.PSObject.Properties['Action'] -and $_.Action -eq 'Purge' -and
                    $_.PSObject.Properties['Identity'] -and
                    $_.Identity -like "$expectedPrefix*"
                } |
                Sort-Object -Property CreatedTime -Descending |
                Select-Object -First 1

                if ($purgeAction) {
                    $status = $purgeAction.Status
                    if ($VerboseLog) {
                        Write-Host ("[Watch] Attempt {0}: {1} Status={2}" -f $attempt, $purgeAction.Identity, $status) -ForegroundColor Yellow
                    }

                    switch ($status) {
                        'Completed' {
                            Write-Host ("[Purge] Action '{0}' Completed." -f $purgeAction.Identity) -ForegroundColor Green
                            return $true
                        }
                        'Failed' {
                            $msg = $purgeAction.PSObject.Properties['ErrorMessage'] ? $purgeAction.ErrorMessage : $null
                            Write-Host ("[Purge] Action '{0}' Failed. {1}" -f $purgeAction.Identity, ($msg ?? '')) -ForegroundColor Red
                            return $false
                        }
                        default {
                            # Continue polling for Queued/InProgress/NotStarted/etc.
                        }
                    }
                }
                else {
                    if ($VerboseLog) {
                        Write-Host "[Watch] No purge action found yet for this search." -ForegroundColor DarkYellow
                    }
                }
            }
            else {
                if ($VerboseLog) {
                    Write-Host "[Watch] Actions not visible yet; waiting..." -ForegroundColor DarkYellow
                }
            }
        }
        catch {
            # Transient reader errors—keep trying until deadline
            if ($VerboseLog) {
                Write-Host ("[Watch] Lookup error: {0}" -f $_.Exception.Message) -ForegroundColor DarkRed
            }
        }

        Start-Sleep -Seconds $PollSeconds

        # Optional gentle backoff after first 10 attempts (avoid hammering)
        if ($attempt -eq 10 -and $PollSeconds -lt 10) { $PollSeconds = 10 }
        if ($attempt -eq 30 -and $PollSeconds -lt 20) { $PollSeconds = 20 }
    }

    Write-Host "[Purge] Timed out waiting for completion." -ForegroundColor Red
    return $false
}

# --------------------------
# Submit purge with fallback
# --------------------------
function Submit-Purge {
    param(
        [Parameter(Mandatory = $true)][string]$SearchName,
        [ValidateSet('SoftDelete', 'HardDelete')][string]$PurgeType,
        [string]$SessionMode,
        [string]$UserPrincipalName
    )

    Write-Host ("[Purge] Submitting {0}..." -f $PurgeType) -ForegroundColor Cyan
    $confirm = Read-Host "Type 'YES' to confirm"
    if ($confirm -ne 'YES') {
        Write-Host "[Purge] Cancelled by user." -ForegroundColor Yellow
        return $false
    }

    $attempt = 0
    $maxAttempts = 2
    while ($attempt -lt $maxAttempts) {
        $attempt++
        try {
            $action = New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType $PurgeType -ErrorAction Stop
            Write-Host ("[Purge] Submitted: {0}" -f $action.Identity) -ForegroundColor Green

            # Replace the ad-hoc loop with the dedicated watcher
            $ok = Wait-ForPurgeCompletion -SearchName $SearchName -CaseName $null -TimeoutSeconds 900 -PollSeconds 5 -VerboseLog
            if ($ok) { return $true } else { throw "Purge action did not complete successfully." }
        }
        catch {
            $msg = $_.Exception.Message
            Write-Host "[Purge] Failed: $msg" -ForegroundColor Red

            $canFallback = ($SessionMode -eq "SearchOnly") -and ($attempt -eq 1) -and (
                $msg -match "Search-Only" -or
                $msg -match "not permitted" -or
                $msg -match "full compliance session"
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

# --------------------------
# Main
# --------------------------
try {
    Import-ExchangeOnlineModule

    $upn = Read-Host "Enter UPN (e.g., user@domain.com)"
    if ([string]::IsNullOrWhiteSpace($upn)) { throw "UPN cannot be empty." }

    $sessionMode = Connect-SearchSession -UserPrincipalName $upn

    Write-Host "`nChoose scope:" -ForegroundColor Cyan
    Write-Host "  1) Tenant-wide (Compliance searches not in a case)"
    Write-Host "  2) eDiscovery Case-scoped"
    $scopeChoice = Read-Host "Enter 1 or 2"
    if ($scopeChoice -notin @('1', '2')) { throw "Invalid scope selection." }

    $caseName = $null

    if ($scopeChoice -eq '1') {
        # ----- Tenant-wide path -----
        Show-RecentComplianceSearches -Top 10

        $searchName = Read-Host "Enter the Compliance Search Name/ID (tenant-wide)"
        if ([string]::IsNullOrWhiteSpace($searchName)) { throw "Search Name/ID cannot be empty." }

        # Read selected search details
        $searchObj = Get-SearchDetails -SearchName $searchName -CaseName $null
        
        # Check for non-mailbox workloads (OneDrice/SharePoint/etc.)
        $hasNonMailbox = Test-HasNonMailboxWorkloads -SearchObj $searchObj
        if ($hasNonMailbox) {
            Write-Warning "This search includes SharePoint/OneDrive sources. Purge supports Exchange mailboxes only."
            $cloneName = Read-Host "Create mailbox-only clone? Enter new search name (or press Enter to skip)"
            if (-not [string]::IsNullOrWhiteSpace($cloneName)) {
                # Optional: collision check (append timestamp if already exists)
                try {
                    Get-ComplianceSearch -Identity $cloneName -ErrorAction Stop | Out-Null
                    Write-Warning "Search '$cloneName' already exists. Appending timestamp."
                    $cloneName = '{0}-{1}' -f $cloneName, (Get-Date -Format 'yyyyMMddHHmmss')
                }
                catch { }

                # Create & start mailbox-only clone (returns new search name as [string])
                $cloneParams = @{
                    OriginalSearchName = $searchName
                    NewSearchName      = $cloneName
                    CaseName           = $null
                }
                $searchName = New-MailboxOnlyClone @cloneParams
            }
        }

        # Normalize and proceed with guided actions (clone or original)
        $searchName = ([string]$searchName).Trim()
        Invoke-GuidedPurge -SearchName $searchName -CaseName $caseName -SessionMode $sessionMode -UserPrincipalName $upn
    }
    else {
        # ----- Case-scoped path -----
        $caseName = Read-Host "Enter the eDiscovery Case Name/ID (e.g., #INC-128959)"
        if ([string]::IsNullOrWhiteSpace($caseName)) { throw "Case cannot be empty." }

        # Validate the case exists
        $case = Get-ComplianceCaseByName -CaseName $caseName

        # List searches in the case and prompt
        Show-CaseComplianceSearches -CaseName $caseName -Top 15

        $searchName = Read-Host "Enter the Compliance Search Name/ID (inside case '$caseName')"
        if ([string]::IsNullOrWhiteSpace($searchName)) { throw "Search Name/ID cannot be empty." }

        # Read selected search details
        $searchObj = Get-SearchDetails -SearchName $searchName -CaseName $caseName
        
        # Check for non-mailbox workloads (OneDrice/SharePoint/etc.)
        $hasNonMailbox = Test-HasNonMailboxWorkloads -SearchObj $searchObj
        if ($hasNonMailbox) {
            Write-Warning "This case search includes SharePoint/OneDrive sources. Purge supports Exchange mailboxes only."
            $cloneName = Read-Host "Create mailbox-only clone in this case? Enter new search name (or press Enter to skip)"
            if (-not [string]::IsNullOrWhiteSpace($cloneName)) {
                # Optional: collision check (append timestamp if exists)
                try {
                    Get-ComplianceSearch -Identity $cloneName -Case $caseName -ErrorAction Stop | Out-Null
                    Write-Warning "Search '$cloneName' already exists. Appending timestamp."
                    $cloneName = '{0}-{1}' -f $cloneName, (Get-Date -Format 'yyyyMMddHHmmss')
                }
                catch { }

                # Create & start mailbox-only clone (returns new search name as [string])
                $cloneParams = @{
                    OriginalSearchName = $searchName
                    NewSearchName      = $cloneName
                    CaseName           = $caseName
                }
                $searchName = New-MailboxOnlyClone @cloneParams
            }
        }

        # Normalize and proceed with guided actions (clone or original)
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
    }
    else {
        Write-Host "Session remains connected." -ForegroundColor Yellow
    }
}
