# Author: Dan.Damit
# Requires: Windows PowerShell 5.1 (no external modules)
# Purpose: Extract data under "Installed batteries" from powercfg battery report, output JSON with health metrics

# Paths
$ReportPath  = "C:\temp\battery-report.html"
$OutputJson  = "C:\temp\installed-batteries.json"
$DebugInfo   = "C:\temp\installed-batteries_debug.txt"

# --- Generate report ---
$reportDir = Split-Path -Parent $ReportPath
if ($reportDir -and -not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
powercfg.exe /batteryreport /output "$ReportPath" | Out-Null

# Wait briefly for the file to be written and non-empty
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
    Write-Error "Battery report not found at: $ReportPath"
    exit 1
}

# --- Read HTML and Update ---
$html = Get-Content -LiteralPath $ReportPath -Raw
$htmlNorm = $html -replace '&nbsp;', ' ' -replace '\r\n', "`n"

# --- Helpers ---
function Update-Text {
    param([string]$s)
    if (-not $s) { return "" }
    try { $s = [System.Web.HttpUtility]::HtmlDecode($s) } catch { }
    $s = ($s -replace '<[^>]+>', '')
    ($s -replace [char]0xA0, ' ' -replace '\s+', ' ').Trim()
}

function Update-CamelKey {
    param([string]$label)
    $l = Update-Text $label
    $l = ($l.ToLower() -replace '[^a-z0-9 ]','').Trim()
    if ([string]::IsNullOrWhiteSpace($l)) { return "" }
    $parts = $l -split '\s+'
    $key = $parts[0]
    for ($i=1; $i -lt $parts.Length; $i++) {
        $key += ($parts[$i].Substring(0,1).ToUpper() + $parts[$i].Substring(1))
    }
    return $key
}

# Parse capacity strings like "55,000 mWh", "55 Wh", "55,000", etc. into integer mWh
function Get-mWh {
    param([string]$text)
    $t = Update-Text $text
    # Capture number and optional unit
    $m = [regex]::Match($t, '(?i)\b([0-9][0-9,\.]*)\s*(mwh|wh)?\b')
    if (-not $m.Success) { return $null }
    $num = $m.Groups[1].Value
    $unit = $m.Groups[2].Value.ToLower()
    # Update number: remove commas; support decimals (round)
    $num = ($num -replace ',','')
    $val = 0
    if ($num -match '^\d+(\.\d+)?$') {
        $val = [double]$num
    } else {
        return $null
    }
    switch ($unit) {
        'mwh' { return [int][math]::Round($val) }      # already mWh
        'wh'  { return [int][math]::Round($val * 1000) } # convert Wh → mWh
        default {
            # No unit—assume mWh if value is large, else Wh
            if ($val -ge 1000) { return [int][math]::Round($val) } else { return [int][math]::Round($val * 1000) }
        }
    }
}

# --- Find Installed batteries section (any heading level), then first table ---
$installedPattern = '(?is)<h[1-6][^>]*>.*?Installed\W+Batter(?:y|ies).*?</h[1-6]>.*?<table\b[^>]*>(.*?)</table>'
$sectionMatch = [regex]::Match($htmlNorm, $installedPattern)

# Fallback: find a table containing typical battery fields if heading is different/translated
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
    Write-Error "Could not locate the Installed batteries table (by heading or typical fields)."
    $headings = [regex]::Matches($htmlNorm, '(?is)<h[1-6][^>]*>(.*?)</h[1-6]>') | ForEach-Object {
        Update-Text $_.Groups[1].Value
    }
    $headings | Set-Content -LiteralPath $DebugInfo -Encoding UTF8
    Write-Warning "Wrote detected headings to $DebugInfo"
    exit 2
}

# --- Extract tbody if present; else parse rows directly ---
$tableHtml  = $sectionMatch.Value
$tbodyMatch = [regex]::Match($tableHtml, '(?is)<tbody\b[^>]*>(.*?)</tbody>')
$rowsHtml   = if ($tbodyMatch.Success) { $tbodyMatch.Groups[1].Value } else { $tableHtml }

$rowMatches = [regex]::Matches($rowsHtml, '(?is)<tr\b[^>]*>(.*?)</tr>')
if ($rowMatches.Count -eq 0) {
    Write-Error "Installed batteries table has no <tr> rows."
    exit 3
}

# --- Parse into battery objects and compute health ---
$batteries = New-Object System.Collections.Generic.List[object]
$current   = [ordered]@{}
$startKeys = @('manufacturer','serialNumber','name','batteryName')

foreach ($rm in $rowMatches) {
    $rowInner    = $rm.Groups[1].Value
    $cellMatches = [regex]::Matches($rowInner, '(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')
    if ($cellMatches.Count -eq 0) { continue }

    if ($cellMatches.Count -eq 2) {
        $label = Update-Text $cellMatches[0].Groups[1].Value
        $value = Update-Text $cellMatches[1].Groups[1].Value

        $key = Update-CamelKey $label
        if ([string]::IsNullOrWhiteSpace($key)) { continue }

        # Start a new battery object if a repeated start key appears (multi-battery heuristic)
        if ($startKeys -contains $key -and $current.Contains($key)) {
            # compute health for current before committing
            $dc = if ($current.Contains('designCapacity')) { Get-mWh $current['designCapacity'] } else { $null }
            $fc = if ($current.Contains('fullChargeCapacity')) { Get-mWh $current['fullChargeCapacity'] } else { $null }
            if ($dc -and $fc -and $dc -gt 0) {
                $current['designCapacity_mWh']     = $dc
                $current['fullChargeCapacity_mWh'] = $fc
                $current['healthRatio']            = [math]::Round($fc / $dc, 4)
                $current['healthPercent']          = [math]::Round(($fc * 100.0) / $dc, 2)
            }
            if ($current.Count -gt 0) { $batteries.Add([PSCustomObject]$current) }
            $current = [ordered]@{}
        }

        $current[$key] = $value
    }
    else {
        # Multi-column rows: capture generically
        $vals = @()
        foreach ($cm in $cellMatches) { $vals += (Update-Text $cm.Groups[1].Value) }
        if ($vals.Count -gt 0) {
            if (-not $current.Contains('rows')) { $current['rows'] = New-Object System.Collections.Generic.List[object] }
            $current['rows'].Add($vals)
        }
    }
}

# compute health for the last battery
if ($current.Count -gt 0) {
    $dc = if ($current.Contains('designCapacity')) { Get-mWh $current['designCapacity'] } else { $null }
    $fc = if ($current.Contains('fullChargeCapacity')) { Get-mWh $current['fullChargeCapacity'] } else { $null }
    if ($dc -and $fc -and $dc -gt 0) {
        $current['designCapacity_mWh']     = $dc
        $current['fullChargeCapacity_mWh'] = $fc
        $current['healthRatio']            = [math]::Round($fc / $dc, 4)
        $current['healthPercent']          = [math]::Round(($fc * 100.0) / $dc, 2)
    }
    $batteries.Add([PSCustomObject]$current)
}

if ($batteries.Count -eq 0) {
    Write-Error "No battery data parsed under Installed batteries."
    exit 4
}

# --- Output JSON ---
$dir = Split-Path -Parent $OutputJson
if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$json = $batteries | ConvertTo-Json -Depth 6
Set-Content -LiteralPath $OutputJson -Value $json -Encoding UTF8

Write-Host "Exported JSON with health metrics to $OutputJson"
Write-Host $json
