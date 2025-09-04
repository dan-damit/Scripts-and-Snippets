<#
.SYNOPSIS
    Queries all computers in a target OU and deploys a printer/driver in one pass
.DESCRIPTION
    - Gathers computers from AD OU
    - Runs remoting preflight (reachability, WinRM, PSSession type)
    - Calls Deploy-PrinterFleet logic against ready machines
.NOTES
    Run elevated (admin) from a machine with RSAT + remoting rights
#>

[CmdletBinding()]
param(
    # Adjust these for your environment
    [string]$OUdn          = "OU=Office PCs,DC=RFD,DC=lan",
    [string]$DriverSource  = "\\APL-DC-01\PrinterDriver", # exported driver folder
    [string]$PrinterShare  = "\\APL-DC-01\Front Desk Printer (HP OfficeJet)",
    [string[]]$ApprovedServers = @('APL-DC-01.RFD.lan','APL-FD-01.RFD.lan'),
    [switch]$ApplyPointAndPrintPolicy,
    [switch]$AllUsers,
    [object]$OperationTimeout = "00:15:00" # can be int seconds, TimeSpan, or "hh:mm:ss"
)

Import-Module ActiveDirectory -ErrorAction Stop

# --- Normalize timeout to seconds ---
$timeoutSeconds = if ($OperationTimeout -is [TimeSpan]) {
    [int]$OperationTimeout.TotalSeconds
}
elseif ($OperationTimeout -is [int]) {
    $OperationTimeout
}
elseif ($OperationTimeout) {
    $ts = [TimeSpan]::Parse($OperationTimeout)
    [int]$ts.TotalSeconds
}
else {
    900
}

$sessionOpts = New-PSSessionOption -OperationTimeout $timeoutSeconds

# --- Gather computers from OU ---
$Computers = Get-ADComputer -SearchBase $OUdn -Filter * |
             Select-Object -ExpandProperty Name |
             Sort-Object

Write-Host "Found $($Computers.Count) computer(s) in '$OUdn'" -ForegroundColor Cyan

# --- Preflight function ---
function Test-PSRemotingSupport {
    param([string]$ComputerName)

    $result = [pscustomobject]@{
        Computer      = $ComputerName
        Reachable     = $false
        WinRM         = $false
        PSSessionType = $false
        Reason        = $null
    }

    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
        $result.Reason = "Host unreachable (ping failed)"
        return $result
    }
    $result.Reachable = $true

    try {
        if (Test-WSMan -ComputerName $ComputerName -ErrorAction Stop) {
            $result.WinRM = $true
        }
    }
    catch {
        $result.Reason = "WinRM not responding"
        return $result
    }

    try {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            [void][System.Management.Automation.Runspaces.PSSession]
        } -ErrorAction Stop
        $result.PSSessionType = $true
    }
    catch {
        $result.Reason = "PSSession type not available"
        return $result
    }

    $result.Reason = "OK"
    return $result
}

# --- Run preflight ---
$preflightResults = foreach ($comp in $Computers) {
    Test-PSRemotingSupport -ComputerName $comp
}

$preflightResults | Format-Table -AutoSize

$readyComputers = $preflightResults | Where-Object { $_.Reason -eq 'OK' } |
                  Select-Object -ExpandProperty Computer

if (-not $readyComputers){
    Write-Warning "No computers passed preflight - aborting deployment."
	return
}

Write-Host "Proceeding with deployment to: $($readyComputers -join ', ')" -ForegroundColor Green

# --- Call Deploy-PrinterFleet.ps1 ---
.\Deploy-PrinterFleet.ps1 `
    -Computers $readyComputers `
    -DriverSource $DriverSource `
    -PrinterShare $PrinterShare `
    -ApprovedServers $ApprovedServers `
    -ApplyPointAndPrintPolicy:$ApplyPointAndPrintPolicy `
    -AllUsers:$AllUsers `
    -OperationTimeout $timeoutSeconds