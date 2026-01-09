
function ConvertTo-mWh {
    <#
    .SYNOPSIS
        Parses capacity strings (e.g., '47,000 mWh', '47 Wh') into an integer
        mWh value.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text)

    $t = ($Text -replace ',', '').Trim()
    $num = [double](($t -match '(\d+(\.\d+)?)') ? $Matches[1] : 0)
    if ($num -le 0) { return $null }

    if ($t -match '(?i)\bmwh\b') { return [int]$num }
    if ($t -match '(?i)\bwh\b')  { return [int]($num * 1000) }
    # Unknown unit: assume mWh
    return [int]$num
}
