$desktop = "$env:USERPROFILE\Desktop"
$destination = Join-Path $desktop "WordDocs"
New-Item -Path $destination -ItemType Directory -Force
Move-Item -Path "$desktop\*.docx" -Destination $destination