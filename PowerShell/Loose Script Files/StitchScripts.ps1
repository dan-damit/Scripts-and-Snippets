# Check for admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Restarting as admin..." -ForegroundColor Yellow
    $ScriptPath = $MyInvocation.MyCommand.Definition
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`"" -Verb RunAs
    Start-Sleep -Seconds 2
    Exit
}
$scripts = '.\NewPCSetup.ps1', 'DSC3Baseline.ps1', '.\YAMLPayload.ps1'
(Get-Item $scripts | ForEach-Object { 
  "& {{`n{0}`n}}" -f (Get-Content -Raw $_.FullName) 
}) -join "`n`n" > 'MainOnboard.ps1'