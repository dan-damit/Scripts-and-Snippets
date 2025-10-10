$Host.UI.RawUI.ForegroundColor = 'Yellow'
$CertPath = "C:\Users\dan\OneDrive\ADV_TECH\Scripts\Certs\SignCode_Expires_20260709.pfx"
$TimestampUrl = "http://timestamp.digicert.com"
$ToolkitDir = "C:\Users\dan\OneDrive\ADV_TECH\_Workstation.Deployment.Toolkit"
$batchPath = "$ToolkitDir\SignAll.cmd"
$secure = Read-Host "Enter certificate password" -AsSecureString
$ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$CertPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr).Trim()
$filesToSign = @(
    "ToolkitLauncher.exe",
    "BackupWorkstation.exe",
    "RestoreWorkstation.exe",
    "WS.Setup.exe",
    "Workstation.Deployment.Toolkit.Installer.exe"
)

# Build batch file
@"
@echo off
setlocal
set CERT="$CertPath"
set PASS=$CertPassword
set TS=$TimestampUrl
"@ | Set-Content $batchPath

foreach ($file in $filesToSign) {
    $fullPath = Join-Path $ToolkitDir $file
    if (Test-Path $fullPath) {
        Add-Content $batchPath "signtool sign /fd SHA256 /f %CERT% /p %PASS% /tr %TS% /td SHA256 `"$fullPath`""
    }
}

# Run batch file
Start-Process -FilePath $batchPath -Wait -NoNewWindow

# Cleanup
if (Test-Path $batchPath) {
    Remove-Item $batchPath -Force
    Write-Host "🧹 Cleaned up temporary batch file: $batchPath"
}
$Host.UI.RawUI.ForegroundColor = 'Gray'
$Host.UI.RawUI.BackgroundColor = 'Black'