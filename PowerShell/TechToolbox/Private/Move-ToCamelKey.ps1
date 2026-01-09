
function Move-ToCamelKey {
    <#
    .SYNOPSIS
        Maps human labels from the battery report to canonical camelCase keys.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Label)

    $map = @{
        'Design Capacity'        = 'designCapacity'
        'Full Charge Capacity'   = 'fullChargeCapacity'
        'Chemistry'              = 'chemistry'
        'Serial Number'          = 'serialNumber'
        'Manufacturer'           = 'manufacturer'
        'Name'                   = 'name'
        'Battery Name'           = 'batteryName'
        'Cycle Count'            = 'cycleCount'
        'Remaining Capacity'     = 'remainingCapacity'
    }

    # lenient matching
    foreach ($k in $map.Keys) {
        if ($Label -match ('^(?i)' + [regex]::Escape($k) + '$')) {
            return $map[$k]
        }
    }

    # fallback: transform generic label
    $fallback = ($Label -replace '[^A-Za-z0-9 ]', '' -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($fallback)) { return $null }
    $parts = $fallback.ToLower().Split(' ')
    return ($parts[0] + ($parts[1..($parts.Count-1)] | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join '')
}
