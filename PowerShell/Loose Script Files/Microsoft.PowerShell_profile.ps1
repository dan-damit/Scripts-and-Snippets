# =====================================================================
#  Operator Profile — Clean, Professional, TechToolbox‑Aware
# =====================================================================

# ─── SETTINGS ─────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "Operator Console"

# ─── SYSTEM SNAPSHOT (FULL DETAILS) ───────────────────────
function Show-SystemSnapshot {
    $info = Get-ComputerInfo
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor

    Write-Host "`nSYSTEM SNAPSHOT:" -ForegroundColor DarkGreen
    Write-Host "  OS         : $($os.Caption)" -ForegroundColor DarkYellow
    Write-Host "  Build      : $($info.WindowsBuildLabEx)" -ForegroundColor DarkYellow
    Write-Host "  Machine    : $($info.CsName)" -ForegroundColor DarkYellow

    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Host "  Uptime     : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor DarkYellow

    Write-Host "  CPU        : $($cpu.Name)" -ForegroundColor DarkYellow
    Write-Host "  Cores      : $($cpu.NumberOfCores)" -ForegroundColor DarkYellow
    Write-Host "  Threads    : $($cpu.NumberOfLogicalProcessors)" -ForegroundColor DarkYellow
    Write-Host "  RAM        : $([math]::Round($info.CsTotalPhysicalMemory / 1GB, 2)) GB" -ForegroundColor DarkYellow
    Write-Host "  Domain     : $($info.CsDomain)" -ForegroundColor DarkYellow

    Write-Host "`nDISK INFORMATION:" -ForegroundColor DarkGreen
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($disk in $disks) {
        $sizeGB = [math]::Round($disk.Size / 1GB, 2)
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $usedGB = $sizeGB - $freeGB
        $percentFree = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
        Write-Host "  Disk $($disk.DeviceID) : $usedGB GB used / $freeGB GB free ($percentFree% free)" -ForegroundColor DarkYellow
    }

    Write-Host "`nDRIVE MODEL:" -ForegroundColor DarkGreen
    $drives = Get-CimInstance Win32_DiskDrive
    foreach ($drive in $drives) {
        Write-Host "  Drive $($drive.DeviceID)" -ForegroundColor DarkYellow
        Write-Host "    Model   : $($drive.Model)" -ForegroundColor DarkYellow
        Write-Host "    Size    : $([math]::Round($drive.Size / 1GB, 2)) GB" -ForegroundColor DarkYellow
        Write-Host "    Status  : $($drive.Status)" -ForegroundColor DarkYellow
    }

    Write-Host "`n"
}

# Display system snapshot on startup
Show-SystemSnapshot

# Path to your module
$TechToolboxRoot = "C:\Users\dan\Scripts-and-Snippets\PowerShell\TechToolbox"

# ─── AUTO‑IMPORT TOOLBOX ──────────────────────────────────
if (Test-Path $TechToolboxRoot) {
    try {
        Import-Module $TechToolboxRoot -Force -ErrorAction Stop
        Write-Host "TechToolbox loaded." -ForegroundColor Green
    }
    catch {
        Write-Host "TechToolbox failed to load: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ─── CLEAN PROFESSIONAL PROMPT ────────────────────────────
function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    $path = (Get-Location)

    Write-Host "`n[$time] " -ForegroundColor DarkCyan -NoNewline
    Write-Host "$path" -ForegroundColor White -NoNewline
    return "`nλ "
}

# =====================================================================
#  END PROFILE
# =====================================================================