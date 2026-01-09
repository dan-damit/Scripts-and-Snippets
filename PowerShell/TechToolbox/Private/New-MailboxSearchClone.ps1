
function New-MailboxSearchClone {
    <#
    .SYNOPSIS
        Clones an existing Compliance Search (mailbox-only) or creates a new one
        with a user-provided KQL query.
    .DESCRIPTION
        If OriginalSearchName is provided and found, clones its
        ContentMatchQuery into a mailbox-only search. Otherwise (or when not
        found), optionally prompts for KQL based on config and creates a new
        mailbox-only search. Starts the search and returns the new/clone search
        name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CaseName,
        [Parameter()][string]$OriginalSearchName
    )

    $cfg = Get-TechToolboxConfig
    $purv = $cfg.Purview
    $promptKql = $purv.Defaults.PromptForKqlQuery
    if ($null -eq $promptKql) { $promptKql = $true }  # default to prompting if config omitted

    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'

    if ([string]::IsNullOrWhiteSpace($OriginalSearchName)) {
        if (-not $promptKql) { throw "OriginalSearchName missing and KQL prompting disabled by config." }
        Write-Log -Level Info -Message "No search name provided. Prompting for KQL query..."
        $customQuery = Read-Host "Enter KQL query"
        if ([string]::IsNullOrWhiteSpace($customQuery)) { throw "Custom query cannot be empty." }

        $newSearchName = "CMS-$timestamp"
        Write-Log -Level Info -Message "Creating mailbox-only search '$newSearchName'..."
        New-ComplianceSearch -Name $newSearchName -Case $CaseName -ExchangeLocation All -ContentMatchQuery $customQuery -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $newSearchName
        return $newSearchName
    }

    try {
        $orig = Get-ComplianceSearch -Identity $OriginalSearchName -Case $CaseName -ErrorAction Stop
        $query = $orig.ContentMatchQuery
        if ([string]::IsNullOrWhiteSpace($query)) { throw "Original search has no ContentMatchQuery." }

        $cloneName = "$OriginalSearchName-MO-$timestamp"
        Write-Log -Level Info -Message "Cloning mailbox-only search '$cloneName'..."
        New-ComplianceSearch -Name $cloneName -Case $CaseName -ExchangeLocation All -ContentMatchQuery $query -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $cloneName
        return $cloneName
    }
    catch {
        Write-Log -Level Warn -Message "Search '$OriginalSearchName' not found. Prompting for KQL query..."
        if (-not $promptKql) { throw "Original search not found and KQL prompting disabled by config." }
        $customQuery = Read-Host "Enter KQL query"
        if ([string]::IsNullOrWhiteSpace($customQuery)) { throw "Custom query cannot be empty." }

        $newSearchName = "CMS-$timestamp"
        Write-Log -Level Info -Message "Creating mailbox-only search '$newSearchName'..."
        New-ComplianceSearch -Name $newSearchName -Case $CaseName -ExchangeLocation All -ContentMatchQuery $customQuery -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $newSearchName
        return $newSearchName
    }
}
