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
$cidr = Read-Host "Enter CIDR block (e.g., 192.168.1.0/24)"
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
        IP         = $ip
        Responded  = $false
        RTTms      = $null
        PTR        = $null
        Port80Open = $false
        ServerHdr  = $null
        Timestamp  = (Get-Date)
    }

    try {
        $reply = $ping.Send($ip, $pingTimeoutMs)
        if ($reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            # mark basic reachability and RTT
            $result.Responded = $true
            $result.RTTms = $reply.RoundtripTime

            # safe, per-probe isolation (errors won't abort the scan)
            try { $result.PTR = Get-ReverseDns $ip } catch { $result.PTR = $null }
            try { $result.Port80Open = Test-TcpPort $ip 80 300 } catch { $result.Port80Open = $false }
            if ($result.Port80Open) {
                try {
                    $hdrs = Get-HttpInfo $ip 80 600
                    if ($hdrs -and $hdrs['Server']) { $result.ServerHdr = $hdrs['Server'] }
                }
                catch { $result.ServerHdr = $null }
            }

            $online++    # maintain your online counter if you still want it
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
Write-Host "`n`nScan complete!" -ForegroundColor Green
Write-Host "$online hosts responded." -ForegroundColor DarkGreen

# Print collected results: compact table first
Write-Host "`Discovered hosts:" -ForegroundColor DarkYellow
$tableText = $hostResults |
    Where-Object { $_.Responded } |
    Select-Object IP, RTTms, PTR, Port80Open, ServerHdr |
    Format-Table -AutoSize | Out-String

Write-Host $tableText -ForegroundColor Blue

# Export CSV for later analysis
$csvPath = "$env:TEMP\cidr-scan-$(Get-Date -Format yyyyMMdd-HHmmss).csv"
$hostResults | Where-Object { $_.Responded } | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "Saved CSV: $csvPath" -ForegroundColor Yellow
# SIG # Begin signature block
# MIIddQYJKoZIhvcNAQcCoIIdZjCCHWICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD4ZQmyz3k2wYh2
# PJ1f+P+BIzXwOdWhDCTaNpvHfnHF6qCCA14wggNaMIICQqADAgECAhASJPP+Ylvz
# q07Pm5xNs5/yMA0GCSqGSIb3DQEBBQUAMDYxEjAQBgNVBAMMCURhbi5EYW1pdDEg
# MB4GCSqGSIb3DQEJARYRZGFuQHRoZWRhbWl0cy5jb20wHhcNMjUwNzA5MjIyOTAz
# WhcNMjYwNzA5MjI0OTAzWjA2MRIwEAYDVQQDDAlEYW4uRGFtaXQxIDAeBgkqhkiG
# 9w0BCQEWEWRhbkB0aGVkYW1pdHMuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAtmuSe45zCVnbgz7lvXMNp9Mp/pXPqnRdNdtuTyvtWPW/83giaIyy
# vyRbxPxvl/YGlJd93H7nJFfzANOhD5qt34ZUzJJcPBjjy8mKLX2Kv8Pa/zns/stf
# 6/P9b8+YEkB8v/13Je9ist4Uyf/XX24BX9CdgtVf5224+UaLhXzYYahoCn/QdoQb
# ukf/kTmDmnOGaLHWs6VccsRFSh3BJSlPdV04BPvgRQkcLBb7RLtTxx1RUkrGr+Oo
# hcBdmZeq7kE2VsOlFt9tDiEPtimdbmwuNWRwgnsPjCiSAZ0cVCsbKv5scZPGi6GF
# oCgfnn2eSrohmA2QAdpi8nz+3OkmcuvGbQIDAQABo2QwYjAOBgNVHQ8BAf8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHAYDVR0RBBUwE4ERZGFuQHRoZWRhbWl0
# cy5jb20wHQYDVR0OBBYEFPyyfreqwdD196m5Kp4jOfUWJBUuMA0GCSqGSIb3DQEB
# BQUAA4IBAQANKw1/E5WAE5pdnzDbKdC5MLpM7hfvAY+LDDmGIuYPfpGq64sMivMc
# U5PNzUhdtZbioTzLoYzZfxipv+wiUVrg9v+OqBYUwwWrFudjWbGZAwB/el1mHTE3
# X82Tjce4scbANCBupK9tdxTyz+NQ4i3WI6QX67ZG6DzEGVQ9WB/XHAltZnVW6uYE
# VQxGH6c+UjSP9SCKC3U8K3EyYtgLKSlSlnQ5nB9hhQOON2p3AY9UlqTVjlWI2FxX
# CbuoT9tMUqlQQYg1Y6t+iyhYGLVqs8rO4Dr7wRX6RRNurwm8H0N4HrxYIHiNp3Ny
# AxqhO2JAAanpfrPM7YrG2ffeXdoHOjShMYIZbTCCGWkCAQEwSjA2MRIwEAYDVQQD
# DAlEYW4uRGFtaXQxIDAeBgkqhkiG9w0BCQEWEWRhbkB0aGVkYW1pdHMuY29tAhAS
# JPP+Ylvzq07Pm5xNs5/yMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDEC
# MAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwG
# CisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIM5CG1JiQYMnD4nwckteeEsrnbaL
# vC5zlu2ITG2lEMGrMA0GCSqGSIb3DQEBAQUABIIBAKjVu7niM6xCyrQpv5x1+I+a
# WvY2ZylU+MM2x7teKGB3SGnKgf474owbM03KKxxSHxNLBaLVdP2On5LTofatlDmr
# ewbW01HUR9iUJ1kFfhIV/K0q0rfTiSSnerOUP09wwwl4sBAj6COyCHKDObCdBSDU
# PTlH/iY13x0BwC0muF41gBJOk8XuQVTNWo5nbz5ITh5L/PCnab5jqBgI3H3koEWT
# fInx7e9FxND+4T+rh/7+e1IJXJbpO1/82IYv1hY7oDpaWtC9C+3dCc0m4R8m+Owo
# KjUJq4G5TrynqO7lXSC9EFR6rHTAW9/7BsgfYCaMb+54jUtRoY5lKbpMoWIn83ih
# ghd2MIIXcgYKKwYBBAGCNwMDATGCF2IwghdeBgkqhkiG9w0BBwKgghdPMIIXSwIB
# AzEPMA0GCWCGSAFlAwQCAQUAMHcGCyqGSIb3DQEJEAEEoGgEZjBkAgEBBglghkgB
# hv1sBwEwMTANBglghkgBZQMEAgEFAAQgje9rnn2HD+hAC9VSEDtS6A55I8Ebanur
# VcxqFQ9Uo8UCEC3NAu7b7T4I3ZbdBAoYRU0YDzIwMjUxMTExMTgwNDI0WqCCEzow
# ggbtMIIE1aADAgECAhAKgO8YS43xBYLRxHanlXRoMA0GCSqGSIb3DQEBCwUAMGkx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYg
# MjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAwWhcNMzYwOTAzMjM1OTU5WjBjMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lD
# ZXJ0IFNIQTI1NiBSU0E0MDk2IFRpbWVzdGFtcCBSZXNwb25kZXIgMjAyNSAxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA0EasLRLGntDqrmBWsytXum9R
# /4ZwCgHfyjfMGUIwYzKomd8U1nH7C8Dr0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k
# +87H9WPxNyFPJIDZHhAqlUPt281mHrBbZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9
# A72wzHpkBaMUNg7MOLxI6E9RaUueHTQKWXymOtRwJXcrcTTPPT2V1D/+cFllESvi
# H8YjoPFvZSjKs3SKO1QNUdFd2adw44wDcKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGH
# r7zou1znOM8odbkqoK+lJ25LCHBSai25CFyD23DZgPfDrJJJK77epTwMP6eKA0kW
# a3osAe8fcpK40uhktzUd/Yk0xUvhDU6lvJukx7jphx40DQt82yepyekl4i0r8OEp
# s/FNO4ahfvAk12hE5FVs9HVVWcO5J4dVmVzix4A77p3awLbr89A90/nWGjXMGn7F
# QhmSlIUDy9Z2hSgctaepZTd0ILIUbWuhKuAeNIeWrzHKYueMJtItnj2Q+aTyLLKL
# M0MheP/9w6CtjuuVHJOVoIJ/DtpJRE7Ce7vMRHoRon4CWIvuiNN1Lk9Y+xZ66laz
# s2kKFSTnnkrT3pXWETTJkhd76CIDBbTRofOsNyEhzZtCGmnQigpFHti58CSmvEyJ
# cAlDVcKacJ+A9/z7eacCAwEAAaOCAZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0O
# BBYEFOQ7/PIx7f391/ORcWMZUEPPYYzoMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esri
# kFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIw
# MjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYy
# MDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggIBAGUqrfEcJwS5rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVv
# hREafBYF0RkP2AGr181o2YWPoSHz9iZEN/FPsLSTwVQWo2H62yGBvg7ouCODwrx6
# ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7YXwBD9R0oU62PtgxOao872bOySCILdBghQ/Z
# LcdC8cbUUO75ZSpbh1oipOhcUT8lD8QAGB9lctZTTOJM3pHfKBAEcxQFoHlt2s9s
# XoxFizTeHihsQyfFg5fxUFEp7W42fNBVN4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqI
# tH3CPFTG7aEQJmmrJTV3Qhtfparz+BW60OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs
# 7v9y69NBqycz0BZwhB9WOfOu/CIJnzkQTwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E
# 5UCSDag6+iX8MmB10nfldPF9SVD7weCC3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGn
# oa9F5AaAyBjFBtXVLcKtapnMG3VH3EmAp/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZ
# yvgLfgyPehwJVxwC+UpX2MSey2ueIu9THFVkT+um1vshETaWyQo8gmBto/m3acaP
# 9QsuLj3FNwFlTxq25+T4QwX9xa6ILs84ZPvmpovq90K8eWyG2N01c4IhSOxqt81n
# MIIGtDCCBJygAwIBAgIQDcesVwX/IZkuQEMiDDpJhjANBgkqhkiG9w0BAQsFADBi
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3Qg
# RzQwHhcNMjUwNTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5WjBpMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRy
# dXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx0wqYQXK+PEbAHKx126NG
# aHS0URedTa2NDZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz4aH+qbxeLho8I6jY3xL1
# IusLopuW2qftJYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJgMQB3h2DZ0Mal5kYp77j
# YMVQXSZH++0trj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQbzIBHYJBYgzWIjk8eDrY
# hXDEpKk7RdoX0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IBZK4ivbVC
# iZv7PNBYqHEpNVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJRfN20VRS3hpLgIR4hjzL
# 0hpoYGk81coWJ+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU14lDnki7CcoKCz6eum5A1
# 9WZQHkqUJfdkDjHkccpL6uoG8pbF0LJAQQZxst7VvwDDjAmSFTUms+wV/FbWBqi7
# fTJnjq3hj0XbQcd8hjj/q8d6ylgxCZSKi17yVp2NL+cnT6Toy+rN+nM8M7LnLqCr
# O2JP3oW//1sfuZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq1BtmXUqEG1NqzJKS4kOm
# xkYp2WyODi7vQTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqgPrHRVHhGNKlYzyjlroPx
# ul+bgIspzOwbtmsgY1MCAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAw
# HQYDVR0OBBYEFO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8GA1UdIwQYMBaAFOzX44LS
# cV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEF
# BQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYy
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5j
# cmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEB
# CwUAA4ICAQAXzvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfFiBowf0/Dm1wGc/Do7oVM
# Y2mhXZXjDNJQa8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4/iEIUBO41P5F448rSYJ5
# 9Ib61eoalhnd6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/DMm/axFSgoR8n6c3nuZB
# 9BfBwAQYK9FHaoq2e26MHvVY9gCDA/JYsq7pGdogP8HRtrYfctSLANEBfHU16r3J
# 05qX3kId+ZOczgj5kjatVB+NdADVZKON/gnZruMvNYY2o1f4MXRJDMdTSlOLh0HC
# n2cQLwQCqjFbqrXuvTPSegOOzr4EWj7PtspIHBldNE2K9i697cvaiIo2p61Ed2p8
# xMJb82Yosn0z4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc3hsXMrS+U0yy+GWqAXam
# 4ToWd2UQ1KYT70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLiRu7hAWE6bTEm4XYRkA6T
# l4KSFLFk43esaUeqGkH/wyW4N7OigizwJWeukcyIPbAvjSabnf7+Pu0VrFgoiovR
# Diyx3zEdmcif/sYQsfch28bZeUz2rtY/9TCA6TD8dC3JE3rYkrhLULy7Dc90G6e8
# BlqmyIjlgp2+VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM1pD2T7m3XDCCBY0wggR1
# oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4X
# DTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEh
# MB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0B
# AQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLh
# Kac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+
# vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMp
# Lc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+n
# MNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1Dek
# LgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmk
# wuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0
# yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP
# 9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHh
# D5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnf
# fEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId
# 5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LS
# cV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgP
# MA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0
# dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2Vy
# dHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNV
# HR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRB
# c3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0B
# AQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlU
# Iu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqa
# i7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eH
# qNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01
# YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ
# 8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDGCA3wwggN4AgEBMH0waTELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENB
# MQIQCoDvGEuN8QWC0cR2p5V0aDANBglghkgBZQMEAgEFAKCB0TAaBgkqhkiG9w0B
# CQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MTExMTE4MDQyNFow
# KwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU3WIwrIYKLTBr2jixaHlSMAf7QX4wLwYJ
# KoZIhvcNAQkEMSIEIIItYw2yfnIcdE+mnKlnfY6x+XANEYRgkfDfwjOOKGWeMDcG
# CyqGSIb3DQEJEAIvMSgwJjAkMCIEIEqgP6Is11yExVyTj4KOZ2ucrsqzP+NtJpqj
# NPFGEQozMA0GCSqGSIb3DQEBAQUABIICAM6Ympqqy++dZ4IDccVPKqAFJEGITNpj
# 8yblVNupz9QdL1k78J3lUlX7InYWENkvfZrLlyFch4CY8GWFIQuQvsEikI3lvCHZ
# St93OEUWw5v0Jy5Kd+iGJ1R/1liaK4Q5a8yDgm2s9Lz6FhvuZ8dlnJFs1s3Cb9KM
# p6Ag7NTkiLGNucjeAgywUC2pC/JRRbp/FbfIfV7SKEi5VcpuBlgmnQCTF2QNqOWg
# z28eZK3y1HHceDmJoV5ehJmTx9UK1kbUw1OePhd4lq0hAE+widwFpoEPGsOO709s
# /27T9CAlbzSwzjdo+U3Q0R5YBD++LnA4ZHHW7XIhDq90OTrmXg+vk7f6yGn6lCvw
# QZuDRNXLALKxlM1YQNGIUkfdYnx6SEd8TLSfqyYtWx5adB1AU1gfgnTEYAUCsfKo
# tjge4gY7a9R4BDk5XHF/48yXEcL7kz5IwD56LvXUdBNXQ69KVeaPs6l0bw/hi87c
# pZsF5LjclkyCp4fHqZHmf3tsSn1hHieJ7Bmb/5ePGKi6Fw8m/rvWfyDwYL0bu7ZR
# NzVW8p8dp5oW2q1BnQQS5F4cfTcv2Sp3BPJnTZf00FiPmXIQ6DFYWsL1S0YxAM3S
# 3pa9pjOmiJscBCESDDmDx/KrX8GJ5wIOa9yl2qeOEDMRUeaQ5fg134qhyxnZfwUx
# fOthnZ4JZVXM
# SIG # End signature block
