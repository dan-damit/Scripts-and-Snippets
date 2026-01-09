# Define install functions
Add-Type -AssemblyName Microsoft.VisualBasic
$ninjaURI = [Microsoft.VisualBasic.Interaction]::InputBox(
    "Paste the full NinjaRMM installer URL:", 
    "NinjaRMM Installer URL", 
    ""
)
function Install-NinjaRMM {
    param (
        [string]$ninjaURI
    )
    if (Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue) {
        Write-Host "NinjaRMM Agent already installed." -ForegroundColor Green
        return
    }
    Write-Host "Installing NinjaRMM Agent..."
    $ninjaInstaller = "$env:TEMP\NinjaAgentInstaller.msi"
    try {
        Invoke-WebRequest -Uri $ninjaUri -OutFile $ninjaInstaller -Headers @{
			"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
			"Referer"    = "https://app.ninjarmm.com/"
		}
        Start-Process $ninjaInstaller -ArgumentList "/passive /norestart" -Wait
        Remove-Item $ninjaInstaller -Force
        Write-Host "NinjaRMM Agent installed." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to install NinjaRMM: $_"
    }
}
Install-NinjaRMM -ninjaURI $ninjaURI