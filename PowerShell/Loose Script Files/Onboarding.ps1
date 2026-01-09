<#PSScriptInfo

Author: Dan.Damit
e: Dan@thedamits.com

Description: 
	Short script to create the Registry key that handles disabling or enabling Core Isolation,
	It creates the key if not present, then sets the value to 0, disabling Core Isolation
	Two blocks were added to disable UAC and join to a domain.
	Blocks added to disable EEE on all NICS, and to disable power management on all USB controllers 
	and Ethernet NICs
	
	Added more interactive status updates and colored fonts.
	Modified Error handling and also changed Core Isolation to user input if they want to disable it or not.
	Added functionality to domain join block to skip it using 'none' or 'null'

Created: 20250304
Last Modified: 20250502

#>

[console]::ForegroundColor = "DarkCyan"
Write-Host #
Write-Host "----------------------------------------------------------"
Start-Sleep -Seconds 1
Write-Host "!!!*Starting Onboarding Scripts*!!!" -ForegroundColor Magenta
Start-Sleep -Seconds 1
Write-Host "----------------------------------------------------------"
Write-Host #

# Disable UAC by setting the EnableLUA registry key to 0
$UACRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$UACValueName = "EnableLUA"

# Define the registry path for Memory Integrity
$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"

# Ensure the registry path exists
if (-not (Test-Path $UACRegistryPath)) {
    New-Item -Path $UACRegistryPath -Force | Out-Null
}

try {
    if (-not (Test-Path $UACRegistryPath)) {
        New-Item -Path $UACRegistryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $UACRegistryPath -Name $UACValueName -Value 0 -Type DWord
    Write-Host "UAC has been disabled successfully." -ForegroundColor Green
} catch {
    Write-Host "Error updating UAC registry key: $($_.Exception.Message)" -ForegroundColor Red
}
Write-host #
# Ask the user if they want to disable Memory Integrity
$MIUserChoice = Read-Host "Do you want to disable Core Isolation? (y/n)"

if ($MIUserChoice -eq "y") {
    try {
        # Ensure the registry path exists
        if (-not (Test-Path $RegistryPath)) {
            New-Item -Path $RegistryPath -Force | Out-Null
        }
        
        # Set the registry key to disable Memory Integrity
        Set-ItemProperty -Path $RegistryPath -Name "Enabled" -Value 0 -Type DWord
        Write-Host "Core Isolation has been disabled successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error updating Core Isolation registry key: $($_.Exception.Message)" -ForegroundColor Red
    }
} elseif ($MIUserChoice -eq "n") {
    Write-Host "Core Isolation was not modified." -ForegroundColor Yellow
} else {
    Write-Host "Invalid input. Please run the script again and enter 'y' or 'n'." -ForegroundColor Red
}
Write-host #
Start-Sleep -Seconds 3
Write-host "Disabling Power Savings on USB Controllers..." -ForegroundColor Yellow
Write-host "This might take a few minutes. Please be patient." -ForegroundColor Red
Start-Sleep -Seconds 3

#This block disables power savings on USB Hub 3.0
try {
    $hubs = Get-WmiObject Win32_USBHub
    $powerMgmt = Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi
    $disabledCount = 0

    foreach ($p in $powerMgmt) {
        $IN = $p.InstanceName.ToUpper()
        foreach ($h in $hubs) {
            $PNPDI = $h.PNPDeviceID
            if ($IN -like "*$PNPDI*") {
                $p.Enable = $False
                $p.psbase.Put() | Out-Null
                $disabledCount++
            }
        }
    }

    if ($disabledCount -gt 0) {
        Write-Host "Disabled power management for $disabledCount USB hub(s)." -ForegroundColor Green
    }
    else {
        Write-Host "No USB hubs required power management disabling." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error disabling power management for USB controllers: $($_.Exception.Message)" -ForegroundColor Red
}
Start-Sleep -Seconds 2
Write-host "Disabled Power Management on all USB Hubs" -ForegroundColor Red
Write-host #
Start-Sleep -Seconds 2
Write-host "Disabling Power Management eXtensible USB controllers if present..." -ForegroundColor Yellow

# Disable Power Management on USB eXtensible Host Controllers
$controllers = Get-WmiObject Win32_PnPEntity | Where-Object { 
    $_.Name -like "*eXtensible*" 
}
$powerMgmt = Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi
$count = 0

foreach ($controller in $controllers) {
    $PNPDI = $controller.PNPDeviceID
    foreach ($p in $powerMgmt) {
        $IN = $p.InstanceName.ToUpper()
        if ($IN -like "*$PNPDI*") {
            $p.Enable = $False
            $p.psbase.Put() | Out-Null
            $count++
        }
    }
}

Write-Host "Power Management Disabled on USB eXtensible Host Controllers for $count item(s)." -ForegroundColor Green
Write-Host #
Start-Sleep -seconds 2
Write-Host "Disabling Energy-Efficient Ethernet on hardware Ethernet interfaces..." -ForegroundColor Yellow

# Get all wired Ethernet adapters (exclude wireless ones)
$ethernetAdapters = Get-NetAdapter | Where-Object { $_.HardwareInterface -eq $true -and $_.NdisPhysicalMedium -eq 14 }

if ($ethernetAdapters.Count -eq 0) {
    Write-Host "No wired Ethernet adapters found. Exiting EEE processing." -ForegroundColor Red
} else {
    foreach ($adapter in $ethernetAdapters) {
        # Get all advanced properties for the current adapter
        $properties = Get-NetAdapterAdvancedProperty -Name $adapter.Name

        # Find any property related to EEE (based on keyword or display name)
        $eeeProperty = $properties | Where-Object { $_.RegistryKeyword -like "*EEE*" -and $_.DisplayName -like "*Ethernet*" }

        if ($eeeProperty) {
            foreach ($property in $eeeProperty) {
                try {
                    # Attempt to disable the EEE-related property
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $property.RegistryKeyword -RegistryValue 0
                    Write-Host "EEE setting '$($property.DisplayName)' successfully disabled on adapter: $($adapter.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "Failed to disable EEE setting '$($property.DisplayName)' on adapter: $($adapter.Name)" -ForegroundColor Red
                    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "No EEE-related settings found for adapter: $($adapter.Name)" -ForegroundColor Yellow
        }
    }
}

Write-Host "EEE processing complete." -ForegroundColor Green
exit
# SIG # Begin signature block
# MIIbggYJKoZIhvcNAQcCoIIbczCCG28CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUgoP6BaxqI5ljC9PSYNik4c5g
# mlugghX/MIIC+DCCAeCgAwIBAgIQTXfE84n+OqdH4IKB0bnPjjANBgkqhkiG9w0B
# AQsFADAUMRIwEAYDVQQDDAlEYW4uRGFtaXQwHhcNMjUwNDE3MjIwODExWhcNMjYw
# NDE3MjIyODExWjAUMRIwEAYDVQQDDAlEYW4uRGFtaXQwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCsUJ06DMUlEzTDRHjDVXzFJQ0hyrxxaTxW6qgHYdY9
# unX3Fo3fLiBOyzIV3VRzEJJgcbhw3nmoHWhCyccTqIZ3ZE5OE0a5t7kbkGeN4SmO
# XG3DNt/CKbLYXZM3DbjkUkliGKt1CEetToebQfWqPm8wseozf3TUMTdY8z7VCQYC
# /R8z9woaZSustTsIZwVf2mALoJDb5WkUyn0ZBImmnlanDJKtby77SMHPL8lHl+rM
# I7HBWH8xSCnpucgVlRh42N95HKGMmEOpSy5xeBLQHeOoK4NY45DChpQH7NjBr0Rb
# sEErrCMpoJPlhVehkXbf6Ty0BTxjgJFWfCNjxqkgmYFFAgMBAAGjRjBEMA4GA1Ud
# DwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUVfs9TWGs
# lKOYJI3f0Gyc14Wh03cwDQYJKoZIhvcNAQELBQADggEBAHFZ8DPPFPTB1nRa0Z4x
# 23TsiQrbRIL5PlJSmvJDDHej92xfcirW9kZlCdNMlQ36SLsg7dyDJdIegbuRktv7
# IuA5iEED8bc8xks+qhQh7w4IroMHHPwq+OhuDjNh3CiDDD1HIITrXFBj0qzO0b6C
# lT8q3i3D5LyAJcoRfNdPmAUZhDVEf2ymTgj7/EZ72++60BpjAM6vau8FuNjFEeJv
# wpZw07vtYg0AoE2K/w3F3gUsu2eMwhtM1yXkbuMEMtmZhPFBoEtJ8SlEZ17k3NXt
# aAPn5Ktnf6tU7/2L0gBVgNJLTGetbsOBeLT/vLyQISHHWbeS0zROrtB9cAI6GyIj
# vzAwggWNMIIEdaADAgECAhAOmxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUA
# MGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsT
# EHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQg
# Um9vdCBDQTAeFw0yMjA4MDEwMDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqcl
# LskhPfKK2FnC4SmnPVirdprNrnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YF
# PFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceIt
# DBvuINXJIB1jKS3O7F5OyJP4IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZX
# V59UWI4MK7dPpzDZVu7Ke13jrclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1
# ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2Tox
# RJozQL8I11pJpMLmqaBn3aQnvKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdp
# ekjw4KISG2aadMreSx7nDmOu5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF
# 30sEAMx9HJXDj/chsrIRt7t/8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9
# t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQ
# UOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXk
# aS+YHS312amyHeUbAgMBAAGjggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1Ud
# DgQWBBTs1+OC0nFdZEzfLmc/57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEt
# UYunpyGd823IDzAOBgNVHQ8BAf8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsG
# AQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0
# dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAw
# DQYJKoZIhvcNAQEMBQADggEBAHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyF
# XqkauyL4hxppVCLtpIh3bb0aFPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76
# LVbP+fT3rDB6mouyXtTP0UNEm0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8L
# punyNDzs9wPHh6jSTEAZNUZqaVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2
# CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si
# /xK4VC0nftg62fC2h5b9W9FcrBjDTZ9ztwGpn1eqXijiuZQwggauMIIElqADAgEC
# AhAHNje3JFR82Ees/ShmKl5bMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yMjAzMjMw
# MDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0
# MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQDGhjUGSbPBPXJJUVXHJQPE8pE3qZdRodbSg9GeTKJtoLDMg/la
# 9hGhRBVCX6SI82j6ffOciQt/nR+eDzMfUBMLJnOWbfhXqAJ9/UO0hNoR8XOxs+4r
# gISKIhjf69o9xBd/qxkrPkLcZ47qUT3w1lbU5ygt69OxtXXnHwZljZQp09nsad/Z
# kIdGAHvbREGJ3HxqV3rwN3mfXazL6IRktFLydkf3YYMZ3V+0VAshaG43IbtArF+y
# 3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYbqMFkdECnwHLFuk4fsbVYTXn+149zk6ws
# OeKlSNbwsDETqVcplicu9Yemj052FVUmcJgmf6AaRyBD40NjgHt1biclkJg6OBGz
# 9vae5jtb7IHeIhTZgirHkr+g3uM+onP65x9abJTyUpURK1h0QCirc0PO30qhHGs4
# xSnzyqqWc0Jon7ZGs506o9UD4L/wojzKQtwYSH8UNM/STKvvmz3+DrhkKvp1KCRB
# 7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo80VgvCONWPfcYd6T/jnA+bIwpUzX6ZhK
# WD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjBJgj5FBASA31fI7tk42PgpuE+9sJ0sj8e
# CXbsq11GdeJgo1gJASgADoRU7s7pXcheMBK9Rp6103a50g5rmQzSM7TNsQIDAQAB
# o4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUuhbZbU2FL3Mp
# dpovdYxqII+eyG8wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYD
# VR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGsw
# aTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUF
# BzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# Um9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeB
# DAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAH1ZjsCTtm+YqUQi
# AX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd4ksp+3CKDaopafxpwc8dB+k+YMjYC+Vc
# W9dth/qEICU0MWfNthKWb8RQTGIdDAiCqBa9qVbPFXONASIlzpVpP0d3+3J0FNf/
# q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl/Yy8ZCaHbJK9nXzQcAp876i8dU+6Wvep
# ELJd6f8oVInw1YpxdmXazPByoyP6wCeCRK6ZJxurJB4mwbfeKuv2nrF5mYGjVoar
# CkXJ38SNoOeY+/umnXKvxMfBwWpx2cYTgAnEtp/Nh4cku0+jSbl3ZpHxcpzpSwJS
# pzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/a6fxZsNBzU+2QJshIUDQtxMkzdwdeDrk
# nq3lNHGS1yZr5Dhzq6YBT70/O3itTK37xJV77QpfMzmHQXh6OOmc4d0j/R0o08f5
# 6PGYX/sr2H7yRp11LB4nLCbbbxV7HhmLNriT1ObyF5lZynDwN7+YAN8gFk8n+2Bn
# FqFmut1VwDophrCYoCvtlUG3OtUVmDG0YgkPCr2B2RP+v6TR81fZvAT6gt4y3wSJ
# 8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJRyvmfxqkhQ/8mJb2VVQrH4D6wPIOK+XW
# +6kvRBVK5xMOHds3OBqhK/bt1nz8MIIGvDCCBKSgAwIBAgIQC65mvFq6f5WHxvnp
# BOMzBDANBgkqhkiG9w0BAQsFADBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGln
# aUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5
# NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTI0MDkyNjAwMDAwMFoXDTM1MTEy
# NTIzNTk1OVowQjELMAkGA1UEBhMCVVMxETAPBgNVBAoTCERpZ2lDZXJ0MSAwHgYD
# VQQDExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyNDCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAL5qc5/2lSGrljC6W23mWaO16P2RHxjEiDtqmeOlwf0KMCBD
# Er4IxHRGd7+L660x5XltSVhhK64zi9CeC9B6lUdXM0s71EOcRe8+CEJp+3R2O8oo
# 76EO7o5tLuslxdr9Qq82aKcpA9O//X6QE+AcaU/byaCagLD/GLoUb35SfWHh43rO
# H3bpLEx7pZ7avVnpUVmPvkxT8c2a2yC0WMp8hMu60tZR0ChaV76Nhnj37DEYTX9R
# eNZ8hIOYe4jl7/r419CvEYVIrH6sN00yx49boUuumF9i2T8UuKGn9966fR5X6kgX
# j3o5WHhHVO+NBikDO0mlUh902wS/Eeh8F/UFaRp1z5SnROHwSJ+QQRZ1fisD8UTV
# DSupWJNstVkiqLq+ISTdEjJKGjVfIcsgA4l9cbk8Smlzddh4EfvFrpVNnes4c16J
# idj5XiPVdsn5n10jxmGpxoMc6iPkoaDhi6JjHd5ibfdp5uzIXp4P0wXkgNs+CO/C
# acBqU0R4k+8h6gYldp4FCMgrXdKWfM4N0u25OEAuEa3JyidxW48jwBqIJqImd93N
# Rxvd1aepSeNeREXAu2xUDEW8aqzFQDYmr9ZONuc2MhTMizchNULpUEoA6Vva7b1X
# CB+1rxvbKmLqfY/M/SdV6mwWTyeVy5Z/JkvMFpnQy5wR14GJcv6dQ4aEKOX5AgMB
# AAGjggGLMIIBhzAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUB
# Af8EDDAKBggrBgEFBQcDCDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1s
# BwEwHwYDVR0jBBgwFoAUuhbZbU2FL3MpdpovdYxqII+eyG8wHQYDVR0OBBYEFJ9X
# LAN3DigVkGalY17uT5IfdqBbMFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZUaW1l
# U3RhbXBpbmdDQS5jcmwwgZAGCCsGAQUFBwEBBIGDMIGAMCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wWAYIKwYBBQUHMAKGTGh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQwOTZTSEEyNTZU
# aW1lU3RhbXBpbmdDQS5jcnQwDQYJKoZIhvcNAQELBQADggIBAD2tHh92mVvjOIQS
# R9lDkfYR25tOCB3RKE/P09x7gUsmXqt40ouRl3lj+8QioVYq3igpwrPvBmZdrlWB
# b0HvqT00nFSXgmUrDKNSQqGTdpjHsPy+LaalTW0qVjvUBhcHzBMutB6HzeledbDC
# zFzUy34VarPnvIWrqVogK0qM8gJhh/+qDEAIdO/KkYesLyTVOoJ4eTq7gj9UFAL1
# UruJKlTnCVaM2UeUUW/8z3fvjxhN6hdT98Vr2FYlCS7Mbb4Hv5swO+aAXxWUm3Wp
# ByXtgVQxiBlTVYzqfLDbe9PpBKDBfk+rabTFDZXoUke7zPgtd7/fvWTlCs30VAGE
# sshJmLbJ6ZbQ/xll/HjO9JbNVekBv2Tgem+mLptR7yIrpaidRJXrI+UzB6vAlk/8
# a1u7cIqV0yef4uaZFORNekUgQHTqddmsPCEIYQP7xGxZBIhdmm4bhYsVA6G2WgNF
# YagLDBzpmk9104WQzYuVNsxyoVLObhx3RugaEGru+SojW4dHPoWrUhftNpFC5H7Q
# EY7MhKRyrBe7ucykW7eaCuWBsBb4HOKRFVDcrZgdwaSIqMDiCLg4D+TPVgKx2EgE
# deoHNHT9l3ZDBD+XgbF+23/zBjeCtxz+dL/9NWR6P2eZRi7zcEO1xwcdcqJsyz/J
# ceENc2Sg8h3KeFUCS7tpFk7CrDqkMYIE7TCCBOkCAQEwKDAUMRIwEAYDVQQDDAlE
# YW4uRGFtaXQCEE13xPOJ/jqnR+CCgdG5z44wCQYFKw4DAhoFAKB4MBgGCisGAQQB
# gjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFFv7+L0t
# v1Vmx6bP/UIOvAyoxcPhMA0GCSqGSIb3DQEBAQUABIIBAIXtCPo/d4GF0Tc6KM7Y
# GooediO5r6jrNlw7lWB/8yTwciATtxnGuPC1o8DBDc9P4X0/VpZNcdvhbe1I8CPT
# 6ywG8Pw6mnl/Hqe03o1Rk2N7uTfSdAKIVz4FGmovNGoSM59Q9V3CZTBT4OpaL2zG
# PJoWJ11JuJ0ncm/IRWR+DXRSC8uH7XkIq0nSf/4F7Hyt+UY69cptG9ND5MoQRKgS
# NZT0Vxm7a+qZ4gVfPDD3+Fk/MJo9IRQ3o0DHOVSOFQcZiFfI2xFbh0M8+I0WgNuk
# q7L3mpwh14K2GnUSqPYoFV+7yrJJlzjqk3TgiTA6tfUeMZKOQllXUJBBH34kK5Dc
# vmyhggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRy
# dXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhALrma8Wrp/
# lYfG+ekE4zMEMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMjUwNTA0MTY1OTQ5WjAvBgkqhkiG9w0BCQQx
# IgQgGdx56aNpzuMnA5GhyvxMtsfpZnSJbWuo63jc26nT0LIwDQYJKoZIhvcNAQEB
# BQAEggIASGXHP+YvMC5NU+IjxPOOSMDmOTaG0IiMxK0fFAN5GEgxfOOW6RaZzBHS
# igbmercFtHrt7FmdIluv4eCdi/kz8YxAKu2CxLqGT+8xL7tjg3VzgDHftfgL1Qt6
# SPQJWF19ZDrQOPC9kvOUpmV9IqHs6dJuEYvu3wR+slhtxA2eWcQRQrGlavuAyKae
# wQ88vONs2269irlbF/kK0esAcPAZ+4lNeWfwbU6h1wmRX7YYhNFZ56JtA464BwN2
# ewpOOMfKnc/A2ZAxazlv0bZh/19XlBMbJDjtPo+QdoFFLGWuoL+YI1ee3bAW+zOT
# Ou9LRDaAUVN8LtlbBbB4d+0Jwl+99/E4/QI9DFas9LYzCfVNH0gsKBU/bgr3kuMo
# RGhOUNOh1MaZQmRUa2fOdaVaQWfrhGsESYcqCeuzyWoTjqEPaZwDL77SC4C053Uz
# JDdc9FmtQ6rnVTWt0PAOL/M+6RuKYA8kp2r4/RxvtzQBrSDs6/Fo6UugQ/smBeSx
# vwCvUsskrbWOEDQlvACoQvFRfYa2HSC2sfMgnQ/YwB46CIUdi3D4idEHgfyQ8Bpk
# h3stszzZwlrCFvCfsEzuyo3QPrqhlLXOZw+9tRUeZ3TcGuQFxpcNTucu2VnxXXcL
# 9eHH20ExElm+Y+s1L4BISfS/3w/DGfL/W/4NIm6D3s5oYfIFNw4=
# SIG # End signature block
