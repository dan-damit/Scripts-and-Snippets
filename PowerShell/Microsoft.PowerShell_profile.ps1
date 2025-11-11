# Matrix.ps1 — Cinematic PowerShell Profile

# ─── CONFIG ─────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "Operator's Matrix Console (elevated)"

# Shuffle glyphs once at session start
$glyphPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
$glyphs = ($glyphPool.ToCharArray() | Get-Random -Count $glyphPool.Length)

# ─── MATRIX INTRO ───────────────────────────────────────
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

    Write-Host "`nSystem Snapshot:" -ForegroundColor DarkGreen
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
}

# ─── INIT ───────────────────────────────────────────────
Show-MatrixIntro
Show-SystemSnapshot