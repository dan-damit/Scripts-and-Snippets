
function Connect-AADSyncRemoteSession {
    <#
    .SYNOPSIS
        Creates a remote PSSession to the target AAD Connect server (Kerberos or
        credential-based).
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter()][ValidateSet(5985, 5986)][int]$Port = 5985,
        [Parameter()][bool]$UseKerberos = $false
    )

    $sessionOption = New-PSSessionOption -OperationTimeout 180000
    $connectionUri = if ($Port -eq 5986) { "https://$ComputerName`:5986/wsman" } else { "http://$ComputerName`:5985/wsman" }

    if ($UseKerberos) {
        if ($PSCmdlet.ShouldProcess($ComputerName, 'Create Kerberos session')) {
            return New-PSSession -ComputerName $ComputerName -Authentication Kerberos -SessionOption $sessionOption -ErrorAction Stop
        }
    }
    else {
        # Prompt for credentials optionally controlled by config.Defaults.PromptForCredentials (caller decides)
        $cred = $null
        $cfg = Get-TechToolboxConfig
        $shouldPromptCreds = $cfg.Defaults.PromptForCredentials
        if ($null -eq $shouldPromptCreds) { $shouldPromptCreds = $true }
        if ($shouldPromptCreds) {
            $cred = Get-Credential -Message ("Enter credentials with rights on {0}" -f $ComputerName)
        }
        if ($PSCmdlet.ShouldProcess($connectionUri, 'Create credential-based session')) {
            return New-PSSession -ConnectionUri $connectionUri -Credential $cred -SessionOption $sessionOption -ErrorAction Stop
        }
    }
}
