<# PSScriptInfo

Author: Dan.Damit (annotated) (https://github.com/dan-damit)
Simple CIDR scanner with in-line progress banner (synchronous)

Created: 2025.06.04
Last Modified: 2025.11.10
#>

# Generate the list of usable host IPs from a CIDR (excludes network and broadcast)
function Get-IPsFromCIDR {
    param([string]$cidr)

    # split "192.168.1.0/24" -> baseIP and prefix length
    $parts = $cidr -split '/'
    $baseIP = $parts[0]; $prefix = [int]$parts[1]

    # convert dotted IP into UInt32 (network byte order -> reverse to little-endian)
    $ipBytes = [System.Net.IPAddress]::Parse($baseIP).GetAddressBytes()
    [Array]::Reverse($ipBytes)
    $ipInt = [BitConverter]::ToUInt32($ipBytes, 0)

    # compute number of host addresses (exclude network & broadcast)
    $hostBits = 32 - $prefix
    $numHosts = [math]::Pow(2, $hostBits) - 2
    if ($numHosts -lt 1) { return @() }     # nothing to scan for tiny nets

    $startIP = $ipInt + 1                  # first usable host

    # build list of IP strings efficiently
    $list = for ($i = 0; $i -lt $numHosts; $i++) {
        $cur = $startIP + $i
        $b = [BitConverter]::GetBytes($cur); [Array]::Reverse($b)
        [System.Net.IPAddress]::Parse(($b -join '.')).ToString()
    }

    return , $list  # ensure array output
}

# Single-line progress banner; uses CR to overwrite the same console line
function Show-ProgressBanner {
    param($current, $total)
    $width = 48
    $percent = if ($total -gt 0) { [math]::Round(($current / $total) * 100) } else { 0 }
    $filled = [math]::Floor(($percent / 100) * $width)
    $bar = ('#' * $filled).PadRight($width)
    # `r returns cursor to start of current line; -NoNewline avoids newline so next Write-Host prints below
    Write-Host -NoNewline "`rProgress: [$bar] $percent% ($current/$total)"
}

# --------- main flow ----------
$cidr = Read-Host "Enter CIDR block (e.g., 192.168.1.0/24)"   # interactive prompt
$ips = Get-IPsFromCIDR $cidr
if ($ips.Count -eq 0) { Write-Host "No hosts to scan for $cidr"; return }

$total = $ips.Count
Write-Host "Starting scan of $total IPs..."

# Reuse a single Ping instance for efficiency (avoids repeated object creation)
$ping = New-Object System.Net.NetworkInformation.Ping

# State counters
$current = 0
$online = 0

# Synchronous loop: simple, deterministic, easy to debug
foreach ($ip in $ips) {
    try {
        # blocking ICMP probe with a timeout; tune timeout for the network if needed
        $reply = $ping.Send($ip, 600)    # 600ms timeout
        if ($reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            # print result on its own line so the banner remains the only overwritten line
            Write-Host "`n$ip is online (time=${($reply.RoundtripTime)}ms)"
            $online++
        }
    }
    catch {
        # network exceptions treated as no response; keep loop robust
    }
    finally {
        $current++
        Show-ProgressBanner $current $total   # update banner inline
    }
}

# Finalize banner and print summary
Show-ProgressBanner $total $total
Write-Host "`nScan complete! $online hosts responded."