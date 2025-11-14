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
        IP         = $ip
        Responded  = $false
        RTTms      = $null
        PTR        = $null
        NetBIOS    = $null
        Mdns       = $null
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
Select-Object IP, RTTms, PTR, NetBIOS, Mdns, Name, Port80Open, ServerHdr |
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
# SIG # Begin signature block
# MIIcQwYJKoZIhvcNAQcCoIIcNDCCHDACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUCyzngPBBwT5/qGFiND7wB5V/
# HJ+gghaYMIIDWjCCAkKgAwIBAgIQEiTz/mJb86tOz5ucTbOf8jANBgkqhkiG9w0B
# AQUFADA2MRIwEAYDVQQDDAlEYW4uRGFtaXQxIDAeBgkqhkiG9w0BCQEWEWRhbkB0
# aGVkYW1pdHMuY29tMB4XDTI1MDcwOTIyMjkwM1oXDTI2MDcwOTIyNDkwM1owNjES
# MBAGA1UEAwwJRGFuLkRhbWl0MSAwHgYJKoZIhvcNAQkBFhFkYW5AdGhlZGFtaXRz
# LmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALZrknuOcwlZ24M+
# 5b1zDafTKf6Vz6p0XTXbbk8r7Vj1v/N4ImiMsr8kW8T8b5f2BpSXfdx+5yRX8wDT
# oQ+ard+GVMySXDwY48vJii19ir/D2v857P7LX+vz/W/PmBJAfL/9dyXvYrLeFMn/
# 119uAV/QnYLVX+dtuPlGi4V82GGoaAp/0HaEG7pH/5E5g5pzhmix1rOlXHLERUod
# wSUpT3VdOAT74EUJHCwW+0S7U8cdUVJKxq/jqIXAXZmXqu5BNlbDpRbfbQ4hD7Yp
# nW5sLjVkcIJ7D4wokgGdHFQrGyr+bHGTxouhhaAoH559nkq6IZgNkAHaYvJ8/tzp
# JnLrxm0CAwEAAaNkMGIwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUF
# BwMDMBwGA1UdEQQVMBOBEWRhbkB0aGVkYW1pdHMuY29tMB0GA1UdDgQWBBT8sn63
# qsHQ9fepuSqeIzn1FiQVLjANBgkqhkiG9w0BAQUFAAOCAQEADSsNfxOVgBOaXZ8w
# 2ynQuTC6TO4X7wGPiww5hiLmD36RquuLDIrzHFOTzc1IXbWW4qE8y6GM2X8Yqb/s
# IlFa4Pb/jqgWFMMFqxbnY1mxmQMAf3pdZh0xN1/Nk43HuLHGwDQgbqSvbXcU8s/j
# UOIt1iOkF+u2Rug8xBlUPVgf1xwJbWZ1VurmBFUMRh+nPlI0j/Ugigt1PCtxMmLY
# CykpUpZ0OZwfYYUDjjdqdwGPVJak1Y5ViNhcVwm7qE/bTFKpUEGINWOrfosoWBi1
# arPKzuA6+8EV+kUTbq8JvB9DeB68WCB4jadzcgMaoTtiQAGp6X6zzO2Kxtn33l3a
# Bzo0oTCCBY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEM
# BQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UE
# CxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJ
# RCBSb290IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zC
# pyUuySE98orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf
# 1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x
# 4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEio
# ZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7ax
# xLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZ
# OjFEmjNAvwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJ
# l2l6SPDgohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz
# 2cXfSwQAzH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH
# 4b235kOkGLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb
# 5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ
# 9eRpL5gdLfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYD
# VR0OBBYEFOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuC
# MS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3
# aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9v
# dENBLmNydDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0g
# ADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs
# 7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq
# 3votVs/59PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/
# Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9
# /HYJaISfb8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWoj
# ayL/ErhULSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDCCBrQwggScoAMC
# AQICEA3HrFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUw
# NzAwMDAwMFoXDTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoT
# DkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRp
# bWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcN
# AQEBBQADggIPADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2U
# tZmWgyxU7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWC
# WgzbNfiR+2fkHUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+
# gKPsYfwEu7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DP
# fNBKS7Zazch8NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVV
# gtmUPAW35xUUFREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifi
# nT7zL2gdFpBP9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x
# 5HHKS+rqBvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HH
# fIY4/6vHespYMQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQ
# yogxG9QEPHrPV6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70Ew
# gWbVRSX1Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7Zr
# IGNTAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTv
# b1NK6eQGfHrK4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qY
# rhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYB
# BQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20w
# QQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZ
# MBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877
# FoAc/gc9EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI
# 9NAzaoQk97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3ess
# BS3q8nL2UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qK
# tntujB71WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I
# +ZI2rVQfjXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q1
# 7r0z0noDjs6+BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+Mt
# ucVGyOxiDf06VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9J
# GYxOGLS/D284NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlH
# qhpB/8MluDezooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7G
# ELH3IdvG2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlar
# Evf8EA+8hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAKgO8Y
# S43xBYLRxHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYD
# VQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBH
# NCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0
# MDAwMDAwWhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMO
# RGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2
# IFRpbWVzdGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfMGUIwYzKomd8U
# 1nH7C8Dr0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt
# 281mHrBbZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9R
# aUueHTQKWXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjKs3SKO1QNUdFd
# 2adw44wDcKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8odbkqoK+lJ25L
# CHBSai25CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK40uhktzUd/Yk0
# xUvhDU6lvJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk12hE5FVs9HVV
# WcO5J4dVmVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0
# ILIUbWuhKuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/
# DtpJRE7Ce7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT3pXWETTJkhd7
# 6CIDBbTRofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A9/z7eacCAwEA
# AaOCAZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZ
# UEPPYYzoMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB
# /wQEAwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgw
# gYUwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEF
# BQcwAoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3Rl
# ZEc0VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRY
# MFYwVKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAE
# GTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAGUq
# rfEcJwS5rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP2AGr181o2YWP
# oSHz9iZEN/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8wv2UV+Kbz/3Im
# ZlJ7YXwBD9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhc
# UT8lD8QAGB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihsQyfFg5fxUFEp
# 7W42fNBVN4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtf
# parz+BW60OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu
# /CIJnzkQTwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8MmB10nfldPF9
# SVD7weCC3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjFBtXVLcKtapnM
# G3VH3EmAp/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJVxwC+UpX2MSe
# y2ueIu9THFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFlTxq25+T4QwX9
# xa6ILs84ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMYIFFTCCBRECAQEwSjA2MRIw
# EAYDVQQDDAlEYW4uRGFtaXQxIDAeBgkqhkiG9w0BCQEWEWRhbkB0aGVkYW1pdHMu
# Y29tAhASJPP+Ylvzq07Pm5xNs5/yMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSl2DshAZN3D/53
# YV8ZB/34YY1x8TANBgkqhkiG9w0BAQEFAASCAQCzwwymSy2iQxdRrULSvbkDNr14
# gAUbzeyhzwzx+8l8vmPuP/VyYAZ9dFYQ9Mbcp+4D6rhAy+k8V2dwrgTU6AKJp4yd
# 0IEbbXE7R0wtzlYqULgrZZBuMCaafk4fUJmXPiMJfECf2MiPx1lW0RTlKASUg36q
# 8ELre87qKSHEYoVwtaMI1Miv/kAC6wXVjsgbApGyYUuf0v2hXG0to1WVSPH6Euev
# VkfVJjKmdgjBzx/Ct69BSzUEPZraqdz2ldJMaptUzCk0M9nXOWdQsyLhNzvp/fOS
# bw0lbYcgGeiBW3QK5OVVyJrbba6pp72Eh+HDqThcafez7dQ8zmNbc1HohyWDoYID
# JjCCAyIGCSqGSIb3DQEJBjGCAxMwggMPAgEBMH0waTELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVk
# IEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN
# 8QWC0cR2p5V0aDANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG
# 9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI1MTExNDE5MTIwOFowLwYJKoZIhvcNAQkE
# MSIEICS1vzMTAjSArqZGrORufoU39FQvaf/O7DnGrs3s+Bj7MA0GCSqGSIb3DQEB
# AQUABIICAGWsf1yD8KisS8ejcg2y36D+xNeFDab3Y8r0iR3z2gVtf/8NjayHV+IT
# t0asfRoipJr1VSz8/Nh4rOMgm6WB9GhA9xfqQ81vbiAJdbEiF/j6uvjJwGv9EPUF
# Sviyerd8MwJboMYkmMA8+7tC+xpKpEJnRXsYZUs+iFUbEmQO3+9yWXMZMlH49G8h
# BSK99yQFo56WBl7L97bX9HmjmYwjKADCeIkK3cjN7WJ5sZpS/xpbkz9LD+lenATk
# tRprSYSWYH7/ga403jTLafsYYFBpqIVO1adzmEA6idnE6QMMzlSDQ69q359rwcFR
# D169LOxF5hQqUv//i0fmzbw5qL1pjlWkm0eRXplT6wTqjiVZ7PIfEp4RMsVB1XqX
# FKB5YAFl872dGF4nfDpmp54y91htyEjTEmGLFsQOxrijuvw9TdwWuISFgzPCTY3U
# lWeFK2G1uMOlqGUqAny+CB4HjfiAf/UwntlnZTDms9dP4SPkTOxZa5F0KuayFr9F
# P9j5cnrEUwnOkKA/A9FMmBDIqAa+yssGj7LFn6Ne+/8UKHk0x0nnxJJ1BniUvLcV
# 5urVgvvifvtaEDyGzEP5vN6qlCPHk8w1gVR1veqs5qsp7aVzYWGGrO+V8XqNjZm8
# QUwIlVcsn5p3pIANtLYSO+5CwrlEIgwc4Z4/RBRqC+0xeOz6j4L1
# SIG # End signature block
