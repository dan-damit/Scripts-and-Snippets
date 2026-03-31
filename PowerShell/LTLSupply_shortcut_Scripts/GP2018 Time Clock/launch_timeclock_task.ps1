
[CmdletBinding()]
param(
    [string]$TaskName   = 'Launch_GP_Timeclock',
    [string]$Runner     = "C:\ProgramData\TechToolbox\GP2018 Time Clock\launch_timeclock.ps1",
    [switch]$CreateDesktopShortcut
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Runner)) { throw "Runner not found: $Runner" }

Write-Host "[$(Get-Date -f HH:mm:ss)] Registering scheduled task '$TaskName' as SYSTEM (elevated)..."

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$Runner`" -VerboseLog"

# Run as SYSTEM with highest privileges
$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -Compatibility Win8

$task = New-ScheduledTask -Action $action -Principal $principal -Settings $settings

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
Register-ScheduledTask -TaskName $TaskName -InputObject $task | Out-Null

Write-Host "[$(Get-Date -f HH:mm:ss)] Task '$TaskName' registered."

if ($CreateDesktopShortcut) {
    $shortcutPath = "$env:PUBLIC\Desktop\GP2018 Time Clock.lnk"
    Write-Host "[$(Get-Date -f HH:mm:ss)] Creating desktop shortcut: $shortcutPath"
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($shortcutPath)
    $sc.TargetPath = "$env:SystemRoot\System32\schtasks.exe"
    $sc.Arguments  = "/run /tn `"$TaskName`""
    $sc.IconLocation = "C:\Program Files (x86)\Microsoft Dynamics\GP2018\Timeclk\Dynamics.exe,0"
    $sc.WorkingDirectory = 'C:\ProgramData\TechToolbox'
    $sc.Save()
    Write-Host "[$(Get-Date -f HH:mm:ss)] Shortcut created."
}

Write-Host "[$(Get-Date -f HH:mm:ss)] Done. Launch with: schtasks /run /tn `"$TaskName`""
