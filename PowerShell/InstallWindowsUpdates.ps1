<#  
Author: Dan.Damit  
e: dan@thedamits.com  

Description:  
    Script uses PSWindowsUpdate module and installs available Windows Updates  
    - Automatically installs updates smaller than 50 MB  
    - Skips updates larger than 50 MB  
    - Timeout mechanism to prevent indefinite stalling  
    - Retry logic for failed updates  
    - Status bar for real-time progress  

Created: 20250501  
Changed: 20250507
#>  

[console]::ForegroundColor = "DarkCyan"
Write-Host "--------------------------------------------------"
Write-Host "!!!*Starting Windows Updates Script*!!!" -ForegroundColor Magenta
Write-Host "--------------------------------------------------"
Write-Host #
Start-Sleep -Seconds 1
Write-Host "Connecting to Microsoft Update servers to check for updates." -ForegroundColor DarkCyan
Write-Host "This might take a while. Please be patient." -ForegroundColor Yellow
Write-Host #

# Retrieve update details
$updates = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot
$totalUpdates = $updates.Count

if ($totalUpdates -eq 0) {
    Write-Host "No updates available!" -ForegroundColor Green
} else {
    $timeout = 900  # 15 minutes per update
    $progressStep = 100 / $totalUpdates
    $i = 0

    foreach ($update in $updates) {
        # Retrieve update size (if available)
        $updateSizeMB = ($update.Size / 1MB)  # Convert bytes to MB

        if ($updateSizeMB -le 50) {
            Write-Host "Installing: $($update.Title) ($($update.KB)), Size: $([math]::Round($updateSizeMB, 2)) MB..." -ForegroundColor Cyan
            
            $startTime = Get-Date
            $success = $false
            $attempts = 0

            while (-not $success -and $attempts -lt 2) {
                $attempts++
                Write-Progress -Activity "Overall Windows Update Progress" -Status "Installing $($update.KB)" -PercentComplete ($i * $progressStep)

                Get-WindowsUpdate -Install -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose | Out-Null

                while ((Get-Date).Subtract($startTime).TotalSeconds -lt $timeout) {
                    Start-Sleep -Seconds 30  # Allow update history to refresh
                    $installedUpdates = Get-WindowsUpdate -History | Where-Object {$_.KB -eq $update.KB}
                    
                    if ($installedUpdates) {
                        Write-Host "Installed: $($update.Title)" -ForegroundColor Green
                        $success = $true
                        break  # Exit the loop once installation is confirmed
                    }
                }

                if (-not $success -and $attempts -lt 2) {
                    Write-Host "Installation appears successful, but verification failed. Re-checking..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 20
                    $installedUpdates = Get-WindowsUpdate -History | Where-Object {$_.KB -eq $update.KB}

                    if ($installedUpdates) {
                        Write-Host "Verified: $($update.Title) successfully installed!" -ForegroundColor Green
                        $success = $true
                    } else {
                        Write-Host "Installation failed—retrying..." -ForegroundColor Yellow
                        Start-Sleep -Seconds 5
                    }
                }
            }

            if (-not $success) {
                Write-Host "Update failed after retries—skipping $($update.KB)" -ForegroundColor Red
            }

        } else {
            Write-Host "Skipping: $($update.Title) ($($update.KB)), Size: $([math]::Round($updateSizeMB, 2)) MB exceeds 50 MB limit." -ForegroundColor Yellow
        }

        # Update progress bar after each update
        $i++
        Write-Progress -Activity "Overall Windows Update Progress" -Status "Completed $i of $totalUpdates" -PercentComplete ($i * $progressStep)
        Write-Progress -Activity "Overall Windows Update Progress" -Completed
    }
}

# Clear progress bar once done
Write-Progress -Activity "Overall Windows Update Progress" -Status "Completed!" -Completed
Write-Host #  
Write-Host "Updates complete! ✅" -ForegroundColor Green
Start-Sleep -Seconds 1
Write-Progress -Activity " " -Status " " -Completed
Exit
# SIG # Begin signature block
# MIIbggYJKoZIhvcNAQcCoIIbczCCG28CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUu8PhGB8gzStEeKJeSEcS9tDl
# SqKgghX/MIIC+DCCAeCgAwIBAgIQTXfE84n+OqdH4IKB0bnPjjANBgkqhkiG9w0B
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFDtBRxIv
# ctTwLd+h5yj3rm1dGspyMA0GCSqGSIb3DQEBAQUABIIBAItE5BI4D5zD7/yS2eIx
# utlanXQ9YMZdGKmXkAdoqfJioFkGkNnL0JAwWMko3lw6EVtKdXp4s+jWgMZgnR7J
# D7mgWOUyB94kBpSO0W+HGUfaR3Nna6/ZZiGBQlXCPboNoTLn5/dzncavEdTX/x3u
# mXCT3vSKtxixlpUPpsE6GLmmr3G/fJnQSLDdkURlUYI8GaCSh1jmrDd42CPD8ihi
# bxs5qnVfz/Vyx58/KBPAnGYEuQtwXJsPUEM0b9VMi9nTb+N9x2JRhN/e/T5b/QcQ
# dTSwfeblZRQLeccVMHCXaQj8z15y4Wkz/GT1iTKPiibMDW31Vwugz9W8cnnuFqDK
# h9uhggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRy
# dXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBAhALrma8Wrp/
# lYfG+ekE4zMEMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3
# DQEHATAcBgkqhkiG9w0BCQUxDxcNMjUwNTA4MDAzNjAzWjAvBgkqhkiG9w0BCQQx
# IgQgm+soUK0XDZiOAQ6MsVeUMr8aLDqBc2mNQkzs5GJn7WswDQYJKoZIhvcNAQEB
# BQAEggIAR+TmXVym03pI8BWCbc8b7iEIZdxftnAcwiIECQRchszopj3kTYsvhtwh
# YpnI2hv2bJGKNpm9hRT8ZpkG2JGjt9tt3hZEhtksAX/kQlp7KDky/Uv1JVo9A1pa
# kAICv6fMWZ7SIn0oTuxR9aUf5xfihgLr1OL6Riw7eLKA93pODj/NFxf67oRgM6Op
# PEoIcq09evXAOrPpcPkXpbN4kv06lRbwd5x3kYGmvHZx8CLfQhLYU9jWM9O+3xg4
# CHCHI3ZElRJOskVw7xl1ycsrHVL+4uYOxhyYJV9dPo5S+mZoU2evJY80jc+ymxPR
# U/KMZsLqDlaOMH5sWDnsR1/s/ks8+H97JszkFaulDSLZGM/jGWWN4wYqKOCB/Stu
# MR7QMPjWPjxqQnqTdkNePzws/phSH6QuNjgpXeb00ei0iuCbxjaF3Hy1xo/yRXpl
# doqAWoSv3Ob6+IUcILhwC9KGcbDDafIwGyjViXKkPDYZY7ggXbSJ+l72hRyIxaCZ
# EUPRQ2nyI7PH+7iSU19+vL+G5vimoCXCAXWHkk8UCCpxd3/787KsplFoj6deHO4y
# +JktXwqU4MLx+opruDj0j/A3e+FwC8kMToKU3Geh1ghchjDIdzAY3zFxIYnItY7E
# RMLSX7L5dcBeYzvmHikRx9HlDz5er+mpg317K8UaitMBPEFe0v0=
# SIG # End signature block
