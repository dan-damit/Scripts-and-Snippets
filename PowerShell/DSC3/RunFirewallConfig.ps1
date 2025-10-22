# Executing test in C:\DSC with DSCv3.1.1 exe file in the same dir
# Simulated a process-scoped env variable for this test

$env:NINJA_FIREWALLENABLED = "true"  # or "false"
$firewallValue = if ($env:NINJA_FIREWALLENABLED -eq "true") { 1 } else { 0 }

$config = [ordered]@{
    '$schema' = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
    resources = @(
        @{
            name = 'ConfigureFirewall'
            type = 'Microsoft.Windows/Registry'
            properties = @{
                _exist = $true
                keyPath = 'HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile'
                valueName = 'EnableFirewall'
                valueData = @{
                    DWord = $firewallValue
                }
            }
        }
    )
}

$config | ConvertTo-Json -Depth 5 | Set-Content .\FirewallToggle.dsc.json
.\dsc.exe config set --file .\FirewallToggle.dsc.json

<#
Further Notes:
-Found a module for Powershell 5.x that converts to YAML
-Install-Module powershell-yaml
-This module functions like ConvertTo-Json that ships with PowerShell
-ConvertTo-Yaml
#>