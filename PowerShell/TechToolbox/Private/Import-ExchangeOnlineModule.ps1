
function Import-ExchangeOnlineModule {
    <#
    .SYNOPSIS
        Ensures ExchangeOnlineManagement module is installed (CurrentUser) and imported.
    .DESCRIPTION
        Installs ExchangeOnlineManagement if missing and imports it. Logs success/failure via Write-Log.
        Honors -WhatIf for the installation step.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    try {
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            Write-Log -Level Warn -Message "ExchangeOnlineManagement module not found. Installing to CurrentUser..."
            if ($PSCmdlet.ShouldProcess('ExchangeOnlineManagement', 'Install-Module')) {
                Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            }
            else {
                Write-Log -Level Info -Message "Install-Module skipped due to -WhatIf/-Confirm."
            }
        }
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
        Write-Log -Level Ok -Message "ExchangeOnlineManagement module imported."
    }
    catch {
        Write-Log -Level Error -Message ("Failed to import/install ExchangeOnlineManagement: {0}" -f $_.Exception.Message)
        throw
    }
}
