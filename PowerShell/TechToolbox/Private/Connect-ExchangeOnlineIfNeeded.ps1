
function Connect-ExchangeOnlineIfNeeded {
    <#
    .SYNOPSIS
        Connects to Exchange Online only if no active connection exists.
    .PARAMETER ShowProgress
        Whether to show progress per config (ExchangeOnline.ShowProgress).
    #>
    [CmdletBinding()]
    param([Parameter()][bool]$ShowProgress = $false)

    try {
        $active = $null
        try { $active = Get-ConnectionInformation } catch { }
        if (-not $active) {
            Write-Log -Level Info -Message "Connecting to Exchange Online..."
            Connect-ExchangeOnline -ShowProgress:$ShowProgress
        }
    }
    catch {
        Write-Log -Level Error -Message ("Failed to connect to Exchange Online: {0}" -f $_.Exception.Message)
        throw
    }
}
