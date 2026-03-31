
# C:\ProgramData\TechToolbox\Run-GPTimelog.ps1
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification='CredXmlPath is a file path, not a password')]

[CmdletBinding()]
param(
    [string]$PsExecPath   = 'C:\ProgramData\TechToolbox\PsExec.exe',
    [string]$KeyPath      = 'C:\ProgramData\TechToolbox\dpapi_machine.key',
    [string]$CredXmlPath  = 'C:\ProgramData\TechToolbox\svc_gp.cred.xml',
    [string]$WorkingDir   = 'C:\Program Files (x86)\Microsoft Dynamics\GP2018\Super',
    [string]$ExePath      = 'C:\Program Files (x86)\Microsoft Dynamics\GP2018\Super\Dynamics.exe',
    [string]$Argument     = 'TimeLog.set',
    [switch]$VerboseLog
)

# Make failures explicit; we’ll catch them and exit 1
$ErrorActionPreference = 'Stop'

# Ensure crypto types load cleanly (older hosts)
Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue

# ---- Logging setup ----
$logDir = 'C:\ProgramData\TechToolbox\logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logPath = Join-Path $logDir ("Run-GPTimelog_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".log")
Start-Transcript -Path $logPath -IncludeInvocationHeader -ErrorAction SilentlyContinue

function Write-Log([string]$msg) {
    $ts = (Get-Date -f 'HH:mm:ss')
    if ($VerboseLog) { Write-Host "[$ts] $msg" }
}

try {
    # ---- Validate required paths ----
    foreach ($p in @($PsExecPath, $KeyPath, $CredXmlPath, $WorkingDir, $ExePath)) {
        if (-not (Test-Path $p)) { throw "Missing path: $p" }
    }

    # ---- Load machine key & decrypt stored cred ----
    $protected = Get-Content $KeyPath -Raw
    $keyBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
        [Convert]::FromBase64String($protected),
        $null,
        [System.Security.Cryptography.DataProtectionScope]::LocalMachine
    )

    [xml]$doc = Get-Content $CredXmlPath
    $user = $doc.Credential.User
    $enc  = $doc.Credential.EncryptedPassword

    if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($enc)) {
        throw "Credential XML missing <User> or <EncryptedPassword> elements."
    }

    $secure = $enc | ConvertTo-SecureString -Key $keyBytes

    # SecureString -> plaintext for PsExec (brief)
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        if ($ptr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }
    if ([string]::IsNullOrWhiteSpace($password)) { throw "Decrypted password is empty." }

    # ---- Determine active session ID (SYSTEM's PATH may not include system32) ----
    $qwinsta = Join-Path $env:SystemRoot 'System32\qwinsta.exe'
    $sessionId = $null
    try {
        if (Test-Path $qwinsta) {
            $lines = & $qwinsta 2>$null
            foreach ($ln in $lines) {
                # Example: rdp-tcp#5   dan   2   Active ...
                if ($ln -match '^\s*\S+\s+\S+\s+(\d+)\s+Active') {
                    $sessionId = [int]$Matches[1]; break
                }
            }
        }
    } catch { }

    if (-not $sessionId) {
        $sessionId = 1
        Write-Log "Active session not found via qwinsta; defaulting to 1."
    } else {
        Write-Log "Active session detected: ID=$sessionId"
    }

    # ---- Build PsExec args ----
    $args = @(
        '-nobanner',
        '-accepteula',
        '-d',                     # do NOT wait for Dynamics to exit (so the task can finish with a 0 on success)
        '-i', $sessionId,
        '-u', $user,
        '-p', $password,
        '-h',                     # requires $user to be local admin; remove if not
        '-w', "`"$WorkingDir`"",
        "`"$ExePath`"",
        $Argument
    )

    Write-Log "Invoking PsExec as $user into session $sessionId..."
    Start-Process -FilePath $PsExecPath -ArgumentList $args -NoNewWindow | Out-Null

    Write-Log "PsExec launched. If Dynamics doesn't show, check AV/EDR, session ID, or GP prerequisites for $user."
    Stop-Transcript | Out-Null

    # SUCCESS: return 0 so Task Scheduler shows (0x0)
    exit 0
}
catch {
    Write-Error $_
    Write-Log "ERROR: $($_.Exception.Message)"
    try { Stop-Transcript | Out-Null } catch { }
    # FAILURE: return 1 so Task Scheduler shows (0x1) with a log to inspect
    exit 1
}
