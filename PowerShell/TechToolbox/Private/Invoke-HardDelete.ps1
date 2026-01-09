
function Invoke-HardDelete {
    <#
    .SYNOPSIS
        Submits a Purview HardDelete purge for a Compliance Search and waits for completion.
    .DESCRIPTION
        Optionally requires typed confirmation per config; honors -WhatIf/-Confirm for the submission step.
        Calls Wait-PurgeCompletion to monitor the purge status.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SearchName,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CaseName
    )

    $cfg = Get-TechToolboxConfig
    $purv = $cfg.Purview
    $requireConfirm = $purv.Purge.RequireConfirmation
    if ($null -eq $requireConfirm) { $requireConfirm = $true }  # default to confirmation for safety

    Write-Log -Level Info -Message ("Preparing HardDelete purge for '{0}' in case '{1}'." -f $SearchName, $CaseName)
    Write-Log -Level Warn -Message "This will permanently delete all items found by the search."

    if ($requireConfirm) {
        $confirm = Read-Host "Type 'YES' to confirm HardDelete purge"
        if ($confirm -notmatch '^(?i)(YES|Y)$') { throw "HardDelete purge cancelled by user." }
    }

    if ($PSCmdlet.ShouldProcess(("Case '{0}' Search '{1}'" -f $CaseName, $SearchName), 'Submit HardDelete purge')) {
        $action = $null
        try {
            $action = New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType HardDelete -ErrorAction Stop
            if ($action.Identity) {
                Write-Log -Level Ok -Message ("Purge submitted: {0}" -f $action.Identity)
                Wait-PurgeCompletion -ActionIdentity $action.Identity -CaseName $CaseName
            }
            else {
                Write-Log -Level Ok -Message "Purge submitted (no Identity returned). Monitoring by search name..."
                Wait-PurgeCompletion -SearchName $SearchName -CaseName $CaseName
            }
        }
        catch {
            Write-Log -Level Error -Message ("Failed to submit purge: {0}" -f $_.Exception.Message)
            throw
        }
    }
    else {
        Write-Log -Level Info -Message "Purge submission skipped due to -WhatIf/-Confirm."
    }
}
