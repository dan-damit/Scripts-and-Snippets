
function Connect-PurviewSearchOnly {
    <#
    .SYNOPSIS
        Connects to Microsoft Purview with a SearchOnly IPPS session.
    .DESCRIPTION
        Uses Connect-IPPSSession -EnableSearchOnlySession with the provided UPN.
        Logs connection status via Write-Log.
    .PARAMETER UserPrincipalName
        UPN used to establish the Purview SearchOnly session (e.g., user@domain.com).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserPrincipalName
    )

    try {
        Write-Log -Level Info -Message ("Connecting to Purview (SearchOnly) as {0}..." -f $UserPrincipalName)
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -EnableSearchOnlySession -ErrorAction Stop
        Write-Log -Level Ok -Message "Connected to Purview (SearchOnly)."
    }
    catch {
        Write-Log -Level Error -Message ("Failed to connect to Purview as {0}: {1}" -f $UserPrincipalName, $_.Exception.Message)
        throw
    }
}
