# Launch-MatrixShell.ps1 — One-time Matrix shell branding

# ─── Self-Elevate to Admin ──────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ─── Window Title ───────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "Operator's Console"

# ─── Glyph Cascade ──────────────────────────────────────
$glyphs = @('░', '▒', '▓', '█', '▌', '▐', '▄', '▀', '■', '●', '◘', '◙', '◦', '☼', '♦', '♣', '♠', '•', '◊', '¤', '§', '¶', '∞', '≡', '≠', '≈', '∴', '∵', '⌐', '¬', '¯', '±', '×', '÷', '√', '∑', '∏', 'Ω', 'µ', '¥', '£', '¢', 'ƒ', '†', '‡', '∂', '∫', '∮', '∇', '∝', '∅', '∈', '∉', '∋', '∩', '∪', '⊂', '⊃', '⊆', '⊇', '⊕', '⊗', '⊥', '⋅', '⌈', '⌉', '⌊', '⌋', '⟨', '⟩')
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

# ─── System Snapshot ────────────────────────────────────
$boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptime = (Get-Date) - $boot
$cpuInfo = Get-CimInstance Win32_Processor
Write-Host "`nSystem Snapshot:" -ForegroundColor DarkGreen
Write-Host "  OS         : $((Get-CimInstance Win32_OperatingSystem).Caption)" -ForegroundColor DarkYellow
Write-Host "  Build      : $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').BuildLabEx)" -ForegroundColor DarkYellow
Write-Host "  Machine    : $env:COMPUTERNAME" -ForegroundColor DarkYellow
Write-Host "  Uptime     : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor DarkYellow
Write-Host "  CPU        : $($cpuInfo.Name)" -ForegroundColor DarkYellow
Write-Host "  RAM        : $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)) GB" -ForegroundColor DarkYellow
Write-Host "  Domain     : $env:USERDOMAIN" -ForegroundColor DarkYellow

# ─── Temporary Prompt ───────────────────────────────────
function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    $path = $(Get-Location)
    Write-Host "`n[$time] " -ForegroundColor DarkGreen -NoNewline
    Write-Host "$path" -ForegroundColor Green -NoNewline
    return "`nλ "
}