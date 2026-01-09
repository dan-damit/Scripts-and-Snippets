function Invoke-TTPurviewPurge {
    [CmdletBinding()]
    param(
        [string]$UserPrincipalName,
        [string]$CaseName,
        [string]$SearchName
    )

    # ---------------- Session Helpers (stay local to this function) ----------------

    function Import-ExchangeOnlineModuleInternal {
        try {
            if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
                Write-Log -Level Warn -Message "ExchangeOnlineManagement module not found. Installing..."
                Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
            }
            Import-Module ExchangeOnlineManagement -ErrorAction Stop
            Write-Log -Level Ok -Message "ExchangeOnlineManagement module imported."
        }
        catch {
            Write-Log -Level Error -Message "Failed to import/install ExchangeOnlineManagement: $($_.Exception.Message)"
            throw
        }
    }

    function Connect-SearchSessionInternal {
        param([Parameter(Mandatory)][string]$UPN)

        try {
            Write-Log -Level Info -Message "Connecting to Purview (SearchOnly session) as $UPN..."
            Connect-IPPSSession -UserPrincipalName $UPN -EnableSearchOnlySession -ErrorAction Stop
            Write-Log -Level Ok -Message "Connected to Purview (SearchOnly)."
        }
        catch {
            Write-Log -Level Error -Message "Failed to connect to Purview as $UPN $($_.Exception.Message)"
            throw
        }
    }

    # ---------------- Main Workflow ----------------

    try {
        # 1) Import EXO module
        Import-ExchangeOnlineModuleInternal

        # 2) Prompt for missing inputs
        if (-not $UserPrincipalName) {
            $UserPrincipalName = Read-Host "Enter UPN (e.g., user@domain.com)"
        }

        if (-not $CaseName) {
            $CaseName = Read-Host "Enter eDiscovery Case Name/ID"
        }

        if (-not $SearchName) {
            $SearchName = Read-Host "Enter original Compliance Search Name/ID in case '$CaseName' (or press Enter to create new)"
        }

        # 3) Connect to Purview
        Connect-SearchSessionInternal -UPN $UserPrincipalName

        # 4) Clone or create mailbox-only search
        $cloneName = New-TTMailboxSearchClone -CaseName $CaseName -OriginalSearchName $SearchName

        # 5) Wait for search to complete
        $searchObj = Wait-TTSearchCompletion -SearchName $cloneName -CaseName $CaseName
        if ($searchObj.Items -le 0) {
            throw "Search '$cloneName' returned 0 mailbox items. Purge aborted."
        }

        # 6) Submit HardDelete purge
        Invoke-TTHardDelete -SearchName $cloneName -CaseName $CaseName

        Write-Log -Level Ok -Message "[Done] Purview HardDelete purge workflow completed for search '$cloneName' in case '$CaseName'."
    }
    catch {
        Write-Log -Level Error -Message "[ERROR] $($_.Exception.Message)"
        throw
    }
    finally {
        $disconnect = Read-Host "Disconnect Exchange Online session now? (Y/N)"
        if ($disconnect -match '^(?i)(Y|YES)$') {
            try {
                Disconnect-ExchangeOnline -Confirm:$false
                Write-Log -Level Info -Message "Disconnected from Exchange Online."
            }
            catch {
                Write-Log -Level Warn -Message "Failed to disconnect cleanly: $($_.Exception.Message)"
            }
        }
        else {
            Write-Log -Level Info -Message "Session remains connected."
        }
    }
}