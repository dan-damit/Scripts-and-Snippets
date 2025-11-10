$cutoffYear = 2024
$basePath = "C:\Users"

$users = Get-ChildItem -Path $basePath -Directory

foreach ($user in $users) {
    $downloadsPath = Join-Path $user.FullName "Downloads"

    if (Test-Path $downloadsPath) {
        Write-Host "Scanning: $downloadsPath"

        $oldFiles = Get-ChildItem -Path $downloadsPath -File -Recurse | Where-Object {
            $_.LastWriteTime.Year -le $cutoffYear
        }

        foreach ($file in $oldFiles) {
            try {
                Remove-Item -Path $file.FullName -Force
                Write-Host "Deleted: $($file.FullName)"
            } catch {
                Write-Warning "Failed to delete: $($file.FullName) — $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host ("No Downloads folder found for: " + $user.FullName)
    }
}