Get-ChildItem -Path "C:\" -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Length -gt 256MB
} | Sort-Object Length -Descending | Select-Object FullName, @{Name="SizeMB";Expression={"{0:N2}" -f ($_.Length / 1MB)}}