
function Test-AADSyncRemote {
    <#
    .SYNOPSIS
        Validates ADSync module import and service state on the remote host.
    .OUTPUTS
        [pscustomobject] with ComputerName, Status, Errors
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Management.Automation.Runspaces.PSSession]$Session)

    return Invoke-Command -Session $Session -ScriptBlock {
        $errors = @()
        try { Import-Module ADSync -ErrorAction Stop } catch {
            $errors += "ADSync module not found or failed to import: $($_.Exception.Message)"
        }
        $svc = Get-Service -Name 'ADSync' -ErrorAction SilentlyContinue
        if (-not $svc) {
            $errors += "ADSync service not found."
        }
        elseif ($svc.Status -ne 'Running') {
            $errors += "ADSync service state is '$($svc.Status)'; expected 'Running'."
        }
        if ($errors.Count -gt 0) {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Status       = 'PreCheckFailed'
                Errors       = ($errors -join '; ')
            }
        }
        else {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Status       = 'PreCheckPassed'
                Errors       = ''
            }
        }
    }
}
