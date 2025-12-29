
<# Author: Dan.Damit (https://github.com/dan-damit)
Remote DISM Repair with opt-in CredSSP, UNC validation, timeout control,
fallback repair, structured output, and optional dry-run mode.

Parameters:
-RemoteComputer: Target computer name or FQDN
-RemoteLogDir: Remote directory for DISM logs (default: C:\Temp\DISM-Remote)
-DryRun: Validate connectivity and access without executing DISM
-UseCredSSP: OPT-IN to use CredSSP (only when you need second-hop delegation)
-CopyLogsLocal: Copy remote DISM log to local temp folder
-UseRepairWindowsImageFallback: Use Repair-WindowsImage if DISM fails

Requires: Admin rights on both client and remote, WinRM enabled.
#>

# -----------------------------
# Parameters
# -----------------------------
param(
    [string]$RemoteComputer,
    [string]$RemoteLogDir = "C:\Temp\DISM-Remote",
    [switch]$DryRun,
    [switch]$UseCredSSP,            # <-- opt-in (was SkipCredSSP)
    [switch]$CopyLogsLocal,
    [switch]$UseRepairWindowsImageFallback
)

# -----------------------------
# Transcript
# -----------------------------
$TranscriptLog = Join-Path $env:TEMP "DISM-Remote-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $TranscriptLog -Force | Out-Null

# -----------------------------
# Prompt for RemoteComputer
# -----------------------------
$RemoteComputer = Read-Host "Enter Remote Computer name (default: $RemoteComputer)"
if ([string]::IsNullOrWhiteSpace($RemoteComputer)) {
    $RemoteComputer = $PSBoundParameters['RemoteComputer'] ?? $RemoteComputer
}

# -----------------------------
# Ask whether to use a local source first
# -----------------------------
do {
    $ans = Read-Host "Use a local repair source first? (Y/N)"
} while ($ans -notmatch '^[YyNn]$')

$UseLocalSource = $ans -match '^[Yy]$'
$SourcePath = $null
if ($UseLocalSource) {
    do {
        $SourcePath = Read-Host "Enter local/UNC source path (e.g., \\server\share\...\sources\sxs or D:\sources\sxs)"
    } while ([string]::IsNullOrWhiteSpace($SourcePath))
}

# -----------------------------
# Credential Prompt
# -----------------------------
$Cred = Get-Credential -Message "Enter credentials with admin rights on $RemoteComputer"

# -----------------------------
# Helper: Preflight WSMan Check
# -----------------------------
function Test-WSManConnection {
    param([string]$Computer)
    try {
        Test-WSMan -ComputerName $Computer -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Throw "WSMan connection to '$Computer' failed: $($_.Exception.Message)"
    }
}

# -----------------------------
# Helper: CredSSP Enable/Disable (used only when -UseCredSSP is set)
# -----------------------------
function Enable-CredSSP {
    param([string]$RemoteComputer)

    Write-Host "Enabling CredSSP..." -ForegroundColor Cyan

    try {
        Enable-WSManCredSSP -Role Client -DelegateComputer $RemoteComputer -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Client CredSSP enable failed or already enabled: $($_.Exception.Message)"
    }

    try {
        Invoke-Command -ComputerName $RemoteComputer -Credential $Cred -ScriptBlock {
            Enable-WSManCredSSP -Role Server -Force
        } -ErrorAction Stop
    }
    catch {
        Throw "Failed to enable CredSSP on remote server: $($_.Exception.Message)"
    }
}

function Disable-CredSSP {
    param([string]$RemoteComputer)

    Write-Host "Disabling CredSSP..." -ForegroundColor Cyan

    try { Disable-WSManCredSSP -Role Client -ErrorAction Stop }
    catch { Write-Warning "Client CredSSP disable failed: $($_.Exception.Message)" }

    try {
        Invoke-Command -ComputerName $RemoteComputer -Credential $Cred -ScriptBlock {
            Disable-WSManCredSSP -Role Server
        } -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Failed to disable CredSSP on remote server: $($_.Exception.Message)"
    }
}

# -----------------------------
# Helper: Remote DISM Check
# -----------------------------
function Test-RemoteDism {
    param($Session)
    Invoke-Command -Session $Session -ScriptBlock {
        if (-not (Get-Command dism.exe -ErrorAction SilentlyContinue)) {
            Throw "DISM.exe not found on remote system."
        }
    }
}

# -----------------------------
# Helper: Timeout-Safe DISM (flexible: with/without Source & LimitAccess)
# -----------------------------
function Invoke-RemoteDism {
    param(
        $Session,
        [string]$SourcePath,
        [string]$LogFile,
        [bool]$IncludeLimitAccess = $false,
        [int]$TimeoutSeconds = 7200  # 2 hours
    )

    Invoke-Command -Session $Session -ScriptBlock {
        param($SourcePath, $LogFile, $IncludeLimitAccess, $TimeoutSeconds)

        $ags = @(
            "/Online",
            "/Cleanup-Image",
            "/RestoreHealth",
            "/LogPath:$LogFile"
        )

        if ($SourcePath) { $ags += "/Source:`"$SourcePath`"" }
        if ($IncludeLimitAccess) { $ags += "/LimitAccess" }

        $proc = Start-Process -FilePath "dism.exe" -ArgumentList $ags -PassThru -NoNewWindow

        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            $proc.Kill()
            Throw "DISM timed out after $TimeoutSeconds seconds."
        }

        [pscustomobject]@{
            ExitCode = $proc.ExitCode
            LogPath  = $LogFile
        }
    } -ArgumentList $SourcePath, $LogFile, $IncludeLimitAccess, $TimeoutSeconds
}

# -----------------------------
# MAIN EXECUTION
# -----------------------------
try {
    Write-Host "Preflight: Testing WSMan connectivity..." -ForegroundColor Cyan
    Test-WSManConnection -Computer $RemoteComputer

    # Only enable CredSSP if explicitly requested (opt-in)
    if ($UseCredSSP) {
        Enable-CredSSP -RemoteComputer $RemoteComputer
    }

    Write-Host "Creating remote session..." -ForegroundColor Cyan

    # Prefer Kerberos in domain; fallback to Negotiate; include CredSSP only if requested
    $authOrder = @('Kerberos','Negotiate')
    if ($UseCredSSP) { $authOrder += 'CredSSP' }

    $Session = $null
    foreach ($auth in $authOrder) {
        try {
            $Session = New-PSSession -ComputerName $RemoteComputer `
                                     -Credential $Cred `
                                     -Authentication $auth `
                                     -ConfigurationName Microsoft.PowerShell `
                                     -ErrorAction Stop
            Write-Host "Session created using $auth." -ForegroundColor Green
            break
        }
        catch {
            Write-Warning "New-PSSession with '$auth' failed: $($_.Exception.Message)"
        }
    }
    if (-not $Session) { throw "Unable to create PSSession to $RemoteComputer with any mechanism." }

    # Dry-run mode stops here
    if ($DryRun) {
        Write-Host "Dry-run mode: Validating remote access only." -ForegroundColor Yellow

        if ($UseLocalSource) {
            $RemoteSourceTest = Invoke-Command -Session $Session -ScriptBlock {
                param($Path) Test-Path $Path
            } -ArgumentList $SourcePath

            if (-not $RemoteSourceTest) {
                Throw "Remote cannot access source path: $SourcePath"
            }
        }

        Write-Host "Dry-run completed successfully." -ForegroundColor Green
        return
    }

    # Validate remote DISM
    Test-RemoteDism -Session $Session

    # Ensure remote log directory
    Invoke-Command -Session $Session -ScriptBlock {
        param($Dir)
        if (-not (Test-Path $Dir)) { New-Item -Path $Dir -ItemType Directory -Force | Out-Null }
    } -ArgumentList $RemoteLogDir

    $RemoteDismLog = Join-Path $RemoteLogDir "DISM-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

    # -------------------------
    # Run DISM according to choice
    # -------------------------
    $DismResult = $null

    if ($UseLocalSource) {
        Write-Host "Validating remote access to source '$SourcePath'..." -ForegroundColor Cyan
        $RemoteSourceTest = Invoke-Command -Session $Session -ScriptBlock {
            param($Path) Test-Path $Path
        } -ArgumentList $SourcePath

        if (-not $RemoteSourceTest) {
            Write-Warning "Remote computer cannot access source '$SourcePath'. Proceeding with ONLINE repair."
            Write-Host "Running DISM online (no /Source, allows WU/WSUS)..." -ForegroundColor Cyan
            $DismResult = Invoke-RemoteDism -Session $Session -SourcePath $null -LogFile $RemoteDismLog
        }
        else {
            Write-Host "Running DISM with local source (offline-only using /LimitAccess)..." -ForegroundColor Cyan
            $DismResult = Invoke-RemoteDism -Session $Session -SourcePath $SourcePath -LogFile $RemoteDismLog -IncludeLimitAccess $true

            if ($DismResult.ExitCode -ne 0) {
                Write-Warning "DISM with local source failed (ExitCode=$($DismResult.ExitCode)). Retrying ONLINE repair..."
                $DismResult = Invoke-RemoteDism -Session $Session -SourcePath $null -LogFile $RemoteDismLog
            }
        }
    }
    else {
        Write-Host "Running DISM online (no /Source, allows WU/WSUS)..." -ForegroundColor Cyan
        $DismResult = Invoke-RemoteDism -Session $Session -SourcePath $null -LogFile $RemoteDismLog
    }

    Write-Host "DISM exit code: $($DismResult.ExitCode)" -ForegroundColor Yellow

    # -------------------------
    # Optional PowerShell cmdlet fallback
    # -------------------------
    if ($DismResult.ExitCode -ne 0 -and $UseRepairWindowsImageFallback) {
        Write-Warning "DISM failed. Attempting Repair-WindowsImage fallback..."

        $Fallback = Invoke-Command -Session $Session -ScriptBlock {
            param($SourcePathLocal)
            try {
                if ($SourcePathLocal) {
                    # First try with source, offline-only; then fallback online
                    Repair-WindowsImage -Online -RestoreHealth -Source $SourcePathLocal -LimitAccess -ErrorAction Stop
                }
                else {
                    # No source selected; allow online repair
                    Repair-WindowsImage -Online -RestoreHealth -ErrorAction Stop
                }
                "OK"
            }
            catch { $_.Exception.Message }
        } -ArgumentList $SourcePath

        if ($Fallback -ne "OK") {
            Throw "Fallback failed: $Fallback"
        }
    }

    # Optional: copy logs locally
    if ($CopyLogsLocal) {
        $LocalCopy = Join-Path $env:TEMP "Remote-DISM-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        Copy-Item -Path $RemoteDismLog -Destination $LocalCopy -FromSession $Session
        Write-Host "Copied remote DISM log to: $LocalCopy" -ForegroundColor Green
    }

    # Tail CBS
    Write-Host "Pulling last 50 lines of CBS.log..." -ForegroundColor Cyan
    $CBS = Invoke-Command -Session $Session -ScriptBlock {
        $Path = "C:\Windows\Logs\CBS\CBS.log"
        if (Test-Path $Path) { Get-Content $Path -Tail 50 }
        else { "CBS.log not found." }
    }

    # Structured return object
    [pscustomobject]@{
        Computer     = $RemoteComputer
        UsedLocal    = $UseLocalSource
        SourcePath   = $SourcePath
        DismExitCode = $DismResult.ExitCode
        DismLog      = $DismResult.LogPath
        Transcript   = $TranscriptLog
        Timestamp    = (Get-Date)
        CBS_Tail     = $CBS
    }

}
catch {
    Write-Error "Error: $($_.Exception.Message)"
}
finally {
    if ($Session) { Remove-PSSession $Session }
    if ($UseCredSSP) { Disable-CredSSP -RemoteComputer $RemoteComputer }   # <-- only if opted-in
    Stop-Transcript | Out-Null
    Write-Host "Transcript saved: $TranscriptLog" -ForegroundColor Yellow
}
