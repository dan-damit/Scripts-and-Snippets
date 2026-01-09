# Load config (if present)
$ConfigPath = Join-Path $PSScriptRoot 'Config\config.json'
if (Test-Path $ConfigPath) {
    $Global:TechToolboxConfig = Get-Content $ConfigPath | ConvertFrom-Json
}

# Load Private functions
Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -File | ForEach-Object {
    . $_.FullName
}

# Load Public functions
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -File | ForEach-Object {
    . $_.FullName
}

# Export only Public functions
$PublicFunctions = Get-ChildItem "$PSScriptRoot\Public\*.ps1" -File |
Select-Object -ExpandProperty BaseName

Export-ModuleMember -Function $PublicFunctions