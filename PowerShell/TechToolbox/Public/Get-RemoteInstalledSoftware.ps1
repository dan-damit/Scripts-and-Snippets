
function Get-RemoteInstalledSoftware {
    <#
    .SYNOPSIS
        Collects installed software from remote Windows computers via PSRemoting
        (registry uninstall keys + optional Appx).
    .DESCRIPTION
        Connects to remote hosts with Invoke-Command, enumerates machine/user
        uninstall registry entries (x64/x86), optionally includes Appx/MSIX
        packages, returns objects, writes a summary table to the information
        stream, and exports per-host CSVs or a consolidated CSV.
    .PARAMETER ComputerName
        One or more remote computer names to query. (Requires WinRM enabled and
        appropriate permissions)
    .PARAMETER Credential
        Credentials used for the remote session. If omitted, current identity is
        attempted; you may be prompted.
    .PARAMETER IncludeAppx
        Include Windows Store (Appx/MSIX) packages. Can be slower and requires
        admin rights on remote hosts.
    .PARAMETER OutDir
        Output directory for CSV exports. Defaults to TechToolbox config
        Paths.ExportDirectory.
    .PARAMETER Consolidated
        Write a single consolidated CSV for all hosts
        (InstalledSoftware_AllHosts_<timestamp>.csv). If omitted, writes one CSV
        per host.
    .PARAMETER ThrottleLimit
        Concurrency limit for Invoke-Command. Default 32.
    .OUTPUTS
        [pscustomobject]
    .EXAMPLE
        Get-RemoteInstalledSoftware -ComputerName server01,server02 -Consolidated
    .EXAMPLE
        Get-RemoteInstalledSoftware -ComputerName laptop01 -IncludeAppx -Credential (Get-Credential)
    .NOTES
        Avoids Win32_Product due to performance/repair risk. Requires PSRemoting
        (WinRM) enabled. SSL and cert relaxation options can be set in config.json.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$ComputerName,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [switch]$IncludeAppx,

        [Parameter()]
        [string]$OutDir,

        [Parameter()]
        [switch]$Consolidated,

        [Parameter()]
        [ValidateRange(1, 128)]
        [int]$ThrottleLimit = 32
    )

    begin {
        # --- Config & Session Options ---
        $cfg = Get-TechToolboxConfig
        $defaults = $cfg.RemoteSoftwareInventory  # may be $null if section not present

        # Default OutDir from config if not provided
        if ($defaults) {
            if (-not $PSBoundParameters.ContainsKey('IncludeAppx') -and $defaults.IncludeAppx) { $IncludeAppx = [switch]::Present }
            if (-not $PSBoundParameters.ContainsKey('Consolidated') -and $defaults.Consolidated) { $Consolidated = [switch]::Present }
            if (-not $PSBoundParameters.ContainsKey('ThrottleLimit') -and $defaults.ThrottleLimit) { $ThrottleLimit = [int]$defaults.ThrottleLimit }
        }

        # --- Build session parameters only if needed ---
        $sessionParams = @{}
        if ($defaults -and $defaults.SessionOptions) {
            $soNeeded = $false
            $so = New-PSSessionOption

            if ($defaults.SessionOptions.SkipCACheck) { $so.SkipCACheck = $true; $soNeeded = $true }
            if ($defaults.SessionOptions.SkipCNCheck) { $so.SkipCNCheck = $true; $soNeeded = $true }
            if ($defaults.SessionOptions.SkipRevocationCheck) { $so.SkipRevocationCheck = $true; $soNeeded = $true }

            if ($soNeeded) { $sessionParams.SessionOption = $so }

            # UseSSL only if explicitly enabled
            if ($defaults.SessionOptions.UseSsl) {
                $sessionParams.UseSSL = $true
            }

            # Log applied session options
            if ($sessionParams.UseSSL -or $sessionParams.SessionOption) {
                $flags = @()
                if ($sessionParams.UseSSL) { $flags += 'UseSSL' }
                if ($sessionParams.SessionOption) {
                    if ($sessionParams.SessionOption.SkipCACheck) { $flags += 'SkipCACheck' }
                    if ($sessionParams.SessionOption.SkipCNCheck) { $flags += 'SkipCNCheck' }
                    if ($sessionParams.SessionOption.SkipRevocationCheck) { $flags += 'SkipRevocationCheck' }
                }
                Write-Log -Level Info -Message ("Session options will be applied: {0}" -f ($flags -join ', '))
            }
            else {
                Write-Log -Level Info -Message "Session options not applied (UseSsl=false and no skip-checks)."
            }
        }

        # Credential Prompting
        if (-not $PSBoundParameters.ContainsKey('Credential') -and -not $Credential) {
            Write-Log -Level Info -Message 'No credential provided; you will be prompted (or current identity will be used if allowed).'
            try {
                $Credential = Get-Credential -Message 'Enter credentials to connect to remote computers (or Cancel to use current identity)'
            }
            catch {
                # If user cancels, $Credential remains $null; Invoke-Command will try current identity.
            }
        }
    }

    process {
        # Remote scriptblock that runs on each target
        $scriptBlock = {
            param([bool]$IncludeAppx)

            function Convert-InstallDate {
                [CmdletBinding()]
                param([string]$Raw)
                if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
                $s = $Raw.Trim()
                if ($s -match '^\d{8}$') {
                    try { return [datetime]::ParseExact($s, 'yyyyMMdd', $null) } catch { }
                }
                try { return [datetime]::Parse($s) } catch { return $null }
            }

            function Get-UninstallFromPath {
                [CmdletBinding()]
                param(
                    [Parameter(Mandatory)][string]$RegPath,
                    [Parameter(Mandatory)][string]$Scope,
                    [Parameter(Mandatory)][string]$Arch
                )
                $results = @()
                try {
                    $keys = Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue
                    foreach ($k in $keys) {
                        $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                        if ($p.DisplayName) {
                            $results += [PSCustomObject]@{
                                ComputerName    = $env:COMPUTERNAME
                                DisplayName     = $p.DisplayName
                                DisplayVersion  = $p.DisplayVersion
                                Publisher       = $p.Publisher
                                InstallDate     = Convert-InstallDate $p.InstallDate
                                UninstallString = $p.UninstallString
                                InstallLocation = $p.InstallLocation
                                EstimatedSizeKB = $p.EstimatedSize
                                Scope           = $Scope
                                Architecture    = $Arch
                                Source          = 'Registry'
                                RegistryPath    = $k.PSPath
                            }
                        }
                    }
                }
                catch { }
                return $results
            }

            $items = @()
            # Machine-wide installs
            $items += Get-UninstallFromPath -RegPath "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"                -Scope 'Machine' -Arch 'x64'
            $items += Get-UninstallFromPath -RegPath "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"    -Scope 'Machine' -Arch 'x86'
            # Current user hive
            $items += Get-UninstallFromPath -RegPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"                -Scope 'User (Current)' -Arch 'x64'
            $items += Get-UninstallFromPath -RegPath "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"    -Scope 'User (Current)' -Arch 'x86'
            # Other loaded user hives (HKU) - covers logged-on users
            try {
                $userHives = Get-ChildItem HKU:\ -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^HKEY_USERS\\S-1-5-21-' }
                foreach ($hive in $userHives) {
                    $sid = $hive.PSChildName
                    $x64Path = "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                    $x86Path = "HKU:\$sid\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                    $items += Get-UninstallFromPath -RegPath $x64Path -Scope "User ($sid)" -Arch 'x64'
                    $items += Get-UninstallFromPath -RegPath $x86Path -Scope "User ($sid)" -Arch 'x86'
                }
            }
            catch { }

            if ($IncludeAppx) {
                try {
                    $items += Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
                        [PSCustomObject]@{
                            ComputerName    = $env:COMPUTERNAME
                            DisplayName     = $_.Name
                            DisplayVersion  = $_.Version.ToString()
                            Publisher       = $_.Publisher
                            InstallDate     = $null
                            UninstallString = $null
                            InstallLocation = $_.InstallLocation
                            EstimatedSizeKB = $null
                            Scope           = 'Appx (AllUsers)'
                            Architecture    = 'Appx/MSIX'
                            Source          = 'Appx'
                            RegistryPath    = $_.PackageFullName
                        }
                    }
                }
                catch { }
            }
            $items
        }

        # Execute across one or many computers
        $results = $null
        try {
            $invocationParams = @{
                ComputerName  = $ComputerName
                ScriptBlock   = $scriptBlock
                ArgumentList  = @($IncludeAppx.IsPresent)
                ErrorAction   = 'Stop'
                ThrottleLimit = $ThrottleLimit
            }

            if ($Credential) { $invocationParams.Credential = $Credential }
            foreach ($k in $sessionParams.Keys) { $invocationParams[$k] = $sessionParams[$k] }
            try { $results = Invoke-Command @invocationParams }
            
            catch {
                if ($sessionParams.UseSSL) {
                    Write-Log -Level Error -Message "HTTPS WinRM (-UseSSL) is enabled by config, but connection failed. Ensure the remote hosts are configured for WinRM over SSL."
                }
                throw
            }
        }
        catch {
            Write-Log -Level Error -Message ("Remote command failed: {0}" -f $_.Exception.Message)
            return
        }

        if (-not $results -or $results.Count -eq 0) {
            Write-Log -Level Warn -Message 'No entries returned. Possible causes: insufficient rights, empty uninstall keys, or connectivity issues.'
        }

        # Write a tidy table to information stream (avoid Write-Host)
        $table = $results |
        Sort-Object ComputerName, DisplayName, DisplayVersion |
        Format-Table ComputerName, DisplayName, DisplayVersion, Publisher, Scope, Architecture -AutoSize |
        Out-String
        Write-Information $table

        # Export CSV(s) (honors -WhatIf/-Confirm)
        $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        if ($Consolidated) {
            $consolidatedPath = Join-Path $OutDir ("InstalledSoftware_AllHosts_{0}.csv" -f $stamp)
            if ($PSCmdlet.ShouldProcess($consolidatedPath, 'Export consolidated CSV')) {
                try {
                    $results |
                    Sort-Object ComputerName, DisplayName, DisplayVersion |
                    Export-Csv -Path $consolidatedPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Level Ok -Message ("Consolidated export written: {0}" -f $consolidatedPath)
                }
                catch {
                    Write-Log -Level Warn -Message ("Failed to write consolidated CSV: {0}" -f $_.Exception.Message)
                }
            }
        }
        else {
            # Per-host export
            $grouped = $results | Group-Object ComputerName
            foreach ($g in $grouped) {
                $csvPath = Join-Path $OutDir ("{0}_InstalledSoftware_{1}.csv" -f $g.Name, $stamp)
                if ($PSCmdlet.ShouldProcess($csvPath, "Export CSV for $($g.Name)")) {
                    try {
                        $g.Group |
                        Sort-Object DisplayName, DisplayVersion |
                        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                        Write-Log -Level Ok -Message ("{0} export written: {1}" -f $g.Name, $csvPath)
                    }
                    catch {
                        Write-Log -Level Warn -Message ("Failed to write CSV for {0}: {1}" -f $g.Name, $_.Exception.Message)
                    }
                }
            }
        }

        # Return objects to pipeline consumers
        return $results
    }
}
