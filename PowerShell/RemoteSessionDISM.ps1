<#  Author: Dan.Damit (https://github.com/dan-damit)

Remote DISM Repair with CredSSP, UNC validation, timeout control, 
fallback repair, structured output, and optional dry-run mode.

Parameters:
-RemoteComputer: Target computer name or IP (default: TARGET-PC)
-SourceUNC: UNC path to source files (default: Path\To\sources\sxs)
-RemoteLogDir: Remote directory for DISM logs (default: C:\Temp\DISM-Remote)
-DryRun: Validate connectivity and access without executing DISM
-SkipCredSSP: Skip CredSSP configuration (default: use CredSSP)
-CopyLogsLocal: Copy remote DISM log to local temp folder
-UseRepairWindowsImageFallback: Use Repair-WindowsImage if DISM fails

Requires: Admin rights on both client and remote, WinRM enabled.
#>

param(
    [string]$RemoteComputer = "TARGET-PC",
    [string]$SourceUNC = "Path\To\sources\sxs",
    [string]$RemoteLogDir = "C:\Temp\DISM-Remote",
    [switch]$DryRun,
    [switch]$SkipCredSSP,
    [switch]$CopyLogsLocal,
    [switch]$UseRepairWindowsImageFallback
)

# -----------------------------
# Transcript
# -----------------------------
$TranscriptLog = Join-Path $env:TEMP "DISM-Remote-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $TranscriptLog -Force | Out-Null

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
# Helper: CredSSP Enable/Disable
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
        }
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
        }
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
# Helper: Timeout-Safe DISM
# -----------------------------
function Invoke-RemoteDism {
    param(
        $Session,
        [string]$SourcePath,
        [string]$LogFile,
        [int]$TimeoutSeconds = 7200  # 2 hours
    )

    Invoke-Command -Session $Session -ScriptBlock {
        param($SourcePath, $LogFile, $TimeoutSeconds)

        $ags = @(
            "/Online",
            "/Cleanup-Image",
            "/RestoreHealth",
            "/Source:`"$SourcePath`"",
            "/LimitAccess",
            "/LogPath:$LogFile"
        )

        $proc = Start-Process -FilePath "dism.exe" -ArgumentList $ags -PassThru -NoNewWindow

        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            $proc.Kill()
            Throw "DISM timed out after $TimeoutSeconds seconds."
        }

        [pscustomobject]@{
            ExitCode = $proc.ExitCode
            LogPath  = $LogFile
        }
    } -ArgumentList $SourcePath, $LogFile, $TimeoutSeconds
}

# -----------------------------
# MAIN EXECUTION
# -----------------------------
try {
    Write-Host "Preflight: Testing WSMan connectivity..." -ForegroundColor Cyan
    Test-WSManConnection -Computer $RemoteComputer

    if (-not $SkipCredSSP) {
        Enable-CredSSP -RemoteComputer $RemoteComputer
    }

    Write-Host "Creating remote session..." -ForegroundColor Cyan
    $Session = New-PSSession -ComputerName $RemoteComputer -Credential $Cred -Authentication (if ($SkipCredSSP) { "Default" } else { "CredSSP" })

    # Dry-run mode stops here
    if ($DryRun) {
        Write-Host "Dry-run mode: Validating remote access only." -ForegroundColor Yellow

        $RemoteSourceTest = Invoke-Command -Session $Session -ScriptBlock {
            param($Path) Test-Path $Path
        } -ArgumentList $SourceUNC

        if (-not $RemoteSourceTest) {
            Throw "Remote cannot access source path: $SourceUNC"
        }

        Write-Host "Dry-run completed successfully." -ForegroundColor Green
        return
    }

    # Validate remote DISM
    Test-RemoteDism -Session $Session

    # Validate UNC access
    Write-Host "Validating remote access to UNC source..." -ForegroundColor Cyan
    $RemoteSourceTest = Invoke-Command -Session $Session -ScriptBlock {
        param($Path) Test-Path $Path
    } -ArgumentList $SourceUNC

    if (-not $RemoteSourceTest) {
        Throw "Remote computer cannot access source '$SourceUNC'."
    }

    # Ensure remote log directory
    Invoke-Command -Session $Session -ScriptBlock {
        param($Dir)
        if (-not (Test-Path $Dir)) { New-Item -Path $Dir -ItemType Directory -Force | Out-Null }
    } -ArgumentList $RemoteLogDir

    $RemoteDismLog = Join-Path $RemoteLogDir "DISM-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

    # Run DISM
    Write-Host "Running DISM remotely..." -ForegroundColor Cyan
    $DismResult = Invoke-RemoteDism -Session $Session -SourcePath $SourceUNC -LogFile $RemoteDismLog

    Write-Host "DISM exit code: $($DismResult.ExitCode)" -ForegroundColor Yellow

    if ($DismResult.ExitCode -ne 0 -and $UseRepairWindowsImageFallback) {
        Write-Warning "DISM failed. Attempting Repair-WindowsImage fallback..."

        $Fallback = Invoke-Command -Session $Session -ScriptBlock {
            param($SourcePath)
            try {
                Repair-WindowsImage -Online -RestoreHealth -Source $SourcePath -LimitAccess -ErrorAction Stop
                "OK"
            }
            catch { $_.Exception.Message }
        } -ArgumentList $SourceUNC

        if ($Fallback -ne "OK") {
            Throw "Fallback failed: $Fallback"
        }
    }

    # Optional: copy logs locally
    if ($CopyLogsLocal) {
        $LocalCopy = Join-Path $env:TEMP "Remote-DISM-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        Copy-Item -Path $RemoteDismLog -Destination $LocalCopy -FromSession $Session
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
    if (-not $SkipCredSSP) { Disable-CredSSP -RemoteComputer $RemoteComputer }
    Stop-Transcript | Out-Null
    Write-Host "Transcript saved: $TranscriptLog" -ForegroundColor Yellow
}