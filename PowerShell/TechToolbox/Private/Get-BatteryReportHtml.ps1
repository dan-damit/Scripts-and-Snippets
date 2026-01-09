
function Get-BatteryReportHtml {
    <#
    .SYNOPSIS
        Parses the battery report HTML and returns battery objects + optional
        debug text.
    .OUTPUTS
        [object[]], [string]  # batteries array, debug text (headings) when
        table detection fails
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Html
    )

    $htmlNorm = $Html -replace "`r`n", "`n" -replace "\t", " "
    $installedPattern = '(?is)<h[1-6][^>]*>.*?Installed\W+Batter(?:y|ies).*?</h[1-6]>.*?<table\b[^>]*>(.*?)</table>'
    $sectionMatch = [regex]::Match($htmlNorm, $installedPattern)

    # Fallback: detect table by typical labels if heading not found
    if (-not $sectionMatch.Success) {
        $tableMatches = [regex]::Matches($htmlNorm, '(?is)<table\b[^>]*>(.*?)</table>')
        foreach ($tm in $tableMatches) {
            if ($tm.Value -match '(?is)(Design\s+Capacity|Full\s+Charge\s+Capacity|Chemistry|Serial|Manufacturer)') {
                $sectionMatch = $tm
                break
            }
        }
    }

    if (-not $sectionMatch.Success) {
        # Gather headings for debug
        $headings = [regex]::Matches($htmlNorm, '(?is)<h[1-6][^>]*>(.*?)</h[1-6]>') | ForEach-Object {
            Format-Text $_.Groups[1].Value
        }
        return @(), ($headings -join [Environment]::NewLine)
    }

    $tableHtml = $sectionMatch.Value
    $tbodyMatch = [regex]::Match($tableHtml, '(?is)<tbody\b[^>]*>(.*?)</tbody>')
    $rowsHtml = if ($tbodyMatch.Success) { $tbodyMatch.Groups[1].Value } else { $tableHtml }
    $rowMatches = [regex]::Matches($rowsHtml, '(?is)<tr\b[^>]*>(.*?)</tr>')
    if ($rowMatches.Count -eq 0) { return @(), $null }

    $batteries = New-Object System.Collections.Generic.List[object]
    $current = [ordered]@{}
    $startKeys = @('manufacturer', 'serialNumber', 'name', 'batteryName')

    foreach ($rm in $rowMatches) {
        $rowInner = $rm.Groups[1].Value
        $cellMatches = [regex]::Matches($rowInner, '(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')
        if ($cellMatches.Count -eq 0) { continue }

        if ($cellMatches.Count -eq 2) {
            # Key-value row
            $label = Format-Text $cellMatches[0].Groups[1].Value
            $value = Format-Text $cellMatches[1].Groups[1].Value
            $key = Move-ToCamelKey $label
            if ([string]::IsNullOrWhiteSpace($key)) { continue }

            # Detect start of a new battery when a "start key" repeats
            if ($startKeys -contains $key -and $current.Contains($key)) {
                # finalize previous battery with parsed capacities
                $dc = if ($current.Contains('designCapacity')) { ConvertTo-mWh $current['designCapacity'] } else { $null }
                $fc = if ($current.Contains('fullChargeCapacity')) { ConvertTo-mWh $current['fullChargeCapacity'] } else { $null }
                if ($dc -and $fc -and $dc -gt 0) {
                    $current['designCapacity_mWh'] = $dc
                    $current['fullChargeCapacity_mWh'] = $fc
                    $current['healthRatio'] = [math]::Round($fc / $dc, 4)
                    $current['healthPercent'] = [math]::Round(($fc * 100.0) / $dc, 2)
                }
                $batteries.Add([PSCustomObject]$current)
                $current = [ordered]@{}
            }
            $current[$key] = $value
        }
        else {
            # Multi-column row: capture as raw values
            $vals = @()
            foreach ($cm in $cellMatches) { $vals += (Format-Text $cm.Groups[1].Value) }
            if ($vals.Count -gt 0) {
                if (-not $current.Contains('rows')) {
                    $current['rows'] = New-Object System.Collections.Generic.List[object]
                }
                $current['rows'].Add($vals)
            }
        }
    }

    # finalize last battery
    if ($current.Count -gt 0) {
        $dc = if ($current.Contains('designCapacity')) { ConvertTo-mWh $current['designCapacity'] } else { $null }
        $fc = if ($current.Contains('fullChargeCapacity')) { ConvertTo-mWh $current['fullChargeCapacity'] } else { $null }
        if ($dc -and $fc -and $dc -gt 0) {
            $current['designCapacity_mWh'] = $dc
            $current['fullChargeCapacity_mWh'] = $fc
            $current['healthRatio'] = [math]::Round($fc / $dc, 4)
            $current['healthPercent'] = [math]::Round(($fc * 100.0) / $dc, 2)
        }
        $batteries.Add([PSCustomObject]$current)
    }

    return , $batteries, $null
}
