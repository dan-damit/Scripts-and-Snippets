
<# 
  Set custom pagefile sizes on Windows with PowerShell 7+ (requires admin).

  - Disables automatic pagefile management
  - Sets InitialSize/MaximumSize on Win32_PageFileSetting
  - Prompts for reboot

  Run on Windows only. Tested on PS 7.x.
#>

# region: preflight checks
# Ensure we are on Windows and PS7+
if (-not $IsWindows) {
    Write-Error "This script can only run on Windows. Exiting."
    exit 1
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "You're running PowerShell $($PSVersionTable.PSVersion). This script is designed for PowerShell 7+. It may still work, but PS7 is recommended."
}

Function Test-Administrator {
    try {
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

# Relaunch as admin if needed
if (-not (Test-Administrator)) {
    Write-Host "This script requires administrative privileges. Restarting as admin in 5 seconds..." -ForegroundColor Red

    for ($i = 5; $i -gt 0; $i--) {
        Write-Host ("`rStarting in {0}s..." -f $i) -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host "`rStarting now...      "

    # Re-run using pwsh (PowerShell 7)
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        Write-Error "Cannot determine current script path. Save and run the script file, or run with -File."
        exit 1
    }

    Start-Process -FilePath "pwsh" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"") -Verb RunAs
    exit
}
# endregion

# region: input
# Default pagefile name/path: usually C:\pagefile.sys
# You can prompt for a drive if you want; for now assume C:\
$pagefilePath = "C:\pagefile.sys"

# Simple numeric validators
function Read-Int([string]$Prompt, [int]$Min = 16, [int]$Max = 131072) {
    while ($true) {
        $value = Read-Host $Prompt
        if ([int]::TryParse($value, [ref]$parsed)) {
            if ($parsed -ge $Min -and $parsed -le $Max) { return $parsed }
            Write-Host "Enter a value between $Min and $Max." -ForegroundColor Yellow
        } else {
            Write-Host "Enter a whole number (MB)." -ForegroundColor Yellow
        }
    }
}

$InitialSize = Read-Int "Enter the initial pagefile size in MB (e.g., 2048)"
$MaximumSize = Read-Int "Enter the maximum pagefile size in MB (must be >= initial)" $InitialSize 2097152

# Sanity check
if ($MaximumSize -lt $InitialSize) {
    Write-Error "Maximum size must be greater than or equal to initial size."
    exit 1
}
# endregion

# region: apply settings via CIM
try {
    # Disable automatic management
    $computersys = Get-CimInstance -ClassName Win32_ComputerSystem
    if ($computersys.AutomaticManagedPagefile) {
        $computersys | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false } | Out-Null
        Write-Host "Automatic pagefile management disabled." -ForegroundColor Cyan
    } else {
        Write-Host "Automatic pagefile management is already disabled." -ForegroundColor DarkCyan
    }

    # Retrieve existing PageFileSetting for the target path (if any)
    $pagefile = Get-CimInstance -ClassName Win32_PageFileSetting -Filter "Name='$pagefilePath'"

    if (-not $pagefile) {
        Write-Host "No existing pagefile setting found for $pagefilePath. Creating..." -ForegroundColor Cyan
        $pagefile = New-CimInstance -ClassName Win32_PageFileSetting -Property @{
            Name        = $pagefilePath
            InitialSize = [int]$InitialSize
            MaximumSize = [int]$MaximumSize
        }
    } else {
        # Update existing setting
        $pagefile | Set-CimInstance -Property @{
            InitialSize = [int]$InitialSize
            MaximumSize = [int]$MaximumSize
        } | Out-Null
    }

    Write-Host "Pagefile sizes updated successfully: $pagefilePath (Initial=$InitialSize MB, Max=$MaximumSize MB)" -ForegroundColor Green
} catch {
    Write-Error "Failed to configure pagefile: $($_.Exception.Message)"
    exit 1
}
# endregion

# region: reboot prompt
$response = Read-Host "Would you like to reboot now? y/n"
if ($response -match '^(y|yes)$') {
    Write-Host "Rebooting now..." -ForegroundColor Green
    try {
        Restart-Computer -Force
    } catch {
        Write-Error "Failed to reboot: $($_.Exception.Message)"
    }
} else {
    Write-Host "You can reboot later to apply the changes." -ForegroundColor Yellow
    Pause
}
# endregion
