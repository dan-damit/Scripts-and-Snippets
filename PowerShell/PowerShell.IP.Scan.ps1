<# PSScriptInfo

Author: Dan.Damit (annotated) (https://github.com/dan-damit)
Synchronous CIDR scanner with ETA and smoothed progress banner
Adding reversedns queries for hostname and http header detection

Created: 2025.06.04
Last Modified: 2025.11.10
#>

# Func to build array of IPs
function Get-IPsFromCIDR {
    param([string]$cidr)
    # Split into IPs and prefix
    $parts = $cidr -split '/'
    $baseIP = $parts[0]; $prefix = [int]$parts[1]
    $ipBytes = [System.Net.IPAddress]::Parse($baseIP).GetAddressBytes()
    [Array]::Reverse($ipBytes); $ipInt = [BitConverter]::ToUInt32($ipBytes,0)
    $hostBits = 32 - $prefix; $numHosts = [math]::Pow(2, $hostBits) - 2
    if ($numHosts -lt 1) { return @() }
    $startIP = $ipInt + 1
    $list = for ($i=0; $i -lt $numHosts; $i++) {
        $cur = $startIP + $i; $b = [BitConverter]::GetBytes($cur); [Array]::Reverse($b)
        [System.Net.IPAddress]::Parse(($b -join '.')).ToString()
    }
    return ,$list
}

# Func to show progress banner with new ETA calculation
function Show-ProgressBanner {
    param(
        [int]$current,
        [int]$total,
        [double]$displayPct,
        [TimeSpan]$eta
    )
    $width = 48
    $percent = [math]::Round($displayPct)
    $filled = [math]::Floor(($percent / 100) * $width)
    $bar = ('#' * $filled).PadRight($width)
    $etaText = if ($eta.TotalSeconds -le 0) { '00:00:00' } else { $eta.ToString("hh\:mm\:ss") }
    Write-Host -NoNewline "`rBanner: [$bar] $percent% ($current/$total) ETA: $etaText"
}

# Func to grab hostname from reverse dns zone
function Get-ReverseDns {
    param([string]$ip)
    try { (Resolve-DnsName -Name $ip -ErrorAction Stop -Type PTR).NameHost } catch { $null }
}

# Func to see if host has http banner
function Get-HttpInfo {
    param([string]$ip, [int]$port = 80, [int]$timeoutMs = 1000)
    try {
        $req = [System.Net.WebRequest]::Create("http://$ip`:$port/")
        $req.Timeout = $timeoutMs
        $req.Method = "HEAD"
        $resp = $req.GetResponse()
        $headers = @{}
        $resp.Headers | ForEach-Object { $headers[$_.Key] = $_.Value }
        $resp.Close()
        return $headers
    } catch { return $null }
}

# --------- main flow (with ETA + smoothing) ----------
$cidr = Read-Host "Enter CIDR block (e.g., 192.168.1.0/24)"
$ips = Get-IPsFromCIDR $cidr
if ($ips.Count -eq 0) { Write-Host "No hosts to scan for $cidr"; return }

# Tunables
$pingTimeoutMs = 600          # per-host ping timeout
$ewmaAlpha = 0.15             # EWMA alpha for average per-host duration (0..1). Higher = more reactive.
$displayAlpha = 0.10          # smoothing alpha for displayed percent (0..1). Lower = smoother.

$total = $ips.Count
Write-Host "Starting scan of $total IPs..."

$ping = New-Object System.Net.NetworkInformation.Ping

# state
$current = 0
$online = 0
$avgHostMs = 0.0              # EWMA of host duration in ms (starts at 0)
$displayPct = 0.0             # smoothed displayed percent
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($ip in $ips) {
    $hostSw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $reply = $ping.Send($ip, $pingTimeoutMs)
        if ($reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            Write-Host "`n$ip is online (time=${($reply.RoundtripTime)}ms)"
            $online++
        }
    } catch {
        # ignore; treat as no response
    } finally {
        $hostSw.Stop()
        $durMs = $hostSw.Elapsed.TotalMilliseconds

        # update EWMA for per-host duration; initialize on first sample
        if ($avgHostMs -le 0) { $avgHostMs = $durMs } else { $avgHostMs = ($ewmaAlpha * $durMs) + ((1 - $ewmaAlpha) * $avgHostMs) }

        $current++

        # actual percent
        $actualPct = if ($total -gt 0) { ($current / $total) * 100 } else { 100 }

        # smooth the displayed percent toward actual percent
        $displayPct = ($displayAlpha * $actualPct) + ((1 - $displayAlpha) * $displayPct)

        # estimate remaining time using EWMA per-host duration
        $remaining = $total - $current
        $etaMs = [math]::Max(0, $avgHostMs * $remaining)
        $eta = [TimeSpan]::FromMilliseconds($etaMs)

        Show-ProgressBanner $current $total $displayPct $eta
    }
}

# finalize banner and summary
$displayPct = 100
Show-ProgressBanner $total $total $displayPct ([TimeSpan]::Zero)
Write-Host "`nScan complete! $online hosts responded. Elapsed: $($stopwatch.Elapsed.ToString("hh\:mm\:ss"))"