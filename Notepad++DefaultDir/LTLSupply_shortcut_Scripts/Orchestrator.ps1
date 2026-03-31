[CmdletBinding()]
param(
    [switch]$CreateDesktopShortcut
)

# Orchestrator for setting up elevated TimeClock + Supervisor Time Logger launch tasks
# Ensures LTL users can run both apps without admin rights.

$ErrorActionPreference = "Stop"

Write-Host "`n=== [Orchestrator] Starting setup ===`n"

# Ensure we run in the orchestrator's directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir
Write-Host "[Orchestrator] Working directory: $scriptDir"

# Helper: Run a script and confirm execution
function Start-Step {
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Description,
        [object[]]$Args = @()
    )
    Write-Host "`n[Orchestrator] Running: $Description"
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "[Orchestrator] Missing script: $Path"
        exit 1
    }
    & $Path @Args
    Write-Host "[Orchestrator] Completed: $Description"
}

# STEP 1 — create DPAPI master key and save encrypted password file
Start-Step ".\save_svc_gp_password.ps1" "Save svc_gp encrypted password"

# Validate outputs
if ((Test-Path ".\dpapi_machine.key") -and (Test-Path ".\svc_gp.cred.xml")) {
    Write-Host "[Orchestrator] svc_gp password saved successfully."
}
else {
    Write-Error "[Orchestrator] Failed to save svc_gp password."
    exit 1
}

# Paths
$stlDir = Join-Path $scriptDir "GP2018 Supervisor Time Logger"
$tcDir  = Join-Path $scriptDir "GP2018 Time Clock"

# Args for scripts that support shortcut creation
$shortcutArgs = if ($CreateDesktopShortcut.IsPresent) { @('-CreateDesktopShortcut') } else { @() }

# STEP 2 — Supervisor Time Logger scheduled task
Start-Step (Join-Path $stlDir "launch_Supervisor_timelog_task.ps1") `
    "Create Supervisor Time Logger scheduled task" `
    $shortcutArgs

# STEP 3 — Supervisor Time Logger permissions
Start-Step (Join-Path $stlDir "SetUserPropertiesForSupervisorTimeLoggerTask.ps1") `
    "Set Supervisor Time Logger permissions"

# STEP 4 — Time Clock scheduled task
Start-Step (Join-Path $tcDir "launch_timeclock_task.ps1") `
    "Create TimeClock scheduled task" `
    $shortcutArgs

# STEP 5 — Time Clock permissions
Start-Step (Join-Path $tcDir "SetUserPropertiesForTimeClockTask.ps1") `
    "Set TimeClock permissions"

Write-Host "`n=== [Orchestrator] Setup completed successfully! ===`n"
