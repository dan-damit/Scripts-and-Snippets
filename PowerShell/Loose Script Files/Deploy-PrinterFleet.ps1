<#
.SYNOPSIS
 One-pass deployment of a network printer:
  - Copy exported driver package to each machine
  - Pre-stage via pnputil
  - (Optional) Lock Point-and-Print to approved server(s)
  - Map printer for all users
  - Log per machine

.NOTES
 - Run as an admin with PS Remoting access to targets.
 - Requires the driver folder exported from pnputil (/export-driver).
 - Safe-by-default: does NOT broadly relax PrintNightmare mitigations.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string[]] $Computers,

    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path $_ })]
    [string] $DriverSource,                    # UNC or local folder containing *.inf + binaries (exported)

    [Parameter(Mandatory=$true)]
    [string] $PrinterShare,                    # e.g. \\PRINTSRV\Front Desk Printer

    [string[]] $ApprovedServers,               # e.g. 'PRINTSRV', 'print01.domain.local'

    [switch] $ApplyPointAndPrintPolicy,        # If set, restricts to ApprovedServers (no broad relax)

    [string] $RemoteDriverPath = 'C:\ProgramData\PrinterDeploy\Driver',

    [string] $RemoteLogPath = 'C:\ProgramData\PrinterDeploy\Logs',

    [switch] $AllUsers,                        # Map printer for all users (machine-wide) via PrintUIEntry /ga

    [switch] $WhatIfOnly,                      # Dry-run
	
	[object] $OperationTimeout
)

begin { 
	
    $ErrorActionPreference = 'Stop'

    # Normalize timeout to seconds (accepts [int], [TimeSpan], or "hh:mm:ss")
    $timeoutSeconds = if ($OperationTimeout -is [TimeSpan]) {
        [int]$OperationTimeout.TotalSeconds
    }
    elseif ($OperationTimeout -is [int]) {
        $OperationTimeout
    }
    elseif ($OperationTimeout) {
        $timeoutSpan = [TimeSpan]::Parse($OperationTimeout)
        [int]$timeoutSpan.TotalSeconds
    }
    else {
        900 # default 15 min
    }

    # Honor custom dry-run switch globally (pairs well with SupportsShouldProcess)
    if ($WhatIfOnly) { $WhatIfPreference = $true }

    # Real remoting session options
    $sessionOpts = New-PSSessionOption -OperationTimeout $timeoutSeconds

    $results     = @()
    $startStamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    Write-Host "Starting deployment at $startStamp (timeout ${timeoutSeconds}s)" -ForegroundColor Cyan

    function Copy-DriverToRemote {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [Parameter(Mandatory)] [string]    $Computer,
            [Parameter(Mandatory)] [PSSession] $Sess,
            [Parameter(Mandatory)] [string]    $Source,
            [Parameter(Mandatory)] [string]    $Dest
        )

        if ($PSCmdlet.ShouldProcess($Computer, "Ensure '$Dest' exists")) {
            Invoke-Command -Session $Sess -ScriptBlock {
                param($DestPath)
                New-Item -Path $DestPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            } -ArgumentList $Dest
        }

        if ($PSCmdlet.ShouldProcess($Computer, "Copy driver package to '$Dest'")) {
            Write-Verbose "[$Computer] Copying driver package from '$Source' to '$Dest'"
            Copy-Item -Path (Join-Path $Source '*') -Destination $Dest -Recurse -Force -ToSession $Sess
        }
    }

    $scriptBlock = {
        param(
            [string]   $DriverPath,
            [string]   $PrinterShare,
            [string[]] $ApprovedServers,
            [bool]     $ApplyPnPPolicy,
            [string]   $LogRoot,
            [bool]     $AllUsersFlag,
            [bool]     $WhatIfOnlyInner
        )

        # Respect WhatIf inside the remote context
        if ($WhatIfOnlyInner) { $WhatIfPreference = $true }
        $ErrorActionPreference = 'Stop'

        $null = New-Item -Path $LogRoot -ItemType Directory -Force
        $logFile = Join-Path $LogRoot ("PrinterDeploy_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
        Start-Transcript -Path $logFile -Force | Out-Null

        try {
            Write-Output "=== Host: $env:COMPUTERNAME ==="
            Write-Output "DriverPath: $DriverPath"
            Write-Output "PrinterShare: $PrinterShare"

            # Ensure spooler is up
            Write-Output "Ensuring Spooler is running..."
            $svc = Get-Service -Name Spooler -ErrorAction Stop
            if ($svc.Status -ne 'Running') { Start-Service Spooler -ErrorAction Stop }

            # Pre-stage all *.inf in the driver path
            $infFiles = Get-ChildItem -Path $DriverPath -Filter *.inf -Recurse -ErrorAction Stop
            if (-not $infFiles -or $infFiles.Count -eq 0) {
                throw "No INF files found under $DriverPath"
            }

            foreach ($inf in $infFiles) {
                Write-Output "Staging driver: $($inf.FullName)"
                $p = Start-Process -FilePath pnputil.exe `
                                   -ArgumentList @('/add-driver', "`"$($inf.FullName)`"", '/install') `
                                   -NoNewWindow -Wait -PassThru
                if ($p.ExitCode -ne 0) {
                    throw "pnputil failed ($($p.ExitCode)) for $($inf.Name)"
                }
            }

            # Optional: restrict Point-and-Print to approved servers (secure posture)
            if ($ApplyPnPPolicy -and $ApprovedServers -and $ApprovedServers.Count -gt 0) {
                $baseKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
                New-Item -Path $baseKey -Force | Out-Null
                New-ItemProperty -Path $baseKey -Name 'Restricted'     -PropertyType DWord      -Value 1   -Force | Out-Null
                New-ItemProperty -Path $baseKey -Name 'TrustedServers' -PropertyType DWord      -Value 1   -Force | Out-Null
                $list = ($ApprovedServers | Sort-Object -Unique)
                New-ItemProperty -Path $baseKey -Name 'ServerList'     -PropertyType MultiString -Value $list -Force | Out-Null
                Write-Output "Applied Point-and-Print restriction to servers: $($list -join ', ')"
            }

            # Map the printer
            if ($AllUsersFlag) {
                $args = "/q /ga /n `"$PrinterShare`""
                Write-Output "Adding machine-wide printer connection via PrintUIEntry: $PrinterShare"
                $p2 = Start-Process -FilePath rundll32.exe -ArgumentList "printui.dll,PrintUIEntry $args" -NoNewWindow -Wait -PassThru
                if ($p2.ExitCode -ne 0) { throw "PrintUIEntry /ga failed ($($p2.ExitCode))" }
                Restart-Service -Name Spooler -Force -ErrorAction Stop
            } else {
                Write-Output "Adding per-context printer connection: $PrinterShare"
                Add-Printer -ConnectionName $PrinterShare -ErrorAction Stop
            }

            Write-Output "Done."
            Stop-Transcript | Out-Null
            [PSCustomObject]@{ Computer=$env:COMPUTERNAME; Success=$true; Log=$logFile }
        }
        catch {
            $msg = $_.Exception.Message
            Write-Output "ERROR: $msg"
            Stop-Transcript | Out-Null
            [PSCustomObject]@{ Computer=$env:COMPUTERNAME; Success=$false; Log=$logFile; Error=$msg }
        }
    }
}

process {
    foreach ($computer in $Computers) {
        try {
            Write-Verbose "[$computer] Opening session (timeout ${timeoutSeconds}s)"
            $sess = New-PSSession -ComputerName $computer -SessionOption $sessionOpts -ErrorAction Stop

            # Ensure remote driver/log paths and copy payload
            Copy-DriverToRemote -Computer $computer -Sess $sess -Source $DriverSource -Dest $RemoteDriverPath

            # Execute deployment on the remote host
            $res = Invoke-Command -Session $sess -ScriptBlock $scriptBlock -ArgumentList @(
                $RemoteDriverPath,
                $PrinterShare,
                $ApprovedServers,
                [bool]$ApplyPointAndPrintPolicy.IsPresent,
                $RemoteLogPath,
                [bool]$AllUsers.IsPresent,
                [bool]$WhatIfOnly.IsPresent
            )

            $results += $res
        }
        catch {
            $results += [PSCustomObject]@{ Computer=$computer; Success=$false; Error=$_.Exception.Message; Log=$null }
            Write-Warning "[$computer] Failed: $($_.Exception.Message)"
        }
        finally {
            if ($sess) { Remove-PSSession $sess -ErrorAction SilentlyContinue }
        }
    }
}

end {
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    $ok = $results | Where-Object { $_.Success }
    $bad = $results | Where-Object { -not $_.Success }
    Write-Host ("Success: {0}, Failed: {1}" -f $ok.Count, $bad.Count)
    if ($bad.Count -gt 0) {
        $bad | Format-Table -AutoSize
    }
}