# Diagnostic wrapper — paste at top of script
$log = Join-Path $env:TEMP "Launch-MatrixShell.diagnostic.log"
function _Log { param($m) "$((Get-Date).ToString('o')) `t $m" | Out-File -FilePath $log -Append -Encoding utf8 }

$ErrorActionPreference = 'Stop'

try {
    # Preserve original behavior — continue into the rest of your script
    _Log "Script started (PID $PID)."
} catch {
    _Log "Startup wrapper failed: $_"
    Write-Host "Startup wrapper error. See $log" -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

# Global trap so any unhandled exception is logged and paused for inspection
trap {
    _Log "UNHANDLED ERROR: $_"
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "More details written to $log" -ForegroundColor Yellow
    Read-Host "Press Enter to close"
    exit 1
}

# Window title
$Host.UI.RawUI.WindowTitle = "Operator's Console"

# glyphs ... (same as yours) ...
$glyphs = @('░','▒','▓','█','▌','▐','▄','▀','■','●','◘','◙','◦','☼','♦','♣','♠','•','◊','¤','§','¶','∞','≡','≠','≈','∴','∵','⌐','¬','¯','±','x','÷','√','∑','∏','Ω','µ','¥','£','¢','ƒ','†','‡','∂','∫','∮','∇','∝','∅','∈','∉','∋','∩','U','⊂','⊃','⊆','⊇','⊕','⊗','⊥','⋅','⌈','⌉','⌊','⌋','⟨','⟩')

function Show-MatrixIntro {
    Clear-Host
    Write-Host "`nInitializing Matrix shell..." -ForegroundColor DarkBlue
    Start-Sleep -Milliseconds 500
    for ($i = 0; $i -lt 20; $i++) {
        $line = -join (1..(Get-Random -Min 40 -Max 80) | ForEach-Object { $glyphs | Get-Random })
        Write-Host $line -ForegroundColor DarkGreen
        Start-Sleep -Milliseconds (Get-Random -Min 30 -Max 80)
    }
    Write-Host "`nDecryption Complete..." -ForegroundColor DarkBlue
    Write-Host "`nWelcome, Operator." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 500
}

function Show-SystemSnapshot {
    # defensive collection
    try { $info = Get-ComputerInfo } catch { _Log "Get-ComputerInfo failed: $_"; $info = $null }
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue

    Write-Host "`nSystem Snapshot:" -ForegroundColor DarkGreen
    Write-Host "  OS         : $($os.Caption -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  Build      : $($info.WindowsBuildLabEx -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  Machine    : $($info.CsName -or $env:COMPUTERNAME)" -ForegroundColor DarkYellow
    Write-Host "  Manufacturer: $($cs.Manufacturer -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  Model       : $($cs.Model -or 'Unknown')" -ForegroundColor DarkYellow

    if ($os -and $os.LastBootUpTime) {
        $uptime = (Get-Date) - $os.LastBootUpTime
        Write-Host "  Uptime     : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor DarkYellow
    } else {
        Write-Host "  Uptime     : [Unavailable]" -ForegroundColor DarkYellow
    }

    Write-Host "  CPU        : $($cpu.Name -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  Cores      : $($cpu.NumberOfCores -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  Threads    : $($cpu.NumberOfLogicalProcessors -or 'Unknown')" -ForegroundColor DarkYellow
    Write-Host "  RAM        : $([math]::Round(($cs?.TotalPhysicalMemory -or 0) / 1GB, 2)) GB" -ForegroundColor DarkYellow
    Write-Host "  Domain     : $($info?.CsDomain -or $env:USERDOMAIN)" -ForegroundColor DarkYellow
}

function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    $path = $(Get-Location)
    Write-Host "`n[$time] " -ForegroundColor DarkGreen -NoNewline
    Write-Host "$path" -ForegroundColor Green -NoNewline
    return "`nλ "
}

# run sequence
Show-MatrixIntro
Show-SystemSnapshot

Write-Host "`nPress Enter to exit..." -ForegroundColor Yellow
Read-Host