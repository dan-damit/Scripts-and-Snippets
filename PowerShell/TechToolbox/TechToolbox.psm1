# TechToolbox.psm1
# Module initialization
$script:ModuleRoot = Split-Path -Parent $PSCommandPath
$script:ConfigPath = Join-Path $script:ModuleRoot 'Config\config.json'
$script:Config = $null

# Dot-source private helpers first
Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Private') -Filter *.ps1 -File -ErrorAction SilentlyContinue |
ForEach-Object { . $_.FullName }

# Dot-source public functions and record names for export
$publicFunctions = @()
Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Public') -Filter *.ps1 -File -ErrorAction SilentlyContinue |
ForEach-Object {
    . $_.FullName
    $publicFunctions += $_.BaseName  # assumes each file defines a matching function
}

# Export only public functions
Export-ModuleMember -Function $publicFunctions -Alias *

function Get-TechToolboxConfig {
    [CmdletBinding()]
    param()

    if ($null -ne $script:Config) { return $script:Config }

    if (-not (Test-Path -Path $script:ConfigPath)) {
        throw "Config file not found at '$script:ConfigPath'."
    }

    try {
        $raw = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse config.json: $($_.Exception.Message)"
    }

    # Optional: validate against expected shape
    Validate-TechToolboxConfig -Config $raw

    # Optional: merge defaults + environment overrides
    $envName = $env:TECHTOOLBOX_ENV
    if ($envName -and $raw.environments -and $raw.environments.$envName) {
        $script:Config = Merge-TechToolboxConfig -Base $raw -Override $raw.environments.$envName
    }
    else {
        $script:Config = $raw
    }
    return $script:Config
}
