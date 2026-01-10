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
    [Array]::Reverse($ipBytes); $ipInt = [BitConverter]::ToUInt32($ipBytes, 0)
    $hostBits = 32 - $prefix; $numHosts = [math]::Pow(2, $hostBits) - 2
    if ($numHosts -lt 1) { return @() }
    $startIP = $ipInt + 1
    $list = for ($i = 0; $i -lt $numHosts; $i++) {
        $cur = $startIP + $i; $b = [BitConverter]::GetBytes($cur); [Array]::Reverse($b)
        [System.Net.IPAddress]::Parse(($b -join '.')).ToString()
    }
    return , $list
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
    Write-Host -NoNewline "`rProgress: [$bar] $percent% ($current/$total) ETA: $etaText" -ForegroundColor Yellow
}

# Func to grab hostname from reverse dns zone
function Get-ReverseDns {
    param([string]$ip)
    try { (Resolve-DnsName -Name $ip -ErrorAction Stop -Type PTR).NameHost } catch { $null }
}

# Func to query NetBIOS name via nbtstat (Windows-only, local subnet)
function Get-NetbiosName {
    param([string]$ip)
    try {
        $output = & nbtstat -A $ip 2>$null
        if ($output) {
            $line = $output | Select-String "<00>" -First 1
            if ($line) {
                # Extract name from line like: "DESKTOP-ABC123 <00> UNIQUE Registered"
                return ($line -split '\s+')[0]
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

# Func to attempt mDNS resolution (e.g., for .local hostnames)
function Get-MdnsName {
    param([string]$ip)
    try {
        # Use ping to get the .local name from ARP cache (if available)
        $arpEntry = arp -a | Where-Object { $_ -match $ip }
        if ($arpEntry -and $arpEntry -match '([a-zA-Z0-9\-]+\.local)') {
            return $matches[1]
        }

        # Fallback: try resolving via mDNS (requires mDNS responder on network)
        $mdnsName = Resolve-DnsName -Name "$ip.in-addr.arpa" -Type PTR -ErrorAction Stop |
        Where-Object { $_.NameHost -like '*.local' } |
        Select-Object -ExpandProperty NameHost -First 1
        return $mdnsName
    }
    catch {
        return $null
    }
}

# Func to get MAC address from ARP cache
function Get-MacAddress {
    param([string]$ip)
    try {
        $arp = arp -a | Where-Object { $_ -match $ip }
        if ($arp -match '([0-9a-f]{2}[-:]){5}[0-9a-f]{2}') {
            return $matches[0].ToUpper()
        }
        return $null
    }
    catch { return $null }
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
    }
    catch { return $null }
}

# Func to test if port 80 is open on the host
function Test-TcpPort {
    param([string]$ip, [int]$port, [int]$timeoutMs = 500)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $ar = $client.BeginConnect($ip, $port, $null, $null)
        if (-not $ar.AsyncWaitHandle.WaitOne($timeoutMs)) { $client.Close(); return $false }
        $client.EndConnect($ar)
        $client.Close()
        return $true
    }
    catch { return $false }
}

# --------- main flow (with ETA + smoothing) ----------
Write-Host "`nSubnet Scanner 2025 https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/PowerShell.IP.Scan.ps1`n" -ForegroundColor Yellow
$cidr = Read-Host "`nEnter CIDR block (e.g., 192.168.1.0/24)"
$ips = Get-IPsFromCIDR $cidr
if ($ips.Count -eq 0) { Write-Host "No hosts to scan for $cidr"; return }

# Tunables
$pingTimeoutMs = 250        # per-host ping timeout
$ewmaAlpha = 0.15       # EWMA alpha for average per-host duration (0..1). Higher = more reactive.
$displayAlpha = 0.10        # smoothing alpha for displayed percent (0..1). Lower = smoother.

$total = $ips.Count
Write-Host "Starting scan of $total IPs..." -ForegroundColor Green

$ping = New-Object System.Net.NetworkInformation.Ping

# state
$current = 0
$online = 0
$avgHostMs = 0.0        # EWMA of host duration in ms (starts at 0)
$displayPct = 0.0       # smoothed displayed percent

# ensure an efficient appendable list exists
if (-not $hostResults) {
    $hostResults = [System.Collections.Generic.List[PSObject]]::new()
}

# Loop through each IP getting the additional info along with IP addr
foreach ($ip in $ips) {
    $hostSw = [System.Diagnostics.Stopwatch]::StartNew()

    # Prepare a minimal result object with defaults
    $result = [PSCustomObject]@{
        IP           = $ip
        Responded    = $false
        RTTms        = $null
        MacAddress   = $null
        PTR          = $null
        NetBIOS      = $null
        Mdns         = $null
        Port80Open   = $false
        ServerHdr    = $null
        Timestamp    = (Get-Date)
    }

    try {
        $reply = $ping.Send($ip, $pingTimeoutMs)
        if ($reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            # mark basic reachability and RTT
            $result.Responded = $true
            $result.RTTms = $reply.RoundtripTime

            # safe, per-probe isolation (errors won't abort the scan)
            try {
                $result.MacAddress = Get-MacAddress $ip
            }
            catch {
                $result.MacAddress = $null
            }
            try { $result.PTR = Get-ReverseDns $ip } catch { $result.PTR = $null }
            try {
                if (-not $result.PTR) {
                    $result.NetBIOS = Get-NetbiosName $ip
                }
            }
            catch {
                $result.NetBIOS = $null
            }
            try {
                if (-not $result.PTR -and -not $result.NetBIOS) {
                    $result.Mdns = Get-MdnsName $ip
                }
            }
            catch {
                $result.Mdns = $null
            }
            try { $result.Port80Open = Test-TcpPort $ip 80 300 } catch { $result.Port80Open = $false }
            if ($result.Port80Open) {
                try {
                    $hdrs = Get-HttpInfo $ip 80 600
                    if ($hdrs -and $hdrs['Server']) { $result.ServerHdr = $hdrs['Server'] }
                }
                catch { $result.ServerHdr = $null }
            }

            $online++    # maintain online counter
        }
    }
    catch {
        # treat as no response; keep moving
    }
    finally {
        $hostSw.Stop()
        $durMs = $hostSw.Elapsed.TotalMilliseconds

        # update EWMA for per-host duration
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

        # update ONLY the banner line
        Show-ProgressBanner $current $total $displayPct $eta -ForegroundColor Yellow

        # store the result object (no console noise)
        $hostResults.Add($result)
    }
}

# ---- finalization: show 100% banner and then output results ----
$displayPct = 100
Show-ProgressBanner $total $total $displayPct ([TimeSpan]::Zero)
$ping.Dispose()
Write-Host "`n`nScan complete!" -ForegroundColor Green
Write-Host "$online hosts responded." -ForegroundColor Yellow

# Print collected results: compact table first
Write-Host "Discovered hosts:" -ForegroundColor DarkYellow
$tableText = $hostResults |
Where-Object { $_.Responded } |
Select-Object IP, RTTms, MacAddress, NetBIOS, PTR, Mdns, Name, Port80Open, ServerHdr |
Format-Table -AutoSize | Out-String

Write-Host $tableText -ForegroundColor Blue

# Export CSV for later analysis
$csvPath = "$env:TEMP\cidr-scan-$($cidr.Replace('/','-'))-$(Get-Date -Format yyyyMMdd-HHmmss).csv"
$hostResults | ForEach-Object {
    $name = if ($_.PTR) { $_.PTR }
    elseif ($_.NetBIOS) { $_.NetBIOS }
    elseif ($_.Mdns) { $_.Mdns }
    else { $null }
    $_ | Add-Member -NotePropertyName Name -NotePropertyValue $name -Force
}
Write-Host "Saved CSV: $csvPath" -ForegroundColor Yellow
Pause
