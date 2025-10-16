# Find and delete all folders named "GIGABYTE" on C:\
Get-ChildItem -Path 'C:\' -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq 'GIGABYTE' } |
    ForEach-Object {
        try {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop
            Write-Host "Deleted folder: $($_.FullName)"
        } catch {
            Write-Warning "Failed to delete: $($_.FullName) - $_"
        }
    }

# Define registry hives to search
$hives = @(
    'HKLM:\SOFTWARE',
    'HKLM:\SOFTWARE\WOW6432Node',
    'HKCU:\SOFTWARE'
)

foreach ($hive in $hives) {
    Get-ChildItem -Path $hive -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'GIGABYTE' } |
        ForEach-Object {
            try {
                Remove-Item -Path $_.PsPath -Recurse -Force -ErrorAction Stop
                Write-Host "Deleted registry key: $($_.PsPath)"
            } catch {
                Write-Warning "Failed to delete registry key: $($_.PsPath) - $_"
            }
        }
}