Get-ChildItem -Path "C:\Users" -Directory -Recurse | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    [PSCustomObject]@{
        Folder = $_.FullName
        SizeMB = "{0:N2}" -f ($size / 1MB)
    }
} | Where-Object { [double]$_.SizeMB -gt 256 } | Sort-Object SizeMB -Descending