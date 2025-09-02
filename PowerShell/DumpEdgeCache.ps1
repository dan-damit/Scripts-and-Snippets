# Kill Edge processes
Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "msedgewebview2" -Force -ErrorAction SilentlyContinue

# Define Edge cache path
$edgeCachePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"

# Remove cache contents
if (Test-Path $edgeCachePath) {
    Remove-Item "$edgeCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Edge cache cleared from: $edgeCachePath"
} else {
    Write-Host "Edge cache path not found."
}