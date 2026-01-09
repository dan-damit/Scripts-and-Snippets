function Invoke-TTHardDelete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$SearchName,
        [Parameter(Mandatory)][string]$CaseName
    )

    $resolved = Resolve-TTSearchName -SearchName $SearchName

    Write-Log -Level Info -Message "Preparing HardDelete purge for '$resolved' in case '$CaseName'."
    Write-Log -Level Warn -Message "This will permanently delete all items found by the search."

    $confirm = Read-Host "Type 'YES' to confirm HardDelete purge"
    if ($confirm -notmatch '^(?i)(YES|Y)$') {
        throw "HardDelete purge cancelled by user."
    }

    $action = New-ComplianceSearchAction -SearchName $resolved -Purge -PurgeType HardDelete -ErrorAction Stop

    if ($action.Identity) {
        Write-Log -Level Ok -Message "Purge submitted: $($action.Identity)"
        Wait-TTPurgeCompletion -ActionIdentity $action.Identity -CaseName $CaseName
    }
    else {
        Write-Log -Level Ok -Message "Purge submitted (no Identity returned). Monitoring by search name..."
        Wait-TTPurgeCompletion -SearchName $resolved -CaseName $CaseName
    }
}