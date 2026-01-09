# Reset Sleep visibility in power menu
# Technician-grade audit and cleanup by Dan Damit & Copilot

$log = @()
$keysToCheck = @(
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoClose" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "HidePowerOptions" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start"; Name = "HideShutDown" }
)

foreach ($entry in $keysToCheck) {
    $path = $entry.Path
    $name = $entry.Name
    $exists = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue

    if ($exists) {
        try {
            Remove-ItemProperty -Path $path -Name $name -Force
            $log += "✔ Removed $name from $path"
        } catch {
            $log += "⚠ Failed to remove $name from $path $_"
        }
    } else {
        $log += "ℹ $name not found in $path"
    }
}

# Optional: force policy refresh
gpupdate /force | Out-Null
$log += "🔄 Group policy refreshed"

# Output results
$log | ForEach-Object { Write-Host $_ }