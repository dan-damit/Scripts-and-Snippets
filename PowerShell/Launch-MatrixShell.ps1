<#
Run-TempMatrix-WinPS.ps1
Creates a temporary session profile, launches a new powershell.exe with -NoProfile -NoExit that dot-sources it,
and optionally requests elevation. Cleans temp profile on exit.
#>

param(
    [switch]$Elevate,                           # add -Elevate to launch elevated
    [string]$TempDir = $env:TEMP
)

# --- helpers
function _WriteLog { param($m) "$((Get-Date).ToString('o')) `t $m" | Out-File -FilePath (Join-Path $TempDir 'Run-TempMatrix.log') -Append -Encoding utf8 }

try {
    $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $tempProfile = Join-Path $TempDir ("MatrixTempProfile-$ts.ps1")

    # Session-only profile content — drop in your branding here
    $profileText = @'
# MatrixTempProfile — session-only branding
if ($IsWindows) { $Host.UI.RawUI.WindowTitle = "Operator''s Console (Temp)" }

# Glyph set (trim or extend as needed)
$glyphs = @('░','▒','▓','█','▌','▐','▄','▀','■','●','◘','◙','◦','☼','♦','♣','♠','•','◊')

function Show-MatrixIntro {
    Clear-Host
    Write-Host "`nInitializing Matrix shell..." -ForegroundColor DarkBlue
    Start-Sleep -Milliseconds 400
    for ($i = 0; $i -lt 12; $i++) {
        $line = -join (1..(Get-Random -Min 40 -Max 70) | ForEach-Object { $glyphs | Get-Random })
        Write-Host $line -ForegroundColor DarkGreen
        Start-Sleep -Milliseconds (Get-Random -Min 25 -Max 70)
    }
    Write-Host "`nDecryption Complete..." -ForegroundColor DarkBlue
    Write-Host "`nWelcome, Operator." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 300
}

function Show-SystemSnapshot {
    # Defensive queries
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue

    Write-Host "`nSystem Snapshot:" -ForegroundColor DarkGreen
    Write-Host "  OS         : $($os.Caption -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  Build      : $($env:OS -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  Machine    : $($cs.Name -or $env:COMPUTERNAME)" -ForegroundColor DarkYellow

    if ($os -and $os.LastBootUpTime) {
        $uptime = (Get-Date) - $os.LastBootUpTime
        Write-Host "  Uptime     : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor DarkYellow
    } else {
        Write-Host "  Uptime     : [Unavailable]" -ForegroundColor DarkYellow
    }

    Write-Host "  CPU        : $($cpu.Name -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  Cores      : $($cpu.NumberOfCores -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  Threads    : $($cpu.NumberOfLogicalProcessors -or 'Unknown')" -ForegroundColor DarkYellow

    $ramGb = if ($cs -and $cs.TotalPhysicalMemory) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 2) } else { 'Unknown' }
    Write-Host "  RAM        : $ramGb GB" -ForegroundColor DarkYellow
    Write-Host "  Domain     : $($cs.Domain -or $env:USERDOMAIN)" -ForegroundColor DarkYellow
}

function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    $path = (Get-Location)
    Write-Host "`n[$time] " -ForegroundColor DarkGreen -NoNewline
    Write-Host "$path" -ForegroundColor Green -NoNewline
    return "`nλ "
}

# Run intro and snapshot once at session start
Show-MatrixIntro
Show-SystemSnapshot

# Self-delete temp profile when the session exits
$__TempProfilePath = $MyInvocation.MyCommand.Path
Register-EngineEvent PowerShell.Exiting -SupportEvent -Action {
    try { Remove-Item -LiteralPath $__TempProfilePath -ErrorAction SilentlyContinue } catch {}
} | Out-Null

'@

    # Write temp profile (UTF8 without BOM recommended)
    $profileText | Out-File -FilePath $tempProfile -Encoding utf8

    _WriteLog "Created temp profile: $tempProfile"

    # Build dot-source command and launcher args
    $dotSource = ". `"$tempProfile`""
    $argList = @("-NoProfile", "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $dotSource)

    # Build Start-Process params (targeting powershell.exe intentionally)
    $startParams = @{
        FilePath = 'powershell.exe'
        ArgumentList = $argList
        WindowStyle  = 'Normal'
    }
    if ($Elevate.IsPresent) { $startParams.Verb = 'runas' }

    Start-Process @startParams
    _WriteLog "Launched powershell.exe with temp profile (Elevate=$($Elevate.IsPresent))."
    Write-Host "Launched temporary Matrix console. Temp profile: $tempProfile"
}
catch {
    _WriteLog "Launcher error: $_"
    Write-Host "Launcher failed: $($_.Exception.Message)" -ForegroundColor Red
}