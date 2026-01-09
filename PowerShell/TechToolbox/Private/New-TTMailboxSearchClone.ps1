function New-TTMailboxSearchClone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CaseName,
        [string]$OriginalSearchName
    )

    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'

    if ([string]::IsNullOrWhiteSpace($OriginalSearchName)) {
        Write-Log -Level Info -Message "No search name provided. Prompting for KQL query..."
        $customQuery = Read-Host "Enter KQL query"
        if ([string]::IsNullOrWhiteSpace($customQuery)) {
            throw "Custom query cannot be empty."
        }

        $newSearchName = "CMS-$timestamp"
        Write-Log -Level Info -Message "Creating mailbox-only search '$newSearchName'..."
        New-ComplianceSearch -Name $newSearchName -Case $CaseName -ExchangeLocation All -ContentMatchQuery $customQuery -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $newSearchName
        return $newSearchName
    }

    try {
        $orig = Get-ComplianceSearch -Identity $OriginalSearchName -Case $CaseName -ErrorAction Stop
        $query = $orig.ContentMatchQuery
        if ([string]::IsNullOrWhiteSpace($query)) {
            throw "Original search has no ContentMatchQuery."
        }

        $cloneName = "$OriginalSearchName-MO-$timestamp"
        Write-Log -Level Info -Message "Cloning mailbox-only search '$cloneName'..."
        New-ComplianceSearch -Name $cloneName -Case $CaseName -ExchangeLocation All -ContentMatchQuery $query -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $cloneName
        return $cloneName
    }
    catch {
        Write-Log -Level Warn -Message "Search '$OriginalSearchName' not found. Prompting for KQL query..."
        $customQuery = Read-Host "Enter KQL query"
        if ([string]::IsNullOrWhiteSpace($customQuery)) {
            throw "Custom query cannot be empty."
        }

        $newSearchName = "CMS-$timestamp"
        Write-Log -Level Info -Message "Creating mailbox-only search '$newSearchName'..."
        New-ComplianceSearch -Name $newSearchName -Case $CaseName -ExchangeLocation All -ContentMatchQuery $customQuery -AllowNotFoundExchangeLocationsEnabled $true -ErrorAction Stop
        Start-ComplianceSearch -Identity $newSearchName
        return $newSearchName
    }
}