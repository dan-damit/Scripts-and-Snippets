<#
    Trigger Azure AD Connect sync (Delta or Initial) on a remote server via
    PowerShell Remoting.
    Author: Dan.Damit (https://github.com/DanDamit)

    Establishes a remote PowerShell session to the specified server,
    imports the ADSync module, and starts an Azure AD Connect sync cycle.
    Target AAD Connect server (FQDN or hostname).
    Default: AADConnect-1.vadtek.com

    Sync policy type: 'Delta' (default) or 'Initial'.
    If set, uses current Windows credentials (Kerberos) instead of prompting.
    If set, writes a transcript to a timestamped file in the current directory.

    EXAMPLES:
    .\Start-AADSync.ps1
    Runs a Delta sync on AADConnect-1.vadtek.com, prompting for credentials.
    .\Start-AADSync.ps1 -PolicyType Initial -ComputerName
    AADConnect-1.vadtek.com
    Runs a Full sync (Initial) on the specified server.
    .\Start-AADSync.ps1 -UseKerberos
    Uses current user’s Kerberos credentials (no prompt), for domain-joined
    scenarios.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ComputerName = "AADConnect-1.vadtek.com",

    [Parameter()]
    [ValidateSet('Delta', 'Initial')]
    [string]$PolicyType = 'Delta',

    [Parameter()]
    [switch]$UseKerberos,

    [Parameter()]
    [switch]$EnableTranscript
)

# Helpers
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Warning $msg }
function Write-Err($msg) { Write-Host "[ERR ] $msg" -ForegroundColor Red }

# Transcript (optional)
$transcriptPath = Join-Path -Path (Get-Location) -ChildPath ("AADSync_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
if ($EnableTranscript) {
    try {
        Start-Transcript -Path $transcriptPath -ErrorAction Stop | Out-Null
        Write-Info "Transcript started: $transcriptPath"
    }
    catch {
        Write-Warn "Could not start transcript: $($_.Exception.Message)"
    }
}

# Credentials / Session
$session = $null
try {
    Write-Info "Preparing remote session to $ComputerName ..."
    if ($UseKerberos) {
        # Assumes trusted domain and SPNs are in place
        $session = New-PSSession -ComputerName $ComputerName -Authentication Kerberos -ErrorAction Stop
        Write-Ok "Session established using Kerberos."
    }
    else {
        $cred = Get-Credential -Message "Enter credentials with rights on $ComputerName"
        $session = New-PSSession -ComputerName $ComputerName -Credential $cred -ErrorAction Stop
        Write-Ok "Session established using supplied credentials."
    }
}
catch {
    Write-Err "Failed to create remote session: $($_.Exception.Message)"
    if ($EnableTranscript) { Stop-Transcript | Out-Null }
    exit 1
}

# Execute Sync
try {
    Write-Info "Invoking ADSync $PolicyType sync on $ComputerName ..."
    $result = Invoke-Command -Session $session -ScriptBlock {
        try {
            # Ensure ADSync module is available
            Import-Module ADSync -ErrorAction Stop

            # Start sync
            Start-ADSyncSyncCycle -PolicyType $using:PolicyType

            # Optionally return service status
            $svc = Get-Service -Name 'ADSync' -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                PolicyType   = $using:PolicyType
                ServiceName  = $svc.Name
                ServiceState = $svc.Status
                Timestamp    = (Get-Date)
            }
        }
        catch {
            throw "Remote sync failed: $($_.Exception.Message)"
        }
    } -ErrorAction Stop

    Write-Ok "Sync command submitted successfully."
    if ($result) {
        $result | Format-Table -AutoSize
    }
}
catch {
    Write-Err "Invoke-Command error: $($_.Exception.Message)"
    # Provide common troubleshooting hints
    Write-Warn "Troubleshooting tips:
    - Verify WinRM is enabled on the remote: 'Enable-PSRemoting -Force'
    - Ensure firewall allows WinRM (TCP 5985/5986)
    - Confirm ADSync module is installed on the remote (Azure AD Connect server)
    - If using Kerberos, ensure you can resolve and trust the FQDN (SPNs/Constrained Delegation)
    - Run PowerShell as Administrator."
    if ($EnableTranscript) { Stop-Transcript | Out-Null }
    Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    exit 1
}
finally {
    # Cleanup
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        Write-Info "Remote session closed."
    }
    if ($EnableTranscript) {
        try { Stop-Transcript | Out-Null } catch {}
        Write-Info "Transcript saved: $transcriptPath"
    }
}

Write-Ok "Completed."
