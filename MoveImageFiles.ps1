$desktop = "$env:USERPROFILE\Desktop"
$destination = Join-Path $desktop "Images"
New-Item -Path $destination -ItemType Directory -Force

$imageFiles = Get-ChildItem -Path "$desktop\*" -Include *.png, *.jpg, *.jpeg, *.bmp, *.gif -File
Write-Host "`nFound $($imageFiles.Count) image(s)...`n"

foreach ($file in $imageFiles) {
    Write-Host "Moving: $($file.Name)"
    Move-Item -Path $file.FullName -Destination $destination
}