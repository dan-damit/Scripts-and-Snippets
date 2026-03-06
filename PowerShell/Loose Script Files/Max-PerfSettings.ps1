<# 
    Max-Performance Power Plan Hardener
    - Targets CURRENT active power scheme
    - Unhides key advanced settings
    - Forces maximum performance / minimum power saving on AC & DC

    Run in an elevated PowerShell session.
#>

# Ensure running as admin
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run this script in an elevated PowerShell session (Run as administrator)."
    exit 1
}

Write-Host "[*] Detecting active power scheme..." -ForegroundColor Cyan
$activeSchemeLine = powercfg /GETACTIVESCHEME 2>$null
if (-not $activeSchemeLine) {
    Write-Error "Unable to get active power scheme."
    exit 1
}

if ($activeSchemeLine -match 'GUID:\s+([0-9a-fA-F\-]+)') {
    $schemeGuid = $matches[1]
}
else {
    Write-Error "Failed to parse active power scheme GUID."
    exit 1
}

Write-Host "[*] Active scheme: $schemeGuid" -ForegroundColor Green

function Set-PerfValue {
    param(
        [Parameter(Mandatory)][string]$Scheme,
        [Parameter(Mandatory)][string]$SubGroup,
        [Parameter(Mandatory)][string]$Setting,
        [Parameter(Mandatory)][uint32]$ACValue,
        [Parameter(Mandatory)][uint32]$DCValue
    )

    powercfg /SETACVALUEINDEX $Scheme $SubGroup $Setting $ACValue | Out-Null
    powercfg /SETDCVALUEINDEX $Scheme $SubGroup $Setting $DCValue | Out-Null
}

function Unhide-Setting {
    param(
        [Parameter(Mandatory)][string]$SubGroup,
        [Parameter(Mandatory)][string]$Setting
    )
    powercfg -attributes $SubGroup $Setting -ATTRIB_HIDE 2>$null
}

Write-Host "[*] Unhiding key advanced settings..." -ForegroundColor Cyan

# GUIDs
$SUB_PROCESSOR = '54533251-82be-4824-96c1-47b60b740d00'
$MIN_PROC_STATE = '893dee8e-2bef-41e0-89c6-b55d0929964c'
$MAX_PROC_STATE = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
$COOLING_POLICY = '94d3a615-a899-4ac5-ae2b-e4d8f634367f'
$IDLE_DISABLE = '5d76a2ca-e8c0-402f-a133-2158492d58ad'
$BOOST_MODE = 'be337238-0d82-4146-a960-4f3749d470c7'

$SUB_PCIEXPRESS = '501a4d13-42af-4429-9fd1-a8218c268e20'
$ASPM_SETTING = 'ee12f906-d277-404b-b6da-e5fa1a576df5'

$SUB_USB = '4f971e89-eebd-4455-a8de-9e59040e7347'
$USB_SELECTIVE = '2a737441-1930-4402-8d77-b2bebba308a3'

$SUB_SLEEP = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
$SLEEP_IDLE = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'
$HYBRID_SLEEP = '94ac6d29-73ce-41a6-809f-6363ba21b47e'
$HIBERNATE_IDLE = '9d7815a6-7ee4-497e-8888-515a05f02364'

$SUB_VIDEO = '7516b95f-f776-4464-8c53-06167f40cc99'
$VIDEO_IDLE = '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'

$SUB_WIRELESS = '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1'
$WLAN_POLICY = '12bbebe6-58d6-4636-95bb-3217ef867c1a'

# Unhide processor settings
Unhide-Setting $SUB_PROCESSOR $MIN_PROC_STATE
Unhide-Setting $SUB_PROCESSOR $MAX_PROC_STATE
Unhide-Setting $SUB_PROCESSOR $COOLING_POLICY
Unhide-Setting $SUB_PROCESSOR $IDLE_DISABLE
Unhide-Setting $SUB_PROCESSOR $BOOST_MODE

# Unhide PCIe ASPM
Unhide-Setting $SUB_PCIEXPRESS $ASPM_SETTING

# Unhide USB selective suspend
Unhide-Setting $SUB_USB $USB_SELECTIVE

# Unhide sleep / hibernate
Unhide-Setting $SUB_SLEEP $SLEEP_IDLE
Unhide-Setting $SUB_SLEEP $HYBRID_SLEEP
Unhide-Setting $SUB_SLEEP $HIBERNATE_IDLE

# Unhide display idle
Unhide-Setting $SUB_VIDEO $VIDEO_IDLE

# Unhide wireless power saving
Unhide-Setting $SUB_WIRELESS $WLAN_POLICY

Write-Host "[*] Forcing maximum performance values..." -ForegroundColor Cyan

# Processor: 100% min/max, active cooling, disable idle, aggressive boost
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_PROCESSOR -Setting $MIN_PROC_STATE -ACValue 100 -DCValue 100
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_PROCESSOR -Setting $MAX_PROC_STATE -ACValue 100 -DCValue 100

# Cooling policy: 0 = Active
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_PROCESSOR -Setting $COOLING_POLICY -ACValue 0 -DCValue 0

# Disable idle states: 1 = Disable
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_PROCESSOR -Setting $IDLE_DISABLE -ACValue 1 -DCValue 1

# Boost mode: 2 = Aggressive (common mapping)
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_PROCESSOR -Setting $BOOST_MODE -ACValue 2 -DCValue 2

# PCIe ASPM: 0 = Off
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_PCIEXPRESS -Setting $ASPM_SETTING -ACValue 0 -DCValue 0

# USB selective suspend: 0 = Disabled
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_USB -Setting $USB_SELECTIVE -ACValue 0 -DCValue 0

# Sleep: never sleep, no hybrid, no hibernate timeout
# Sleep idle: 0 = Never
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_SLEEP -Setting $SLEEP_IDLE -ACValue 0 -DCValue 0
# Hybrid sleep: 0 = Off
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_SLEEP -Setting $HYBRID_SLEEP -ACValue 0 -DCValue 0
# Hibernate after: 0 = Never
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_SLEEP -Setting $HIBERNATE_IDLE -ACValue 0 -DCValue 0

# Display idle: 0 = Never turn off
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_VIDEO -Setting $VIDEO_IDLE -ACValue 0 -DCValue 0

# Wireless: 0 = Maximum Performance
Set-PerfValue -Scheme $schemeGuid -SubGroup $SUB_WIRELESS -Setting $WLAN_POLICY -ACValue 0 -DCValue 0

Write-Host "[*] Re-applying active scheme to ensure values are live..." -ForegroundColor Cyan
powercfg /SETACTIVE $schemeGuid | Out-Null

Write-Host ""
Write-Host "=== Max Performance Hardening Complete ===" -ForegroundColor Green
Write-Host "Scheme: $schemeGuid"
Write-Host "Open Control Panel -> Power Options -> Change plan settings -> Advanced to inspect the full tree."