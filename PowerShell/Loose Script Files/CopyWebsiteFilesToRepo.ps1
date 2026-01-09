$source = "\\CloudDamit\web\dan"
$destination = "C:\Users\dan\Scripts-and-Snippets\Website"

# Ensure destination exists
if (!(Test-Path $destination)) {
    New-Item -ItemType Directory -Path $destination | Out-Null
}

# Copy and log each file
Get-ChildItem -Path $source -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring($source.Length).TrimStart('\')
    $targetPath = Join-Path $destination $relativePath

    # Ensure target directory exists
    $targetDir = Split-Path $targetPath
    if (!(Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # Copy and overwrite
    Copy-Item $_.FullName -Destination $targetPath -Force
    Write-Host "Copied: $($_.FullName) → $targetPath"
}