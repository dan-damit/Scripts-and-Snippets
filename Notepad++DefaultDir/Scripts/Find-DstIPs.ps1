$logPath = "C:\Users\ddamit\Downloads\fortianalyzer-traffic-forward-2026_03_30.log"
$printPorts = @(9100, 445, 631, 515)

function ConvertFrom-FortiLine {
    param([Parameter(Mandatory)][string]$Line)
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

$dstCounts = @{}

Get-Content $logPath -ReadCount 5000 | ForEach-Object {
    foreach ($line in $_) {

        # Cheap pre-filter: only lines that have dstport and one of our print ports
        if ($line -notmatch 'dstport=') { continue }
        if (-not ($printPorts | Where-Object { $line -match "dstport=$($_)(\D|$)" })) { continue }

        $o = ConvertFrom-FortiLine $line
        if (-not $o.dstip) { continue }

        $dstCounts[$o.dstip] = 1 + ($dstCounts[$o.dstip] | ForEach-Object { $_ } )
    }
}

$dstCounts.GetEnumerator() |
Sort-Object Value -Descending |
Select-Object @{n = 'DstIP'; e = { $_.Key } }, @{n = 'Hits'; e = { $_.Value } } |
Format-Table -AutoSize

$TargetDstIPs = @(
    "10.100.30.7"     # keep this
    # add any other DstIPs you discover above (e.g., LB VIP)
)

$targetHits = New-Object System.Collections.Generic.List[object]

Get-Content $logPath -ReadCount 5000 | ForEach-Object {
    foreach ($line in $_) {
        # cheap check: skip parsing unless it contains dstip=
        if ($line -notmatch 'dstip=') { continue }

        foreach ($ip in $TargetDstIPs) {
            if ($line -match "dstip=$([regex]::Escape($ip))(\s|$)") {
                $targetHits.Add((ConvertFrom-FortiLine $line))
                break
            }
        }
    }
}

$targetHits.Count
($targetHits | Select-Object -First 1).PSObject.Properties.Name | Sort-Object

$targetHits |
Where-Object { $_.action -eq 'accept' } |
Group-Object policyid |
Sort-Object Count -Descending |
Format-Table Name, Count -AutoSize

$EpicorPolicyIds = @("123", "456")   # fill in after the grouping output
$printPorts = @(9100, 445, 631, 515)

$epicorTalkers =
$targetHits |
Where-Object {
    $_.action -eq 'accept' -and
    $_.policyid -in $EpicorPolicyIds -and
    $_.srcip -and
    $_.dstip -and
    $_.srcip -ne $_.dstip -and
    (-not $_.dstport -or ($printPorts -contains [int]$_.dstport))
} |
Group-Object srcip |
Sort-Object Count -Descending |
Select-Object @{n = 'EpicorSrcIP'; e = { $_.Name } }, @{n = 'Hits'; e = { $_.Count } }

$epicorTalkers | Format-Table -AutoSize

$one = $targetHits | Select-Object -First 20
$one | ForEach-Object {
    $_.PSObject.Properties | Where-Object {
        $_.Value -match '^\d{1,3}(\.\d{1,3}){3}$' -and
        $_.Value -notmatch '^10\.' -and
        $_.Value -notmatch '^192\.168\.' -and
        $_.Value -notmatch '^172\.(1[6-9]|2\d|3[0-1])\.'
    } | Select-Object Name, Value
} | Select-Object -First 40

$targetHits |
Where-Object { $_.action -eq 'accept' } |
Group-Object policyid |
Sort-Object Count -Descending |
ForEach-Object {
    $sample = $_.Group | Select-Object -First 1
    [pscustomobject]@{
        PolicyId   = $_.Name
        Hits       = $_.Count
        PolicyName = $sample.policyname
        SrcIntfTop = ($_.Group | Group-Object srcintf | Sort-Object Count -Descending | Select-Object -First 1).Name
        VpnTypeTop = ($_.Group | Group-Object vpntype | Sort-Object Count -Descending | Select-Object -First 1).Name
    }
} |
Format-Table -AutoSize

$targets = '10.3.70.204', '10.100.30.7'

$targetHits |
Where-Object { $_.dstip -in $targets -and $_.action -eq 'accept' } |
Group-Object dstip |
ForEach-Object {
    $ip = $_.Name
    $ports = $_.Group | Group-Object dstport | Sort-Object Count -Descending |
    Select-Object -First 8 @{n = 'DstPort'; e = { $_.Name } }, @{n = 'Hits'; e = { $_.Count } }
    "`n=== $ip ==="
    $ports | Format-Table -AutoSize | Out-String
} | Out-Host

$EpicorPolicyIds = @('4')
$PrintTargets = @('10.3.70.204', '10.100.30.7')

function Test-PrivateIPv4 {
    param([Parameter(Mandatory)][string]$IP)
    if ($IP -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return $false }

    $b = $IP.Split('.') | ForEach-Object { [int]$_ }
    # 10.0.0.0/8
    if ($b[0] -eq 10) { return $true }
    # 172.16.0.0/12
    if ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) { return $true }
    # 192.168.0.0/16
    if ($b[0] -eq 192 -and $b[1] -eq 168) { return $true }

    return $false
}

$EpicorPolicyIds = @('4')  # <-- replace after policy mapping
$PrintTargets = @('10.3.70.204', '10.100.30.7')

# Optional: tighten to "more likely printing"
$PrintPorts = @(9100, 515, 631, 445)   # you can reduce to 9100 if that’s dominant

$epicorPublic =
$targetHits |
Where-Object {
    $_.action -eq 'accept' -and
    $_.policyid -in $EpicorPolicyIds -and
    $_.dstip -in $PrintTargets -and
    $_.dstport -and ([int]$_.dstport) -in $PrintPorts -and
    $_.srcip -and (-not (Test-PrivateIPv4 $_.srcip))
} |
Group-Object srcip |
Sort-Object Count -Descending |
Select-Object @{n = 'EpicorPublicIP'; e = { $_.Name } },
@{n = 'Hits'; e = { $_.Count } }

$epicorPublic | Format-Table -AutoSize

$targetHits |
Where-Object {
    $_.action -eq 'accept' -and
    $_.policyid -in $EpicorPolicyIds -and
    $_.dstip -in $PrintTargets -and
    $_.srcip -and (-not (Test-PrivateIPv4 $_.srcip))
} |
Group-Object srcip, dstip, dstport |
Sort-Object Count -Descending |
Select-Object @{n = 'SrcIP'; e = { $_.Name.Split(',')[0].Trim() } },
@{n = 'DstIP'; e = { $_.Name.Split(',')[1].Trim() } },
@{n = 'DstPort'; e = { $_.Name.Split(',')[2].Trim() } },
Count |
Format-Table -AutoSize

$targetHits |
Where-Object { $_.dstip -eq '10.3.70.204' -and $_.action -eq 'accept' } |
Select-Object -First 10 date, time, srcip, srcintf, dstip, dstport, service, policyid, policyname, trandisp, dstintf, vpntype |
Format-Table -AutoSize