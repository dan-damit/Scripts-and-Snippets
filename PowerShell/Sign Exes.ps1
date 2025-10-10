$CertPath = "C:\Users\dan\OneDrive\ADV_TECH\Scripts\Certs\SignCode_Expires_20260709.pfx"
$CertPassword = "St@ff1234!"
$TimestampUrl = "http://timestamp.digicert.com"
$ToolkitDir = "C:\Users\dan\OneDrive\ADV_TECH\_Workstation.Deployment.Toolkit"
$batchPath = "$ToolkitDir\SignAll.cmd"

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