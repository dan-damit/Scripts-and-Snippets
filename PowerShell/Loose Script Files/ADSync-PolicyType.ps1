<#
.SYNOPSIS
    Trigger Azure AD Connect sync (Delta or Initial) on a remote server via PowerShell Remoting.

.DESCRIPTION
    Prompts for the target server FQDN/hostname, establishes a remote PowerShell session,
    imports the ADSync module on the remote machine, and starts an Azure AD Connect sync cycle.

.PARAMETER ComputerName
    Target AAD Connect server (FQDN or hostname). If omitted, you will be prompted.

.PARAMETER PolicyType
    Sync policy type: 'Delta' (default) or 'Initial'.

.PARAMETER UseKerberos
    If set, uses current Windows credentials (Kerberos) instead of prompting.

.PARAMETER EnableTranscript
    If set, writes a transcript to a timestamped file in the current directory.

.PARAMETER Port
    WinRM port to use. Defaults to 5985 (HTTP). For HTTPS listeners, set to 5986 and ensure trusted certs.

.EXAMPLE
    .\Invoke-AADSyncRemote.ps1
    Prompts for server name and credentials, then runs a Delta sync.

.EXAMPLE
    .\Invoke-AADSyncRemote.ps1 -PolicyType Initial
    Prompts for server name and credentials, then runs a Full sync.

.EXAMPLE
    .\Invoke-AADSyncRemote.ps1 -UseKerberos
    Prompts for server name and uses current domain credentials (no prompt).

.EXAMPLE
    .\Invoke-AADSyncRemote.ps1 -Port 5986
    Use HTTPS WinRM (requires configured listener and trusted certificate).
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ComputerName,

    [Parameter()]
    [ValidateSet('Delta', 'Initial')]
    [string]$PolicyType = 'Delta',

    [Parameter()]
    [switch]$UseKerberos,

    [Parameter()]
    [switch]$EnableTranscript,

    [Parameter()]
    [ValidateSet(5985, 5986)]
    [int]$Port = 5985
)

# ======= Prompt for FQDN/hostname if not provided =======
if (-not $ComputerName -or [string]::IsNullOrWhiteSpace($ComputerName)) {
    $ComputerName = Read-Host -Prompt 'Enter the FQDN or hostname of the AAD Connect server (e.g., AADConnect-1.contoso.com)'
}
$ComputerName = $ComputerName.Trim()

# ======= Helpers =======
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Warning $msg }
function Write-Err($msg)  { Write-Host "[ERR ] $msg" -ForegroundColor Red }

# ======= Transcript (optional) =======
$transcriptPath = Join-Path -Path (Get-Location) -ChildPath ("AADSync_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
if ($EnableTranscript) {
    try {
        Start-Transcript -Path $transcriptPath -ErrorAction Stop | Out-Null
        Write-Info "Transcript started: $transcriptPath"
    } catch {
        Write-Warn "Could not start transcript: $($_.Exception.Message)"
    }
}

# ======= Pre-checks (local) =======
Write-Info "Performing local pre-checks..."
try {
    # Validate name can resolve (DNS)
    $resolved = Resolve-DnsName -Name $ComputerName -ErrorAction Stop
    Write-Ok "DNS resolution succeeded: $($resolved.NameHost ?? $resolved.Name)"
} catch {
    Write-Warn "DNS resolution failed for '$ComputerName': $($_.Exception.Message) — proceeding anyway."
}

# ======= Build connection options =======
$sessionOption = New-PSSessionOption -OperationTimeout 180000  # 3 minutes
$connectionUri = if ($Port -eq 5986) {
    "https://$ComputerName`:5986/wsman"
} else {
    "http://$ComputerName`:5985/wsman"
}

# ======= Credentials / Session =======
$session = $null
try {
    Write-Info "Creating remote session to $ComputerName on port $Port ..."
    if ($UseKerberos) {
        # Kerberos requires matching SPN and domain trust; use -ComputerName for Kerberos
        $session = New-PSSession -ComputerName $ComputerName -Authentication Kerberos -SessionOption $sessionOption -ErrorAction Stop
        Write-Ok "Session established using Kerberos."
    } else {
        $cred = Get-Credential -Message "Enter credentials with rights on $ComputerName"
        # For non-Kerberos scenarios or custom port, connect via connection URI
        $session = New-PSSession -ConnectionUri $connectionUri -Credential $cred -SessionOption $sessionOption -ErrorAction Stop
        Write-Ok "Session established using supplied credentials."
    }
} catch {
    Write-Err "Failed to create remote session: $($_.Exception.Message)"
    Write-Warn "Troubleshooting tips:
    - Verify PS Remoting: 'Enable-PSRemoting -Force' (run as admin on remote)
    - Check firewall: WinRM TCP $Port
    - For HTTPS (5986): ensure a valid trusted certificate and listener (winrm quickconfig)
    - Ensure the server name resolves (FQDN) and you have network reachability."
    if ($EnableTranscript) { try { Stop-Transcript | Out-Null } catch {} }
    exit 1
}

# ======= Remote environment check & sync =======
try {
    Write-Info "Checking ADSync module and service state on $ComputerName ..."
    $result = Invoke-Command -Session $session -ScriptBlock {
        $errors = @()

        # Basic environment info
        $psver = $PSVersionTable.PSVersion.ToString()
        $hostname = $env:COMPUTERNAME

        # Ensure ADSync module is available
        try {
            Import-Module ADSync -ErrorAction Stop
        } catch {
            $errors += "ADSync module not found or failed to import: $($_.Exception.Message)"
        }

        # Service check
        $svc = Get-Service -Name 'ADSync' -ErrorAction SilentlyContinue
        if (-not $svc) {
            $errors += "ADSync service not found."
        } elseif ($svc.Status -ne 'Running') {
            $errors += "ADSync service state is '$($svc.Status)'; expected 'Running'."
        }

        # If any errors, return details; else start sync
        if ($errors.Count -gt 0) {
            [PSCustomObject]@{
                ComputerName = $hostname
                PSVersion    = $psver
                PolicyType   = $using:PolicyType
                ServiceName  = $svc?.Name
                ServiceState = $svc?.Status
                Timestamp    = (Get-Date)
                Status       = 'PreCheckFailed'
                Errors       = ($errors -join '; ')
            }
        } else {
            # Start sync
            Start-ADSyncSyncCycle -PolicyType $using:PolicyType | Out-Null

            # Return status snapshot
            [PSCustomObject]@{
                ComputerName = $hostname
                PSVersion    = $psver
                PolicyType   = $using:PolicyType
                ServiceName  = $svc.Name
                ServiceState = $svc.Status
                Timestamp    = (Get-Date)
                Status       = 'SyncTriggered'
                Errors       = ''
            }
        }
    } -ErrorAction Stop

    if ($result.Status -eq 'PreCheckFailed') {
        Write-Err "Remote pre-checks failed: $($result.Errors)"
        throw "Remote environment not ready (module/service issue)."
    }

    Write-Ok "Sync ($PolicyType) triggered successfully on $ComputerName."
    $result | Format-Table -AutoSize
} catch {
    Write-Err "Invoke-Command error: $($_.Exception.Message)"
    Write-Warn "Troubleshooting tips:
    - Ensure Azure AD Connect is installed on the target and ADSync module is present.
    - Verify account has local admin or required rights on the AAD Connect server.
    - Run PowerShell as Administrator locally.
    - If using Kerberos, ensure SPNs are correct and FQDN resolves within the domain."
    if ($EnableTranscript) { try { Stop-Transcript | Out-Null } catch {} }
    Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    exit 1
} finally {
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
