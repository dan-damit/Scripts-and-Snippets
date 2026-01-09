
function Invoke-PurviewPurge {
    <#
    .SYNOPSIS
        End-to-end Purview HardDelete purge workflow: connect, clone search, wait, purge, optionally disconnect.
    .DESCRIPTION
        Imports ExchangeOnlineManagement (if needed), connects to Purview with SearchOnly session,
        prompts for any missing inputs (config-driven), clones an existing search (mailbox-only),
        waits for completion, and submits a HardDelete purge. Uses Write-Log and supports -WhatIf/-Confirm.
    .PARAMETER UserPrincipalName
        UPN used to connect to Purview (e.g., user@domain.com).
    .PARAMETER CaseName
        eDiscovery case name/ID.
    .PARAMETER SearchName
        Original Compliance Search name/ID to clone (or leave empty to create new per clone logic).
    .NOTES
        Calls other TechToolbox functions: New-MailboxSearchClone, Wait-SearchCompletion, Invoke-HardDelete.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$UserPrincipalName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CaseName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SearchName
    )

    try {
        # 0) Config & prompt defaults
        $cfg = Get-TechToolboxConfig
        $purv = $cfg.Purview

        # Defaults: keep prompting behavior if config is absent
        $promptCase = $purv.Defaults.PromptForCaseName
        if ($null -eq $promptCase) { $promptCase = $true }
        $promptSearch = $purv.Defaults.PromptForSearchName
        if ($null -eq $promptSearch) { $promptSearch = $true }

        $autoConnect = $purv.AutoConnect
        if ($null -eq $autoConnect) { $autoConnect = $true }
        $autoDisconnect = $purv.AutoDisconnectPrompt
        if ($null -eq $autoDisconnect) { $autoDisconnect = $true }

        # 1) Import EXO module (private helper)
        Import-ExchangeOnlineModule

        # 2) Prompt for missing inputs (config-driven)
        if (-not $UserPrincipalName) {
            $UserPrincipalName = Read-Host "Enter UPN (e.g., user@domain.com)"
        }
        if (-not $CaseName) {
            if ($promptCase) {
                $CaseName = Read-Host "Enter eDiscovery Case Name/ID"
            }
            else {
                throw "CaseName is required but prompting is disabled by config."
            }
        }
        if (-not $SearchName) {
            if ($promptSearch) {
                $SearchName = Read-Host "Enter original Compliance Search Name/ID in case '$CaseName' (or press Enter to create new)"
            }
            else {
                Write-Log -Level Info -Message "No SearchName provided and prompting disabled; proceeding to clone/create."
            }
        }

        # 3) Connect to Purview if enabled by config (private helper)
        if ($autoConnect) {
            Connect-PurviewSearchOnly -UserPrincipalName $UserPrincipalName
        }
        else {
            Write-Log -Level Info -Message "AutoConnect disabled by config; ensure an active Purview session exists."
        }

        # 4) Clone or create mailbox-only search
        Write-Log -Level Info -Message ("Cloning/creating mailbox-only search from '{0}' in case '{1}'..." -f $SearchName, $CaseName)
        $cloneName = New-MailboxSearchClone -CaseName $CaseName -OriginalSearchName $SearchName

        # 5) Wait for search to complete (Private helper)
        Write-Log -Level Info -Message ("Waiting for search '{0}' in case '{1}' to complete..." -f $cloneName, $CaseName)
        $searchObj = Wait-SearchCompletion -SearchName $cloneName -CaseName $CaseName
        if ($null -eq $searchObj) { throw "Search object not returned for '$cloneName' (case '$CaseName')." }
        if ($searchObj.Items -le 0) { throw "Search '$cloneName' returned 0 mailbox items. Purge aborted." }
        Write-Log -Level Ok -Message ("Search '{0}' completed with {1} item(s)." -f $cloneName, $searchObj.Items)

        # 6) Submit HardDelete purge (respects -WhatIf/-Confirm)
        if ($PSCmdlet.ShouldProcess(("Case '{0}' Search '{1}'" -f $CaseName, $cloneName), 'Submit Purview HardDelete purge')) {
            Invoke-HardDelete -SearchName $cloneName -CaseName $CaseName -WhatIf:$WhatIfPreference -Confirm:$false
            Write-Log -Level Ok -Message ("[Done] Purview HardDelete purge submitted for search '{0}' in case '{1}'." -f $cloneName, $CaseName)
        }
        else {
            Write-Log -Level Info -Message "Purge submission skipped due to -WhatIf/-Confirm."
        }
    }
    catch {
        Write-Log -Level Error -Message ("[ERROR] {0}" -f $_.Exception.Message)
        throw
    }
    finally {
        # 7) Optional disconnect prompt (config-driven)
        if ($autoDisconnect) {
            $disconnect = Read-Host "Disconnect Exchange Online session now? (Y/N)"
            if ($disconnect -match '^(?i)(Y|YES)$') {
                try {
                    Disconnect-ExchangeOnline -Confirm:$false
                    Write-Log -Level Info -Message "Disconnected from Exchange Online."
                }
                catch {
                    Write-Log -Level Warn -Message ("Failed to disconnect cleanly: {0}" -f $_.Exception.Message)
                }
            }
            else {
                Write-Log -Level Info -Message "Session remains connected."
            }
        }
        else {
            Write-Log -Level Info -Message "AutoDisconnectPrompt disabled by config; leaving session as-is."
        }
    }
}
