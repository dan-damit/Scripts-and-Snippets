Configuration SystemConfiguration {

    # Define parameters
    param (
        [string]$StaticIPAddress
    )

    # Import-DSCResource is required for custom DSC resources
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    Node 'localhost' {

        # Set PowerShell execution policy
        Script SetExecutionPolicy {
            GetScript = { @{ Result = (Get-ExecutionPolicy -Scope LocalMachine) } }
            SetScript = { Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -Force }
            TestScript = { (Get-ExecutionPolicy -Scope LocalMachine) -eq 'Unrestricted' }
        }

        # disable Firewall
        WindowsFeature DisableFirewall {
            Name = "Windows-Firewall"
            Ensure = "Absent"
        }

        # Create folders and set permissions
        File InsightsFolder {
            DestinationPath = 'C:\advinsight'
            Ensure = 'Present'
            Type = 'Directory'
        }
        File WorkingFolder {
            DestinationPath = 'C:\working'
            Ensure = 'Present'
            Type = 'Directory'
        }
        # full access for Authenticated Users
        Script SetFolderPermissions {
            GetScript = { @{} }
            SetScript = { icacls 'C:\working' /grant 'Authenticated Users:(OI)(CI)M' }
            TestScript = { ((Get-Acl 'C:\working').Access | Where-Object { $_.IdentityReference -eq 'Authenticated Users' -and $_.FileSystemRights -match 'Modify' }) -ne $null }
            DependsOn = '[File]WorkingFolder'
        }
        # create our ADV eventlog
        Script CreateEventLogSource {
            GetScript = {
                @{ Result = (Get-EventLog -LogName AdvantageTechnologies).Sources -contains 'Advantage Insight' }
            }
            SetScript = {
                New-EventLog -LogName AdvantageTechnologies -Source 'Advantage Insight'
            }
            TestScript = {
                (Get-EventLog -LogName AdvantageTechnologies).Sources -contains 'Advantage Insight'
            }
        }
        # Set static IP address
        Script SetIPAddress {
            GetScript = { @{ Result = (Get-NetIPAddress -AddressFamily IPv4 | Select-Object -First 1 -ExpandProperty IPAddress) } }
            SetScript = { New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress $StaticIPAddress -PrefixLength 24 }
            TestScript = { (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -eq $StaticIPAddress}) -ne $null }
        }

        # Set DNS  8.8.8.8 and 4.4.4.4
        Script SetDNSServers {
            GetScript = { @{ Result = (Get-DnsClientServerAddress -InterfaceAlias 'Ethernet').ServerAddresses } }
            SetScript = { Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses ('8.8.8.8','4.4.4.4') }
            TestScript = { (Get-DnsClientServerAddress -InterfaceAlias 'Ethernet').ServerAddresses -contains '8.8.8.8' -and (Get-DnsClientServerAddress -InterfaceAlias 'Ethernet').ServerAddresses -contains '4.4.4.4' }
        }

        # Set user 'AdvAdmin' password to 'Staff!!' never expire
        User AdvAdminUser {
            UserName = 'AdvAdmin'
            Password = (ConvertTo-SecureString 'St@ff1234!' -AsPlainText -Force)
            Ensure = 'Present'
            PasswordChangeNotAllowed = $true
            PasswordNeverExpires = $true
        }

        # Install ScreenConnect if not present
        Script InstallScreenConnect {
            GetScript = { @{ Result = (Get-ItemProperty -Path 'HKLM:\Software\ScreenConnect' -ErrorAction SilentlyContinue) } }
            SetScript = { Start-Process -FilePath 'Path\to\ScreenConnectInstaller.exe' -ArgumentList '/qn' -Wait }
            TestScript = { (Get-ItemProperty -Path 'HKLM:\Software\ScreenConnect' -ErrorAction SilentlyContinue) -ne $null }
        }

        # Install Huntress if not present
        Script InstallHuntress {
            GetScript = { @{ Result = (Get-ItemProperty -Path 'HKLM:\Software\Huntress Labs' -ErrorAction SilentlyContinue) } }
            SetScript = { Start-Process -FilePath 'Path\to\HuntressInstaller.exe' -ArgumentList '/qn' -Wait }
            TestScript = { (Get-ItemProperty -Path 'HKLM:\Software\Huntress Labs' -ErrorAction SilentlyContinue) -ne $null }
        }

        # Install the latest version of PowerShell PackageManagement
        Package PackageManagement {
            Name = 'PackageManagement'
            Ensure = 'Present'
            Source = 'PSGallery'
        }

        # Install PSWindowsUpdate PowerShell module
        Script InstallPSWindowsUpdateModule {
            GetScript = { @{ Result = (Get-Module -Name 'PSWindowsUpdate' -ListAvailable) } }
            SetScript = { Install-Module -Name 'PSWindowsUpdate' -Force -Scope AllUsers }
            TestScript = { (Get-Module -Name 'PSWindowsUpdate' -ListAvailable) -ne $null }
        }
    }
}

# Apply the configuration
SystemConfiguration -StaticIPAddress '192.168.1.100'  # Replace with desired IP
Start-DscConfiguration -Path .\SystemConfiguration -Wait -Verbose -Force