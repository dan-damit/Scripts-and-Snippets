<#
Run-TempMatrix-WinPS.ps1 — launcher (Windows PowerShell)
Creates a temp session profile (ASCII-safe), launches powershell.exe -NoProfile -NoExit
dot-sourcing it into an interactive session, and cleans the temp profile when the session exits.
#>

param(
    [switch]$Elevate,
    [string]$TempDir = $env:TEMP
)

try {
    $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $tempProfile = Join-Path $TempDir ("MatrixTempProfile-$ts.ps1")

    # Session-only profile content (ASCII-only here-string).
    $profileText = @'
# MatrixTempProfile — session-only ASCII-safe profile

# Init clear of console for new lines
Clear-Host

# Construct glyphs from Unicode codepoints at runtime (ASCII-safe file)
# Shuffle glyphs once at session start
$glyphPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789<>?-+=/\!@#$%^&*()_' "
$glyphs = ($glyphPool.ToCharArray() | Get-Random -Count $glyphPool.Length)

function Show-MatrixIntro {
    Clear-Host
    # Use a bright header color for the intro
    Write-Host "`nInitializing custom shell..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 350
    for ($i = 0; $i -lt 12; $i++) {
        $line = -join (1..(Get-Random -Min 40 -Max 70) | ForEach-Object { $glyphs | Get-Random })
        Write-Host $line -ForegroundColor Green
        Start-Sleep -Milliseconds (Get-Random -Min 25 -Max 70)
    }
    Write-Host "`nDecryption Complete..." -ForegroundColor Yellow
    Write-Host "`nWelcome, Operator." -ForegroundColor Red
    Start-Sleep -Milliseconds 250
}

function Show-SystemSnapshot {
    $info = Get-ComputerInfo

    Write-Host "`nSystem Snapshot:" -ForegroundColor DarkGreen
    Write-Host "  OS         : $(Get-CimInstance Win32_OperatingSystem)" -ForegroundColor Yellow
    Write-Host "  Build      : $($info.WindowsBuildLabEx)" -ForegroundColor Yellow
    Write-Host "  Machine    : $($info.CsName)" -ForegroundColor Yellow
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
		$uptime = (Get-Date) - $boot
	Write-Host "  Uptime     : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor Yellow
	$cpuInfo = Get-CimInstance Win32_Processor
	Write-Host "  CPU        : $($cpuInfo.Name)" -ForegroundColor Yellow
	Write-Host "  Cores      : $($cpuInfo.NumberOfCores)" -ForegroundColor Yellow
	Write-Host "  Threads    : $($cpuInfo.NumberOfLogicalProcessors)" -ForegroundColor Yellow
    Write-Host "  RAM        : $([math]::Round($info.CsTotalPhysicalMemory / 1GB, 2)) GB" -ForegroundColor Yellow
    Write-Host "  Domain     : $($info.CsDomain)" -ForegroundColor Yellow
}

# Reliable prompt: build lambda char at runtime to avoid encoding issues
$LambdaChar = [char]0x03BB
function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    $path = (Get-Location)
    Write-Host "`n[$time] " -ForegroundColor DarkGreen -NoNewline
    Write-Host "$path" -ForegroundColor Green -NoNewline
    return "`n$LambdaChar "
}

# Run intro and snapshot once
Show-MatrixIntro
Show-SystemSnapshot

# Self-delete temp profile when the session exits (best-effort)
$__TempProfilePath = $MyInvocation.MyCommand.Path
Register-EngineEvent PowerShell.Exiting -SupportEvent -Action {
    try { Remove-Item -LiteralPath $__TempProfilePath -ErrorAction SilentlyContinue } catch {}
} | Out-Null

'@

    # Write the temp profile explicitly as UTF-8 without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tempProfile, $profileText, $utf8NoBom)

    # Build dot-source command and args for powershell.exe
    $dotSource = ". `"$tempProfile`""
    $argList = @("-NoProfile", "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $dotSource)

    $startParams = @{
        FilePath     = 'powershell.exe'
        ArgumentList = $argList
        WindowStyle  = 'Normal'
    }
    if ($Elevate.IsPresent) { $startParams.Verb = 'runas' }

    Start-Process @startParams
    Write-Host "Launched temporary Matrix console. Temp profile: $tempProfile"
}
catch {
    Write-Host "Launcher failed: $($_.Exception.Message)" -ForegroundColor Red
}