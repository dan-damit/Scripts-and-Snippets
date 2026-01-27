
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
        [string]$Path,
        [string]$Description
    )
    Write-Host "`n[Orchestrator] Running: $Description"
    if (-not (Test-Path $Path)) {
        Write-Error "[Orchestrator] Missing script: $Path"
        exit 1
    }
    & $Path
    Write-Host "[Orchestrator] Completed: $Description"
}

# STEP 1 — create DPAPI master key and save encrypted password file
Start-Step ".\save_svc_gp_password.ps1" "Save svc_gp encrypted password"

# Validate outputs
if ((Test-Path ".\dpapi_machine.key") -and (Test-Path ".\svc_gp.cred.xml")) {
    Write-Host "[Orchestrator] ✔ svc_gp password saved successfully."
} else {
    Write-Error "[Orchestrator] ❌ Failed to save svc_gp password."
    exit 1
}

# STEP 2 — create scheduled task for Supervisor Time Logger
Start-Step ".\GP2018 Supervisor Time Logger\launch_Supervisor_timelog_task.ps1" `
         "Create Supervisor Time Logger scheduled task"

# STEP 3 — set group/user permissions + optional shortcut
Start-Step ".\SetUserPropertiesForSupervisorTimeLoggerTask.ps1 -CreateDesktopShortcut \$true" `
         "Set Supervisor Time Logger permissions"

# STEP 4 — create scheduled task for TimeClock
Start-Step ".\launch_timelcock_task.ps1" `
         "Create TimeClock scheduled task"

# STEP 5 — assign permissions + shortcut
Start-Step ".\SetUserPropertiesForTimeClockTask.ps1 -CreateDesktopShortcut \$true" `
         "Set TimeClock permissions"

Write-Host "`n=== [Orchestrator] Setup completed successfully! ===`n"