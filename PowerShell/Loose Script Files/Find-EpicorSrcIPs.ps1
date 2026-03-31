<#
.SYNOPSIS
    Analyze FortiGate/FortiAnalyzer traffic logs to find Epicor source IPs and
    target services.

.DESCRIPTION
    Performs one or two passes over FortiGate/FortiAnalyzer logs: 1) Optional
        discovery pass to identify top destination IPs for selected ports. 2)
        Aggregation pass to report policy activity and Epicor source talkers.

    Key behavior: - Supports DNAT-aware destination matching using
        tranip/tranport. - Filters to public source IPs by default. - Can use
        transip as effective source when srcip is private. - Produces console
        summaries and CSV exports (policy, source, hourly, date, top tuples).

.PARAMETER LogPath
    Path to the FortiGate/FortiAnalyzer log file.

.PARAMETER PrintPorts
    Ports of interest used for discovery and filtering. Defaults to 9100, 515,
    631, and 445.

.PARAMETER TargetDstIPs
    Destination IPs to include in pass 2. If omitted, pass 1 discovers top
    targets based on IncludeTopDstIPs.

.PARAMETER IncludeTopDstIPs
    Number of discovered destination IPs to carry into pass 2 when TargetDstIPs
    is not provided.

.PARAMETER Action
    Optional action filter (for example: accept, deny).

.PARAMETER Subtype
    Optional subtype filter. Defaults to forward.

.PARAMETER EpicorPolicyIds
    Policy IDs treated as Epicor traffic for source talker reports. If omitted,
    auto-detection is attempted using policy/interface regex filters.

.PARAMETER EpicorPolicyNameRegex
    Regex used to detect Epicor-related policy names when EpicorPolicyIds is not
    supplied.

.PARAMETER EpicorSrcIntfRegex
    Regex used to detect Epicor-related source interfaces when EpicorPolicyIds
    is not supplied.

.PARAMETER IncludePrivateSources
    Includes RFC1918 source IPs. By default, private sources are excluded.

.PARAMETER UseTransIpAsSourceWhenPublic
    If srcip is private and transip is public, uses transip as the effective
    source IP.

.PARAMETER UseTranIP
    For DNAT records (trandisp=dnat), uses tranip as the effective destination
    IP.

.PARAMETER UseTranPort
    For DNAT records (trandisp=dnat), uses tranport as the effective destination
    port.

.PARAMETER ShowHourlyBreakdown
    Enables/disables per-hour output for Epicor sources.

.PARAMETER MaxHourlyRows
    Maximum rows shown in the hourly table output.

.PARAMETER ReadCount
    Number of lines read per batch from the log file.

.PARAMETER ProgressEvery
    Progress update interval in processed lines.

.EXAMPLE
    .\Find-EpicorSrcIPs.ps1 -LogPath C:\Temp\traffic.log -UseTranIP -UseTranPort

    Discovers top destination IPs, then analyzes matching records with DNAT-aware destination fields.

.EXAMPLE
    .\Find-EpicorSrcIPs.ps1 -LogPath C:\Temp\traffic.log -TargetDstIPs 10.1.2.3,10.1.2.4 -EpicorPolicyIds 7

    Skips discovery, analyzes only provided targets, and reports Epicor talkers for policy 7.

.OUTPUTS
    Console tables and CSV files under C:\Temp\EpicorLogReports_<timestamp>.

.NOTES
    Effective destination fields: - IP:   tranip (when UseTranIP and
        trandisp=dnat) else dstip - Port: tranport (when UseTranPort and
        trandisp=dnat), then dstport/pdstport fallback
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$LogPath,

    # Ports of interest (not just printing; used for discovery/filtering)
    [int[]]$PrintPorts = @(9100, 515, 631, 445),

    # If not provided, Pass 1 discovers top targets
    [string[]]$TargetDstIPs,

    [ValidateRange(1, 50)]
    [int]$IncludeTopDstIPs = 5,

    # Post-parse filters (pass $null to disable)
    [string]$Action = $null,
    [string]$Subtype = 'forward',

    # Epicor identification (optional; if omitted we try regex auto-detect from policy summary)
    [string[]]$EpicorPolicyIds,
    [string]$EpicorPolicyNameRegex = 'Epicor|ADVPN|SecureCrimp',
    [string]$EpicorSrcIntfRegex = 'ADVPN|Epicor|port1|WAN',

    # Default behavior = only public sources
    [switch]$IncludePrivateSources,

    # If srcip is private but transip exists and is public, use transip as the effective source
    [switch]$UseTransIpAsSourceWhenPublic,

    # DNAT helpers: treat tranip/tranport as the effective destination (recommended for policy 7)
    [switch]$UseTranIP,
    [switch]$UseTranPort,

    # NEW: Hourly output controls
    [bool]$ShowHourlyBreakdown = $true,
    [ValidateRange(1, 500000)]
    [int]$MaxHourlyRows = 5000,

    # Performance knobs
    [ValidateRange(100, 200000)]
    [int]$ReadCount = 5000,

    [ValidateRange(1000, 5000000)]
    [int]$ProgressEvery = 50000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helpers

function Write-Info {
    param([string]$Message)
    $ts = (Get-Date).ToString('HH:mm:ss')
    Write-Host "[$ts] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    $ts = (Get-Date).ToString('HH:mm:ss')
    Write-Host "[$ts] WARNING: $Message" -ForegroundColor Yellow
}

function ConvertFrom-FortiLine {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Line)

    # key=value OR key="value with spaces"
    $rx = [regex]'(\w+)=("([^"\\]*(\\.[^"\\]*)*)"|[^\s]+)'
    $ht = [ordered]@{}

    foreach ($m in $rx.Matches($Line)) {
        $k = $m.Groups[1].Value
        $v = $m.Groups[2].Value
        if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Trim('"') }
        $ht[$k] = $v
    }

    [pscustomobject]$ht
}

function Add-Count {
    param(
        [Parameter(Mandatory)][hashtable]$Table,
        [Parameter(Mandatory)][string]$Key,
        [int]$Increment = 1
    )
    if (-not $Table.ContainsKey($Key)) { $Table[$Key] = 0 }
    $Table[$Key] += $Increment
}

function Test-PrivateIPv4 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$IP)

    if ($IP -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return $false }

    $b = $IP.Split('.') | ForEach-Object { [int]$_ }
    if ($b[0] -eq 10) { return $true }
    if ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) { return $true }
    if ($b[0] -eq 192 -and $b[1] -eq 168) { return $true }
    return $false
}

function Get-EffectiveSourceIP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Record,
        [switch]$PreferTransIpIfPublic
    )

    $src = $Record.srcip
    if (-not $PreferTransIpIfPublic) { return $src }

    if ($src -and (Test-PrivateIPv4 $src) -and $Record.transip) {
        $t = $Record.transip
        if ($t -match '^\d{1,3}(\.\d{1,3}){3}$' -and -not (Test-PrivateIPv4 $t)) {
            return $t
        }
    }

    return $src
}

function Get-EffectiveDestination {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Record,
        [switch]$PreferTranIP,
        [switch]$PreferTranPort
    )

    $isDnat = ($Record.trandisp -eq 'dnat')

    $dstIP =
    if ($PreferTranIP -and $isDnat -and $Record.tranip) { $Record.tranip }
    else { $Record.dstip }

    $dstPort =
    if ($PreferTranPort -and $isDnat -and $Record.tranport) { $Record.tranport }
    elseif ($Record.dstport) { $Record.dstport }
    elseif ($Record.pdstport) { $Record.pdstport }
    elseif ($Record.tranport) { $Record.tranport }
    else { $null }

    [pscustomobject]@{
        IP     = $dstIP
        Port   = $dstPort
        IsDnat = $isDnat
    }
}

function ConvertTo-IPv4SortKey {
    param([Parameter(Mandatory)][string]$IP)

    # Numeric sort key for IPv4 (fallback for non-IPv4 -> sorts last)
    if ($IP -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return [uint32]::MaxValue }

    try {
        $bytes = [System.Net.IPAddress]::Parse($IP).GetAddressBytes()

        # Ensure it's IPv4 (4 bytes). If IPv6 sneaks in, sort last.
        if ($bytes.Count -ne 4) { return [uint32]::MaxValue }

        # Convert to UInt32 in host order (big-endian bytes to numeric)
        return ([uint32]$bytes[0] -shl 24) -bor
        ([uint32]$bytes[1] -shl 16) -bor
        ([uint32]$bytes[2] -shl 8) -bor
        ([uint32]$bytes[3])
    }
    catch {
        return [uint32]::MaxValue
    }
}

function Export-Table {
    param(
        [Parameter(Mandatory)][object]$Data,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$BaseFolder
    )

    if (-not (Test-Path -LiteralPath $BaseFolder)) {
        New-Item -Path $BaseFolder -ItemType Directory | Out-Null
    }

    $safeName = ($Name -replace '[^a-zA-Z0-9_\-]+', '_').Trim('_')
    $path = Join-Path -Path $BaseFolder -ChildPath "$safeName.csv"

    $Data | Export-Csv -Path $path -NoTypeInformation -Force
    Write-Host "Exported: $path" -ForegroundColor Cyan
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path -Path "C:\Temp\" -ChildPath "EpicorLogReports_$stamp"

#endregion Helpers

#region Validation

if (-not (Test-Path -LiteralPath $LogPath)) {
    throw "Log file not found: $LogPath"
}

Write-Info "LogPath: $LogPath"
Write-Info ("Ports of interest: " + ($PrintPorts -join ', '))
Write-Info ("UseTranIP: {0} | UseTranPort: {1}" -f [bool]$UseTranIP, [bool]$UseTranPort)

#endregion Validation

#region Build fast port regex (dstport/pdstport/tranport)

$portsAlt = ($PrintPorts | ForEach-Object { [regex]::Escape([string]$_) }) -join '|'
$portRegex = "(?:dstport|pdstport|tranport)=(?:$portsAlt)(?:\D|$)"

#endregion

#region Pass 1: Discover target destination IPs (effective IP based on UseTranIP)

$dstCounts = @{}

if (-not $TargetDstIPs -or $TargetDstIPs.Count -eq 0) {
    Write-Info "Pass 1: Discovering top destination IPs for selected ports..."

    $lines = 0

    Get-Content -LiteralPath $LogPath -ReadCount $ReadCount | ForEach-Object {
        foreach ($line in $_) {
            $lines++

            if (($lines % $ProgressEvery) -eq 0) {
                Write-Info "Pass 1 progress: processed ~ $lines lines..."
            }

            if ($line -notmatch $portRegex) { continue }

            $o = ConvertFrom-FortiLine $line

            if ($Subtype -and $o.subtype -ne $Subtype) { continue }
            if ($Action -and $o.action -ne $Action) { continue }

            $eff = Get-EffectiveDestination -Record $o -PreferTranIP:$UseTranIP -PreferTranPort:$UseTranPort
            if (-not $eff.IP) { continue }

            Add-Count -Table $dstCounts -Key $eff.IP
        }
    }

    if ($dstCounts.Count -eq 0) {
        Write-Warn "Pass 1 found ZERO matches. Likely wrong ports for this dataset."
        throw "No targets discovered in Pass 1. Aborting before Pass 2."
    }

    $TargetDstIPs = $dstCounts.GetEnumerator() |
    Sort-Object Value -Descending |
    Select-Object -First $IncludeTopDstIPs |
    ForEach-Object { $_.Key }

    Write-Info ("Top discovered destination IPs (targets): " + ($TargetDstIPs -join ', '))

    $dstCounts.GetEnumerator() |
    Sort-Object Value -Descending |
    Select-Object -First 30 @{n = 'DstIP'; e = { $_.Key } }, @{n = 'Hits'; e = { $_.Value } } |
    Format-Table -AutoSize
}
else {
    Write-Info ("Targets provided: " + ($TargetDstIPs -join ', '))
}

#endregion Pass 1

#region Pass 2: Parse + aggregate only records whose effective destination IP is in TargetDstIPs

Write-Info "Pass 2: Parsing and aggregating target destination records..."

$policyCounts = @{}
$policySample = @{}
$srcCountsByPolicy = @{}
$detailCounts = @{}
$hourOfDayBySrc = @{}
$dateBySrc = @{}
$allProps = [System.Collections.Generic.HashSet[string]]::new()

# NEW: Hourly aggregations
$hourCountsByPolicy = @{}   # policyId -> ( "src|hour" -> hits )
$srcFirstSeen = @{}   # src -> datetime
$srcLastSeen = @{}   # src -> datetime

$targetSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$TargetDstIPs)

$lines2 = 0
$matched = 0

Get-Content -LiteralPath $LogPath -ReadCount $ReadCount | ForEach-Object {
    foreach ($line in $_) {
        $lines2++

        if (($lines2 % $ProgressEvery) -eq 0) {
            Write-Info "Pass 2 progress: processed ~ $lines2 lines, matched ~ $matched target records..."
        }

        if ($line -notmatch $portRegex) { continue }

        $o = ConvertFrom-FortiLine $line

        foreach ($pn in $o.PSObject.Properties.Name) { [void]$allProps.Add($pn) }

        if ($Subtype -and $o.subtype -ne $Subtype) { continue }
        if ($Action -and $o.action -ne $Action) { continue }

        $eff = Get-EffectiveDestination -Record $o -PreferTranIP:$UseTranIP -PreferTranPort:$UseTranPort
        if (-not $eff.IP) { continue }
        if (-not $targetSet.Contains([string]$eff.IP)) { continue }

        if ($PrintPorts -and $eff.Port) {
            try {
                $p = [int]$eff.Port
                if ($PrintPorts -notcontains $p) { continue }
            }
            catch { }
        }

        $matched++

        $policyId = if ($o.policyid) { [string]$o.policyid } else { '<no-policyid>' }
        Add-Count -Table $policyCounts -Key $policyId

        if (-not $policySample.ContainsKey($policyId)) {
            $policySample[$policyId] = [pscustomobject]@{
                PolicyId   = $policyId
                PolicyName = $o.policyname
                SrcIntf    = $o.srcintf
                DstIntf    = $o.dstintf
            }
        }

        $src = Get-EffectiveSourceIP -Record $o -PreferTransIpIfPublic:$UseTransIpAsSourceWhenPublic
        if (-not $src) { continue }

        # Default = filter OUT private RFC1918 sources unless explicitly included
        if (-not $IncludePrivateSources) {
            if ($src -match '^\d{1,3}(\.\d{1,3}){3}$' -and (Test-PrivateIPv4 $src)) { continue }
        }

        # per-policy source counts
        if (-not $srcCountsByPolicy.ContainsKey($policyId)) { $srcCountsByPolicy[$policyId] = @{} }
        Add-Count -Table $srcCountsByPolicy[$policyId] -Key $src

        # detail breakdown: src|effectiveDstIP|effectiveDstPort
        $portKey = if ($eff.Port) { [string]$eff.Port } else { '<no-port>' }
        $detailKey = "$src|$($eff.IP)|$portKey"
        Add-Count -Table $detailCounts -Key $detailKey

        # Parse record datetime and bucket by hour-of-day (0..23)
        $dt = $null
        if ($o.date -and $o.time) {
            try {
                $dt = [datetime]::ParseExact(
                    "$($o.date) $($o.time)",
                    'yyyy-MM-dd HH:mm:ss',
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            }
            catch {
                $dt = $null
            }
        }

        if ($dt) {
            $h = $dt.Hour  # 0..23

            if (-not $hourOfDayBySrc.ContainsKey($src)) {
                $hourOfDayBySrc[$src] = @{}
            }
            if (-not $hourOfDayBySrc[$src].ContainsKey($h)) {
                $hourOfDayBySrc[$src][$h] = 0
            }
            $hourOfDayBySrc[$src][$h]++
        }

        if ($dt) {
            $dateKey = $dt.ToString('yyyy-MM-dd')

            if (-not $dateBySrc.ContainsKey($src)) {
                $dateBySrc[$src] = @{}
            }
            if (-not $dateBySrc[$src].ContainsKey($dateKey)) {
                $dateBySrc[$src][$dateKey] = 0
            }

            $dateBySrc[$src][$dateKey]++
        }

    }
}

Write-Info "Pass 2 complete: processed ~ $lines2 lines, matched ~ $matched target records."

#endregion Pass 2

#region Policy summary

Write-Info "Policy summary (targets only):"

$policySummary =
$policyCounts.GetEnumerator() |
Sort-Object Value -Descending |
ForEach-Object {
    $policyId = $_.Key
    $hits = $_.Value
    $s = $policySample[$policyId]

    [pscustomobject]@{
        PolicyId   = $policyId
        Hits       = $hits
        PolicyName = $s.PolicyName
        SrcIntf    = $s.SrcIntf
        DstIntf    = $s.DstIntf
    }
}

$policySummary | Format-Table -AutoSize

#endregion Policy summary

#region Auto-detect Epicor policies (if not specified)

if (-not $EpicorPolicyIds -or $EpicorPolicyIds.Count -eq 0) {
    Write-Warn "EpicorPolicyIds not supplied; attempting auto-detection using regexes..."
    Write-Info  "EpicorPolicyNameRegex: $EpicorPolicyNameRegex"
    Write-Info  "EpicorSrcIntfRegex:    $EpicorSrcIntfRegex"

    $candidates =
    $policySummary |
    Where-Object {
        ($_.PolicyName -and $_.PolicyName -match $EpicorPolicyNameRegex) -or
        ($_.SrcIntf -and $_.SrcIntf -match $EpicorSrcIntfRegex)
    } |
    Sort-Object Hits -Descending

    if ($candidates.Count -gt 0) {
        $EpicorPolicyIds = @([string]$candidates[0].PolicyId)
        Write-Info "Auto-detected EpicorPolicyIds: $($EpicorPolicyIds -join ', ')"
    }
    else {
        Write-Warn "Auto-detection failed. Supply -EpicorPolicyIds <id> after reviewing policy summary."
        $EpicorPolicyIds = @()
    }
}
else {
    Write-Info "EpicorPolicyIds provided: $($EpicorPolicyIds -join ', ')"
}

#endregion Auto-detect

#region Epicor talker report + Hourly report

if ($EpicorPolicyIds.Count -gt 0) {

    # Total hits per IP (across selected Epicor policies)
    $epicorSrcCounts = @{}

    foreach ($policyId in $EpicorPolicyIds) {
        if ($srcCountsByPolicy.ContainsKey($policyId)) {
            foreach ($kvp in $srcCountsByPolicy[$policyId].GetEnumerator()) {
                Add-Count -Table $epicorSrcCounts -Key $kvp.Key -Increment $kvp.Value
            }
        }
    }

    Write-Info "Epicor source IP summary (TotalHits, FirstSeen, LastSeen, PeakHourOfDay):"

    $epicorSummary =
    $epicorSrcCounts.GetEnumerator() |
    ForEach-Object {
        $src = $_.Key

        # Default peak values
        $peakHourOfDay = $null
        $peakHourHits = $null

        if ($hourOfDayBySrc.ContainsKey($src) -and $hourOfDayBySrc[$src].Count -gt 0) {
            $peak = $hourOfDayBySrc[$src].GetEnumerator() |
            Sort-Object Value -Descending |
            Select-Object -First 1

            $peakHourOfDay = ("{0:D2}:00" -f [int]$peak.Key)
            $peakHourHits = [int]$peak.Value
        }

        [pscustomobject]@{
            EpicorSourceIP = $src
            TotalHits      = $_.Value
            FirstSeen      = if ($srcFirstSeen.ContainsKey($src)) { $srcFirstSeen[$src] } else { $null }
            LastSeen       = if ($srcLastSeen.ContainsKey($src)) { $srcLastSeen[$src] }  else { $null }
            PeakHourOfDay  = $peakHourOfDay
            PeakHourHits   = $peakHourHits
        }
    } |
    Sort-Object @{ Expression = { ConvertTo-IPv4SortKey $_.EpicorSourceIP } }

    # Display summary in console
    $epicorSummary | Format-Table -AutoSize

    if ($ShowHourlyBreakdown) {
        Write-Info "Hits per hour per IP (Epicor policies only):"

        $hourRows = New-Object System.Collections.Generic.List[object]

        foreach ($policyId in $EpicorPolicyIds) {
            if (-not $hourCountsByPolicy.ContainsKey($policyId)) { continue }

            foreach ($kvp in $hourCountsByPolicy[$policyId].GetEnumerator()) {
                $parts = $kvp.Key.Split('|', 2)
                $src = $parts[0]
                $hourStr = $parts[1]

                # Convert hour string back to datetime for sorting/formatting
                $hourDt = $null
                try {
                    $hourDt = [datetime]::ParseExact(
                        $hourStr,
                        'yyyy-MM-dd HH\:00',
                        [System.Globalization.CultureInfo]::InvariantCulture
                    )
                }
                catch {}

                $hourRows.Add([pscustomobject]@{
                        SrcIP     = $src
                        HourStart = $hourDt
                        Hits      = $kvp.Value
                        PolicyId  = $policyId
                    }) | Out-Null
            }
        }

        $hourRows |
        Sort-Object @{Expression = { ConvertTo-IPv4SortKey $_.SrcIP } }, HourStart |
        Select-Object -First $MaxHourlyRows SrcIP, HourStart, Hits |
        Format-Table -AutoSize
    }

    # Top (src,dst,port) breakdown (effective destination)
    Write-Info "Top (src,dst,port) breakdown (effective destination):"

    $topBreakdown =
    $detailCounts.GetEnumerator() |
    ForEach-Object {
        $p = $_.Key.Split('|')
        [pscustomobject]@{
            SrcIP   = $p[0]
            DstIP   = $p[1]
            DstPort = $p[2]
            Hits    = $_.Value
        }
    } |
    Sort-Object @{Expression = { ConvertTo-IPv4SortKey $_.SrcIP } }, DstIP, DstPort |
    Select-Object -First 40

    $topBreakdown | Format-Table -AutoSize

    # Pivot table of hits per hour of day (0-23) per IP for Epicor talkers
    Write-Info "Pivot: Hits per hour of day per Epicor IP (rows=IP, cols=00-23):"

    $hours = 0..23

    $pivotRows =
    $epicorSrcCounts.Keys |
    Sort-Object { ConvertTo-IPv4SortKey $_ } |
    ForEach-Object {
        $src = $_
        $row = [ordered]@{ SrcIP = $src }

        foreach ($h in $hours) {
            $col = "{0:D2}" -f $h
            $row[$col] = if ($hourOfDayBySrc.ContainsKey($src) -and $hourOfDayBySrc[$src].ContainsKey($h)) {
                [int]$hourOfDayBySrc[$src][$h]
            }
            else { 0 }
        }

        $row['Total'] = ($hours | ForEach-Object { $row["{0:D2}" -f $_] } | Measure-Object -Sum).Sum
        [pscustomobject]$row
    }

    
    # Build the exact column list: SrcIP, 00..23, Total
    $cols = @('SrcIP') + (0..23 | ForEach-Object { '{0:D2}' -f $_ }) + @('Total')

    # Force table formatting, wrap instead of switching to list
    ($pivotRows |
    Format-Table -Property $cols -AutoSize -Wrap |
    Out-String -Width 4096
) | Write-Host

    # Also show peak hour of day per IP based on $hourOfDayBySrc
    Write-Info "Peak hour of day per Epicor IP (00-23):"

    $peakHourOfDay =
    $hourOfDayBySrc.GetEnumerator() |
    ForEach-Object {
        $src = $_.Key

        # Find the hour with the highest hits for this src
        $peak = $_.Value.GetEnumerator() |
        Sort-Object Value -Descending |
        Select-Object -First 1

        [pscustomobject]@{
            EpicorSourceIP = $src
            PeakHourOfDay  = ("{0:D2}:00" -f [int]$peak.Key)
            PeakHourHits   = [int]$peak.Value
            TotalHits      = $epicorSrcCounts[$src]
        }
    } |
    # Sort by IP (numeric) if you kept ConvertTo-IPv4SortKey helper
    Sort-Object @{Expression = { ConvertTo-IPv4SortKey $_.EpicorSourceIP } }

    $peakHourOfDay | Format-Table -AutoSize

    Write-Info "Hits per date per Epicor IP:"

    # Pivot table of hits per date per IP for Epicor talkers (similar to hourly pivot but by date)
    $dateRows =
    foreach ($src in ($epicorSrcCounts.Keys | Sort-Object { ConvertTo-IPv4SortKey $_ })) {
        if (-not $dateBySrc.ContainsKey($src)) { continue }

        foreach ($date in ($dateBySrc[$src].Keys | Sort-Object)) {
            [pscustomobject]@{
                SrcIP = $src
                Date  = $date
                Hits  = $dateBySrc[$src][$date]
            }
        }
    }

    $dateRows | Format-Table -AutoSize

    # For each Epicor source IP, find the date with the highest hits and create a summary table
    $peakDateRows =
    foreach ($src in ($epicorSrcCounts.Keys | Sort-Object { ConvertTo-IPv4SortKey $_ })) {
        if (-not $dateBySrc.ContainsKey($src)) { continue }

        $peak = $dateBySrc[$src].GetEnumerator() |
        Sort-Object Value -Descending |
        Select-Object -First 1

        [pscustomobject]@{
            SrcIP     = $src
            PeakDate  = $peak.Key
            PeakHits  = [int]$peak.Value
            TotalHits = [int]$epicorSrcCounts[$src]
        }
    }

    # Export results to CSV files
    Export-Table -Data $epicorSummary -Name "Epicor_IP_Summary" -BaseFolder $outDir
    Export-Table -Data $policySummary -Name "Policy_Summary" -BaseFolder $outDir
    Export-Table -Data $pivotRows    -Name "Pivot_HitsByHourOfDay" -BaseFolder $outDir
    Export-Table -Data $dateRows     -Name "Hits_By_Date_Long" -BaseFolder $outDir
    Export-Table -Data $peakDateRows -Name "Peak_Day_Per_IP" -BaseFolder $outDir
    Export-Table -Data $topBreakdown -Name "Top_SrcDstPort" -BaseFolder $outDir
}
else {
    Write-Warn "No EpicorPolicyIds resolved; skipping Epicor talker report."
}

#endregion Epicor talker report + Hourly report

# Debug fields (kept commented like your version)
# Write-Info "Fields observed in parsed target records:"
# $allProps | Sort-Object | ForEach-Object { $_ }