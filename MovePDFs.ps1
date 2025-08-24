$desktop = "$env:USERPROFILE\Desktop"
$destination = Join-Path $desktop "PDFs"
New-Item -Path $destination -ItemType Directory -Force
Move-Item -Path "$desktop\*.pdf" -Destination $destination