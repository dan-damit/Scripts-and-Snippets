# Matrix.ps1 — Cinematic PowerShell Profile

# ─── CONFIG ─────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "Operator's Matrix Console (elevated)"

# Shuffle glyphs once at session start
$glyphPool = " ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 <>?-+=/\!@#$%^&*()_' "
$glyphs = ($glyphPool.ToCharArray() | Get-Random -Count $glyphPool.Length)

# ─── MATRIX INTRO ───────────────────────────────────────
function Show-MatrixIntro {
    Clear-Host
    Write-Host "`nInitializing Matrix shell...`n" -ForegroundColor DarkBlue
    Start-Sleep -Milliseconds 500

    for ($i = 0; $i -lt 15; $i++) {
        $line = -join (1..(Get-Random -Min 40 -Max 80) | ForEach-Object { $glyphs | Get-Random })
        Write-Host $line -ForegroundColor DarkGreen
        Start-Sleep -Milliseconds (Get-Random -Min 30 -Max 80)
    }

	Write-Host "`nDecryption Complete..." -ForegroundColor DarkBlue
    Write-Host "`nWelcome, Operator." -ForegroundColor Red
    Start-Sleep -Milliseconds 500
}

# ─── CUSTOM PROMPT ──────────────────────────────────────
function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    $path = $(Get-Location)
    Write-Host "`n[$time] " -ForegroundColor DarkGreen -NoNewline
    Write-Host "$path" -ForegroundColor Green -NoNewline
    return "`nλ "
}

# ─── DIAGNOSTIC TOGGLES (Optional) ──────────────────────
$global:MatrixDebug = $false
function Enable-MatrixDebug {
    [CmdletBinding()]
    param()
    Set-Variable -Name MatrixDebug -Scope Global -Value $true -Force
    Write-Host "Matrix Debug Mode: $global:MatrixDebug" -ForegroundColor Yellow
}

function Disable-MatrixDebug {
    [CmdletBinding()]
    param()
    Set-Variable -Name MatrixDebug -Scope Global -Value $false -Force
    Write-Host "Matrix Debug Mode: $global:MatrixDebug" -ForegroundColor Yellow
}

# ─── SYSTEM SNAPSHOT ────────────────────────────────────
function Show-SystemSnapshot {
    $info = Get-ComputerInfo

    Write-Host "`nSYSTEM SNAPSHOT:" -ForegroundColor DarkGreen
    Write-Host "  OS         : $(Get-CimInstance Win32_OperatingSystem)" -ForegroundColor DarkYellow
    Write-Host "  Build      : $($info.WindowsBuildLabEx)" -ForegroundColor DarkYellow
    Write-Host "  Machine    : $($info.CsName)" -ForegroundColor DarkYellow

    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptime = (Get-Date) - $boot
    Write-Host "  Uptime     : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor DarkYellow

    $cpuInfo = Get-CimInstance Win32_Processor
    Write-Host "  CPU        : $($cpuInfo.Name)" -ForegroundColor DarkYellow
    Write-Host "  Cores      : $($cpuInfo.NumberOfCores)" -ForegroundColor DarkYellow
    Write-Host "  Threads    : $($cpuInfo.NumberOfLogicalProcessors)" -ForegroundColor DarkYellow
    Write-Host "  RAM        : $([math]::Round($info.CsTotalPhysicalMemory / 1GB, 2)) GB" -ForegroundColor DarkYellow
    Write-Host "  Domain     : $($info.CsDomain)" -ForegroundColor DarkYellow
	Write-Host "`nDISK INFORMATION:" -ForegroundColor DarkGreen

    # Logical disks
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($disk in $disks) {
        $sizeGB = [math]::Round($disk.Size / 1GB, 2)
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $usedGB = $sizeGB - $freeGB
        $percentFree = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
        Write-Host "  Disk $($disk.DeviceID) : $usedGB GB used / $freeGB GB free ($percentFree% free)" -ForegroundColor DarkYellow
    }
	
	Write-Host "`nDRIVE MODEL:" -ForegroundColor DarkGreen

    # Physical drives
    $drives = Get-CimInstance Win32_DiskDrive
    foreach ($drive in $drives) {
        Write-Host "  Drive $($drive.DeviceID)" -ForegroundColor DarkYellow
        Write-Host "    Model   : $($drive.Model)" -ForegroundColor DarkYellow
        Write-Host "    Size    : $([math]::Round($drive.Size / 1GB, 2)) GB" -ForegroundColor DarkYellow
        Write-Host "    Status  : $($drive.Status)" -ForegroundColor DarkYellow
    }
	Write-Host "`n"
}

# ─── INIT ───────────────────────────────────────────────
Show-MatrixIntro
Show-SystemSnapshot