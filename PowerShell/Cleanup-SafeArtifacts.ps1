# Cleanup-SafeArtifacts.ps1 — Technician-grade cleanup script
# Targets safe-to-delete update/install artifacts

$targets = @(
    "C:\Windows\SoftwareDistribution\Download",
    "C:\Program Files\Common Files\Adobe\Acrobat\Setup",
    "C:\Program Files\Adobe\Acrobat DC\Acrobat\AcroCEF\SingleClientServicesUpdater.exe"
)

# Optional: Include specific files if needed
$extensions = @("*.cab", "*.msp", "*.esd")

foreach ($path in $targets) {
    if (Test-Path $path) {
        Write-Host "`nScanning: $path" -ForegroundColor Cyan

        foreach ($ext in $extensions) {
            Get-ChildItem -Path $path -Recurse -Filter $ext -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -Verbose
                } catch {
                    Write-Warning "Failed to delete $($_.FullName): $_"
                }
            }
        }

        # Delete empty folders if desired
        Get-ChildItem -Path $path -Recurse -Directory | Where-Object {
            ($_.GetFiles().Count -eq 0) -and ($_.GetDirectories().Count -eq 0)
        } | Remove-Item -Force -Verbose
    } else {
        Write-Host "Path not found: $path" -ForegroundColor DarkGray
    }
}

Write-Host "`nCleanup complete." -ForegroundColor Green