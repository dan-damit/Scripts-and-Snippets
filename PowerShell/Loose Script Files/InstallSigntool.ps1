# Download and install Windows SDK with only the signing tools
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2120843" -OutFile "$env:TEMP\winsdksetup.exe"
Start-Process "$env:TEMP\winsdksetup.exe" -ArgumentList "/features OptionId.SigningTools /quiet /norestart" -Wait

# Locate the signtool path (adjust <version> as needed)
$sdkPath = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64"  # Example version
$envVar = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

# Check if it's already in PATH
if ($envVar -notlike "*$sdkPath*") {
    $newPath = "$envVar;$sdkPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
    Write-Host "SignTool path added to system PATH."
} else {
    Write-Host "SignTool path is already in system PATH."
}