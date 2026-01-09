function Get-mWh {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $clean = Update-Text $Text

    # Capture number + optional unit
    $match = [regex]::Match($clean, '(?i)\b([0-9][0-9,\.]*)\s*(mwh|wh)?\b')
    if (-not $match.Success) { return $null }

    $num = $match.Groups[1].Value -replace ',', ''
    $unit = $match.Groups[2].Value.ToLower()

    if ($num -notmatch '^\d+(\.\d+)?$') {
        return $null
    }

    $val = [double]$num

    switch ($unit) {
        'mwh' { return [int][math]::Round($val) }
        'wh' { return [int][math]::Round($val * 1000) }
        default {
            # No unit — infer based on magnitude
            if ($val -ge 1000) {
                return [int][math]::Round($val)      # assume mWh
            }
            else {
                return [int][math]::Round($val * 1000) # assume Wh
            }
        }
    }
}