# TechToolbox.psm1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ModuleRoot = Split-Path -Parent $PSCommandPath
$script:ConfigPath = Join-Path $script:ModuleRoot 'Config\config.json'
$script:Config = $null

# Load Private first
Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Private') -Filter *.ps1 -File -ErrorAction SilentlyContinue |
ForEach-Object { . $_.FullName }

# Load Public and export only those
$publicFunctions = Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Public') -Filter *.ps1 -File -ErrorAction SilentlyContinue |
ForEach-Object {
    . $_.FullName
    $_.BaseName
}

Export-ModuleMember -Function $publicFunctions

function Get-TechToolboxConfig {
    <#
    .SYNOPSIS
    Loads and returns the TechToolbox configuration from config.json.
    .OUTPUTS
    PSCustomObject representing the configuration.
    #>
    [CmdletBinding()]
    param()

    if ($script:Config) { return $script:Config }

    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        throw "Config file not found: $script:ConfigPath"
    }

    try {
        $raw = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse config.json: $($_.Exception.Message)"
    }

    # Basic validation: ensure critical keys exist
    foreach ($key in @('Paths', 'Logging')) {
        if (-not $raw.PSObject.Properties.Name.Contains($key)) {
            throw "Missing required config section: '$key'"
        }
    }

    $script:Config = $raw
    return $script:Config
}
