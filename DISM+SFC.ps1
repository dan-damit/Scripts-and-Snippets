# Check for administrative privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
	Write-Host "Restarting as admin..." -ForegroundColor Yellow
    $ScriptPath = $MyInvocation.MyCommand.Definition
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`"" -Verb RunAs
	Start-Sleep -seconds 5
    Exit
}
# Run DISM to repair Windows image
Write-Host "Running DISM to repair Windows image..." -ForegroundColor Green
DISM /Online /Cleanup-Image /RestoreHealth

Write-Host #

# Run SFC to scan and fix corrupted files
Write-Host "Running SFC to scan and repair system files..." -ForegroundColor Green
sfc /scannow

Write-Host #

Write-Host "Process completed. Please restart your computer if needed." -ForegroundColor Yellow
Pause