<# Build WS Seutp.exe
   This script builds the WS Setup executable 
   
#>
# Check for admin and relaunch hidden if needed
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $ScriptPath = $MyInvocation.MyCommand.Definition
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    $psi.Verb = "runas"
    # $psi.WindowStyle = "Hidden"  # Uncomment this to run hidden
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    Exit
}

Push-Location "C:\Users\dan\WS_Setup_6\WS_Setup_6.UI"
dotnet clean
dotnet restore
dotnet build -c Release
dotnet publish -c Release
Pop-Location

signtool sign /fd SHA256 /f "C:\Users\dan\OneDrive\ADV_TECH\Scripts\Certs\SignCode_Expires_20260709.pfx" /p St@ff1234! /tr http://timestamp.digicert.com /td SHA256 "C:\Users\dan\WS_Setup_6\WS_Setup_6.UI\bin\Release\net8.0-windows\win-x64\Publish\WS_Setup_6.UI.exe"

Push-Location "C:\Users\dan\WS_Setup_6\WS_Setup_6.MSI"
dotnet clean
dotnet restore
dotnet build -c Release
dotnet publish -c Release
Pop-Location

signtool sign /fd SHA256 /f "C:\Users\dan\OneDrive\ADV_TECH\Scripts\Certs\SignCode_Expires_20260709.pfx" /p St@ff1234! /tr http://timestamp.digicert.com /td SHA256 "C:\Users\dan\WS_Setup_6\WS_Setup_6.MSI\Deploy\Release\en-us\WS_Setup_6.MSI.msi"

Push-Location "C:\Users\dan\WS_Setup_6\WS_Setup_6.Bundle"
dotnet clean
dotnet restore
dotnet build -c Release
dotnet publish -c Release
Pop-Location