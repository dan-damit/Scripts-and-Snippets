# Title: Check & Fix Game Bar Components
Write-Host "`n--- Game Bar Diagnostic Script ---`n" -ForegroundColor Cyan

# Check services
$services = @("XblAuthManager", "XblGameSave", "XboxGipSvc", "XboxNetApiSvc")
foreach ($svc in $services) {
    $status = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($status) {
        Write-Host "$svc is $($status.Status)" -ForegroundColor Green
    } else {
        Write-Host "$svc not found" -ForegroundColor Yellow
    }
}

# Registry validation
$regPath = "HKCU:\Software\Microsoft\GameBar"
if (Test-Path $regPath) {
    $keys = Get-ItemProperty $regPath
    Write-Host "`nRegistry settings found:" -ForegroundColor Green
    $keys | Format-List
} else {
    Write-Host "GameBar registry path missing. Attempting to create..." -ForegroundColor Yellow
    New-Item -Path $regPath -Force | Out-Null
    New-ItemProperty -Path $regPath -Name "AllowAutoGameMode" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $regPath -Name "ShowStartupPanel" -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Host "Registry keys created." -ForegroundColor Green
}

# Optional identity provider reset
Write-Host "`nIf problems persist, consider resetting Xbox Identity Provider via Settings." -ForegroundColor Magenta
Write-Host "Done.`n" -ForegroundColor Cyan
Pause