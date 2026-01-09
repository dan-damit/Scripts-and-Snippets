function Get-TechToolboxConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Config
    )

    $required = @('paths', 'settings')
    foreach ($key in $required) {
        if (-not $Config.PSObject.Properties.Name.Contains($key)) {
            throw "Missing required key '$key' in config.json."
        }
    }

    if (-not $Config.paths.temp -or -not $Config.paths.logs) {
        throw "Config.paths.temp and Config.paths.logs are required."
    }
}

function Merge-TechToolboxConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Base,
        [Parameter(Mandatory)] [object] $Override
    )
    # Simple deep-merge (Override wins); customize as needed
    $result = $Base | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    foreach ($prop in $Override.PSObject.Properties) {
        if ($result.$($prop.Name) -and ($prop.Value -is [psobject])) {
            foreach ($sub in $prop.Value.PSObject.Properties) {
                $result.$($prop.Name).$($sub.Name) = $sub.Value
            }
        } else {
            $result.$($prop.Name) = $prop.Value
        }
    }
    return $result
}
