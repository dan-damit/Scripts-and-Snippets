
<#
Run DISM remotely with a UNC source and full logging.
Requires: Admin rights on both client and remote, and network access to the share.
#>

# -----------------------------
# VARIABLES — edit these first
# -----------------------------
$RemoteComputer = "TARGET-PC"  # e.g. the computer being repairing
$SourceUNC = "\\UTILITY-1.vadtek.com\C$\DeploymentShare\Operating Systems\Windows 11 x64 - 24H2 - Build 26100 - Value Added Companies\sources\sxs"
$UseRepairWindowsImageFallback = $true  # set $false to skip the fallback
$RemoteLogDir = "C:\Temp\DISM-Remote"  # will be created if missing
$TranscriptLog = Join-Path $env:TEMP "DISM-Remote-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Prompt for credential once
$Cred = Get-Credential -Message "Enter credentials with admin rights on $RemoteComputer"

# -----------------------------
# Helper: Enable/Disable CredSSP
# -----------------------------
function Enable-CredSSP {
    param(
        [string]$RemoteComputer
    )
    Write-Host "Enabling CredSSP on client and remote server '$RemoteComputer'..." -ForegroundColor Cyan

    # Enable CredSSP on client (this machine)
    try {
        Enable-WSManCredSSP -Role Client -DelegateComputer $RemoteComputer -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Client CredSSP enable failed or already enabled: $($_.Exception.Message)"
    }

    # Enable CredSSP on remote server
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
    param(
        [string]$RemoteComputer
    )
    Write-Host "Disabling CredSSP on client and remote server '$RemoteComputer'..." -ForegroundColor Cyan

    # Disable CredSSP on client
    try {
        Disable-WSManCredSSP -Role Client -ErrorAction Stop
    }
    catch {
        Write-Warning "Client CredSSP disable failed or already disabled: $($_.Exception.Message)"
    }

    # Disable CredSSP on remote server
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
# Start transcript for local logging
# -----------------------------
Start-Transcript -Path $TranscriptLog -Force | Out-Null

try {
    # 1) Enable CredSSP
    Enable-CredSSP -RemoteComputer $RemoteComputer

    # 2) Create remote session using CredSSP
    Write-Host "Creating CredSSP session to $RemoteComputer..." -ForegroundColor Cyan
    $Session = New-PSSession -ComputerName $RemoteComputer -Credential $Cred -Authentication CredSSP

    # 3) Validate remote access to UNC source (double-hop test)
    Write-Host "Validating remote access to: $SourceUNC" -ForegroundColor Cyan
    $RemoteSourceTest = Invoke-Command -Session $Session -ScriptBlock {
        param($Path)
        Test-Path -Path $Path
    } -ArgumentList $SourceUNC

    if (-not $RemoteSourceTest) {
        Throw "Remote computer '$RemoteComputer' cannot access source '$SourceUNC'. Check share permissions, firewall, and double-hop setup."
    }

    # 4) Ensure remote log directory exists
    Invoke-Command -Session $Session -ScriptBlock {
        param($Dir)
        if (-not (Test-Path $Dir)) { New-Item -Path $Dir -ItemType Directory -Force | Out-Null }
    } -ArgumentList $RemoteLogDir

    $RemoteDismLog = Join-Path $RemoteLogDir "DISM-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

    # 5) Run DISM remotely
    Write-Host "Running DISM /RestoreHealth remotely..." -ForegroundColor Cyan
    $DismResult = Invoke-Command -Session $Session -ScriptBlock {
        param($SourcePath, $LogFile)

        $as = @(
            "/Online",
            "/Cleanup-Image",
            "/RestoreHealth",
            "/Source:`"$SourcePath`"",
            "/LimitAccess",
            "/LogPath:$LogFile"
        )

        $proc = Start-Process -FilePath "dism.exe" -ArgumentList $as -Wait -PassThru -NoNewWindow
        [pscustomobject]@{
            ExitCode = $proc.ExitCode
            LogPath  = $LogFile
        }
    } -ArgumentList $SourceUNC, $RemoteDismLog

    Write-Host "DISM exit code: $($DismResult.ExitCode)" -ForegroundColor Yellow
    Write-Host "Remote log: $($DismResult.LogPath)" -ForegroundColor Yellow

    # 6) Evaluate exit code
    if ($DismResult.ExitCode -ne 0) {
        Write-Warning "DISM returned non-zero exit code ($($DismResult.ExitCode)). Attempting PowerShell fallback (Repair-WindowsImage)..." 
        if ($UseRepairWindowsImageFallback) {
            $PsFallback = Invoke-Command -Session $Session -ScriptBlock {
                param($SourcePath)
                try {
                    Repair-WindowsImage -Online -RestoreHealth -Source $SourcePath -LimitAccess -ErrorAction Stop
                    "OK"
                }
                catch {
                    $_.Exception.Message
                }
            } -ArgumentList $SourceUNC

            if ($PsFallback -ne "OK") {
                Throw "Repair-WindowsImage fallback failed: $PsFallback"
            }
            else {
                Write-Host "Repair-WindowsImage completed successfully." -ForegroundColor Green
            }
        }
        else {
            Throw "DISM failed and fallback is disabled."
        }
    }
    else {
        Write-Host "DISM completed successfully." -ForegroundColor Green
    }

    # 7) Optional: show last lines of CBS log for context
    Write-Host "Pulling last 50 lines of CBS.log from remote for quick review..." -ForegroundColor Cyan
    Invoke-Command -Session $Session -ScriptBlock {
        $CBS = "C:\Windows\Logs\CBS\CBS.log"
        if (Test-Path $CBS) { Get-Content $CBS -Tail 50 }
        else { "CBS.log not found." }
    }

}
catch {
    Write-Error "Error: $($_.Exception.Message)"
}
finally {
    # Cleanup
    if ($Session) { Remove-PSSession $Session }
    Disable-CredSSP -RemoteComputer $RemoteComputer
    Stop-Transcript | Out-Null
    Write-Host "Transcript saved: $TranscriptLog" -ForegroundColor Yellow
}

