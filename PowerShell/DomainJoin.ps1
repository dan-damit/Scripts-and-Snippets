<#
Author: Dan.Damit
e: dan@thedamits.com

Description:
    Script joins the computer to a domain

Created: 20250502
Changed: 20250502

#>

[console]::ForegroundColor = "DarkCyan"
Start-Sleep -Seconds 1
Write-Host #
Write-Host "----------------------------------------------------------"
Write-Host "!!!*Starting Domain Join process*!!!" -ForegroundColor Magenta
Write-Host "----------------------------------------------------------"
Write-Host #

# Function to validate domain existence using nltest
function Validate-Domain {
    param($DomainName)
    $DomainExists = $false

    try {
        $result = nltest /dsgetdc:$DomainName 2>&1
        if ($result -match "DSGetDcName failed") {
            Write-Host "Domain '$DomainName' not found or could not be contacted. Please enter a valid domain name." -ForegroundColor Red
        } else {
            $DomainExists = $true
        }
    } catch {
        Write-Host "Error validating domain: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $DomainExists
}

# Define retry parameters
$MaxRetries = 5
$RetryCount = 0
$DomainJoined = $false

# Prompt for domain name with retry logic
do {
    $DomainName = Read-Host "Enter the domain name (type NONE or NULL to skip domain join)"
    if ($DomainName -eq "NONE" -or $DomainName -eq "NULL") {
        Write-Host "Skipping domain join as requested." -ForegroundColor Cyan
        exit
    }

    $DomainValid = Validate-Domain $DomainName
    if (-not $DomainValid) {
        $RetryCount++
        if ($RetryCount -lt $MaxRetries) {
            Write-Host "Retrying domain validation... Attempt $RetryCount of $MaxRetries" -ForegroundColor Yellow
        } else {
            Write-Host "Maximum retry attempts reached. Please check the domain settings and try again later." -ForegroundColor Red
            exit
        }
    }
} while (-not $DomainValid)

# Reset retry counter for domain join process
$RetryCount = 0

Write-host #

# Attempt to join the domain with retry mechanism
do {
    $Credential = Get-Credential -Message "Enter credentials for the domain"

    try {
        Add-Computer -DomainName $DomainName -Credential $Credential -ErrorAction Stop
        Write-Host "The computer has been successfully joined to the domain." -ForegroundColor Green
        $DomainJoined = $true
    } catch {
        Write-Host "Error joining the domain: $($_.Exception.Message)" -ForegroundColor Red
        $RetryCount++

        if ($RetryCount -lt $MaxRetries) {
            Write-Host "Retrying domain join... Attempt $RetryCount of $MaxRetries." -ForegroundColor Yellow
            Write-Host "Re-enter domain and credentials before retrying." -ForegroundColor Cyan
            Write-Host #
            $DomainName = Read-Host "Enter the domain name (type NONE or NULL to skip domain join)"
            if ($DomainName -eq "NONE" -or $DomainName -eq "NULL") {
                Write-Host "Skipping domain join as requested." -ForegroundColor Cyan
                exit
            }
        } else {
            Write-Host "Maximum retry attempts reached. Please verify credentials and network access." -ForegroundColor Red
            exit
        }
    }
} while (-not $DomainJoined -and $RetryCount -lt $MaxRetries)

Write-Host #

# Confirm domain join status
$CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
if ($DomainJoined -and $CurrentDomain -eq $DomainName) {
    Write-Host "The computer is now confirmed as part of '$DomainName'." -ForegroundColor Cyan
} else {
    Write-Host "Domain join failed or not confirmed. Please retry with valid credentials or network settings." -ForegroundColor Yellow
}
Exit
# SIG # Begin signature block
# MIIbggYJKoZIhvcNAQcCoIIbczCCG28CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVyfFfrMeNsqGHWmmPYQPSDj7
# Q3agghX/MIIC+DCCAeCgAwIBAgIQTXfE84n+OqdH4IKB0bnPjjANBgkqhkiG9w0B
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFNH7L9pV
# CGNCFBtRGYKcL7lmqypiMA0GCSqGSIb3DQEBAQUABIIBAKFbAvnSDPebYKTmhcIY
# 7zmVHiwvjoAIpi7vgrArEI8W2VB242hK4PXwONG8Jn4KSWBfJSQpeOgqk9dOvJh1
# NARuFIWWMtiGq5ueDisAUtcw+swh3zGONzz6r7Dcy7yXcESK8/gsb3DwZwoguYVP
# xu7EuBDoIhLYj9Yx5dcxgkz8FNUMnnhcQrbRwGJxxDAS+tkggtjThCRhLC/7CSl/
# uHV68ggq/T9XF9ZK0rmf6mZGwr3IDcK3pjnCIdfI9aHk2lWzyWoLZzqtiKd/6Fql
# dj/JSURUjqVd+110H5ZCli0lOXaHqqLSKohIJvXCyeqm+04jO2xJHZBcVpkuhoid
# dLShggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRy
# dXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhALrma8Wrp/
# lYfG+ekE4zMEMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMjUwNTA0MTY1ODUzWjAvBgkqhkiG9w0BCQQx
# IgQgNRWslGNhHpyjNwIt7s3/YeIlsKrIJLanHYWqHGJhCwAwDQYJKoZIhvcNAQEB
# BQAEggIAAVjPx8BaBsFhyMw3XAoI9PkW4A7o6fBK25JgIvh9e1jJ7+qZTcoFrTop
# ts+57QuA5rwfwsimAbeenHBizfgQrZm/rdhoKliU/Oo74uDChIHa+Ljl3IVETFtZ
# 1+5uJjGEBH9AwQVe4QEBX6kDrAJwI1U5e/o1GYPVVNANPMn0iA5ZnpVYmdZKSPOn
# ggpFj77Yq4bpDmdMEarAK2uDvKK3MwQlBLRJatpDqXfycXBA/K89ZKLrAlBH181P
# NkIVtCKBCMjTp9MBN9Gr6YWwAvIwQf3AJelrcpFHGDy76QtGhe0Ix5tf592jDhJE
# INKvGe7z4ap3e+RJW1fmZNyfvw38AsejEbAkgemzMAw0Sh8Rk2Rxw1LLAmttQefq
# FyznOCzLuCkdJ+63eX8kmEj0KlPQiTHM41lW7NFnhGt0g7MTUzWEZZ8eTT8cSpOe
# DFolQZo8WrC/RjtXOAze01qLHp799e1gk4KIIfgsIl5gP3nRpItiGvqV4Owua0bU
# aq1gu/sHj4HBnFfLZH1mrrx1omCzV/DTtraYeVvjillXBkEtHxEWBkzPc3JwIcRE
# AfUs3tkalwsQRZnHQDo9JAaHfuet+0qmgNIHKYvAzM3hkA9QyptYImLGHgO2xIvc
# BUvqNvcd6aP6dIuP5n+4H359zOYnDSysFEuOsHod1uOiqUsWlZE=
# SIG # End signature block
