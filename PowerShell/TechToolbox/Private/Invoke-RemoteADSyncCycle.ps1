
function Invoke-RemoteADSyncCycle {
    <#
    .SYNOPSIS
        Triggers Start-ADSyncSyncCycle (Delta/Initial) on the remote host.
    .OUTPUTS
        [pscustomobject] result with ComputerName, PolicyType, Status, Errors
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][System.Management.Automation.Runspaces.PSSession]$Session,
        [Parameter(Mandatory)][ValidateSet('Delta', 'Initial')][string]$PolicyType
    )

    if ($PSCmdlet.ShouldProcess(("ADSync on $($Session.ComputerName)"), "Start-ADSyncSyncCycle ($PolicyType)")) {
        return Invoke-Command -Session $Session -ScriptBlock {
            try {
                Start-ADSyncSyncCycle -PolicyType $using:PolicyType | Out-Null
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    PolicyType   = $using:PolicyType
                    Status       = 'SyncTriggered'
                    Errors       = ''
                }
            }
            catch {
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    PolicyType   = $using:PolicyType
                    Status       = 'SyncFailed'
                    Errors       = $_.Exception.Message
                }
            }
        }
    }
}
