function Get-TTBatteryHealth {
    [CmdletBinding()]
    param(
        [string]$ReportPath,
        [string]$OutputJson,
        [string]$DebugInfo
    )

    # Pull config defaults if parameters not supplied
    $cfg = $Global:TechToolboxConfig.BatteryReport

    $ReportPath = $ReportPath ?? $cfg.ReportPath
    $OutputJson = $OutputJson ?? $cfg.OutputJson
    $DebugInfo = $DebugInfo ?? $cfg.DebugInfo

    Write-Log -Level Info -Message "Generating battery report..."

    # Ensure directory exists
    $reportDir = Split-Path -Parent $ReportPath
    if ($reportDir -and -not (Test-Path -LiteralPath $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }

    # Generate report
    powercfg.exe /batteryreport /output "$ReportPath" | Out-Null

    # Wait for file to be written
    $tries = 0
    while ($tries -lt 40) {
        if (Test-Path -LiteralPath $ReportPath) {
            $size = (Get-Item -LiteralPath $ReportPath).Length
            if ($size -gt 0) { break }
        }
        Start-Sleep -Milliseconds 250
        $tries++
    }

    if (-not (Test-Path -LiteralPath $ReportPath)) {
        Write-Log -Level Error -Message "Battery report not found at: $ReportPath"
        return
    }

    Write-Log -Level Ok -Message "Battery report generated."

    # Read HTML
    $html = Get-Content -LiteralPath $ReportPath -Raw
    $htmlNorm = $html -replace '&nbsp;', ' ' -replace '\r\n', "`n"

    # --- Extract Installed Batteries table ---
    Write-Log -Level Info -Message "Parsing Installed batteries section..."

    $installedPattern = '(?is)<h[1-6][^>]*>.*?Installed\W+Batter(?:y|ies).*?</h[1-6]>.*?<table\b[^>]*>(.*?)</table>'
    $sectionMatch = [regex]::Match($htmlNorm, $installedPattern)

    # Fallback: detect table by typical fields
    if (-not $sectionMatch.Success) {
        Write-Log -Level Warn -Message "Installed batteries heading not found. Trying fallback detection..."
        $tableMatches = [regex]::Matches($htmlNorm, '(?is)<table\b[^>]*>(.*?)</table>')
        foreach ($tm in $tableMatches) {
            if ($tm.Value -match '(?is)(Design\s+Capacity|Full\s+Charge\s+Capacity|Chemistry|Serial|Manufacturer)') {
                $sectionMatch = $tm
                break
            }
        }
    }

    if (-not $sectionMatch.Success) {
        Write-Log -Level Error -Message "Could not locate Installed batteries table."

        # Dump headings for debugging
        $headings = [regex]::Matches($htmlNorm, '(?is)<h[1-6][^>]*>(.*?)</h[1-6]>') |
        ForEach-Object { Update-Text $_.Groups[1].Value }

        $headings | Set-Content -LiteralPath $DebugInfo -Encoding UTF8
        Write-Log -Level Warn -Message "Wrote detected headings to $DebugInfo"

        return
    }

    # Extract rows
    $tableHtml = $sectionMatch.Value
    $tbodyMatch = [regex]::Match($tableHtml, '(?is)<tbody\b[^>]*>(.*?)</tbody>')
    $rowsHtml = if ($tbodyMatch.Success) { $tbodyMatch.Groups[1].Value } else { $tableHtml }

    $rowMatches = [regex]::Matches($rowsHtml, '(?is)<tr\b[^>]*>(.*?)</tr>')
    if ($rowMatches.Count -eq 0) {
        Write-Log -Level Error -Message "Installed batteries table has no <tr> rows."
        return
    }

    Write-Log -Level Ok -Message "Battery table located. Parsing rows..."

    # --- Parse into objects ---
    $batteries = New-Object System.Collections.Generic.List[object]
    $current = [ordered]@{}
    $startKeys = @('manufacturer', 'serialNumber', 'name', 'batteryName')

    foreach ($rm in $rowMatches) {
        $rowInner = $rm.Groups[1].Value
        $cellMatches = [regex]::Matches($rowInner, '(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')

        if ($cellMatches.Count -eq 0) { continue }

        if ($cellMatches.Count -eq 2) {
            $label = Update-Text $cellMatches[0].Groups[1].Value
            $value = Update-Text $cellMatches[1].Groups[1].Value

            $key = Update-CamelKey $label
            if ([string]::IsNullOrWhiteSpace($key)) { continue }

            # Detect new battery
            if ($startKeys -contains $key -and $current.Contains($key)) {
                # Compute health for previous battery
                $dc = if ($current.Contains('designCapacity')) { Get-mWh $current['designCapacity'] } else { $null }
                $fc = if ($current.Contains('fullChargeCapacity')) { Get-mWh $current['fullChargeCapacity'] } else { $null }

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
            # Multi-column rows
            $vals = @()
            foreach ($cm in $cellMatches) { $vals += (Update-Text $cm.Groups[1].Value) }

            if ($vals.Count -gt 0) {
                if (-not $current.Contains('rows')) {
                    $current['rows'] = New-Object System.Collections.Generic.List[object]
                }
                $current['rows'].Add($vals)
            }
        }
    }

    # Final battery
    if ($current.Count -gt 0) {
        $dc = if ($current.Contains('designCapacity')) { Get-mWh $current['designCapacity'] } else { $null }
        $fc = if ($current.Contains('fullChargeCapacity')) { Get-mWh $current['fullChargeCapacity'] } else { $null }

        if ($dc -and $fc -and $dc -gt 0) {
            $current['designCapacity_mWh'] = $dc
            $current['fullChargeCapacity_mWh'] = $fc
            $current['healthRatio'] = [math]::Round($fc / $dc, 4)
            $current['healthPercent'] = [math]::Round(($fc * 100.0) / $dc, 2)
        }

        $batteries.Add([PSCustomObject]$current)
    }

    if ($batteries.Count -eq 0) {
        Write-Log -Level Error -Message "No battery data parsed."
        return
    }

    Write-Log -Level Ok -Message "Parsed $($batteries.Count) battery object(s)."

    # --- Export JSON ---
    $dir = Split-Path -Parent $OutputJson
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $json = $batteries | ConvertTo-Json -Depth 6
    Set-Content -LiteralPath $OutputJson -Value $json -Encoding UTF8

    Write-Log -Level Ok -Message "Exported JSON with health metrics to $OutputJson"

    return $batteries
}