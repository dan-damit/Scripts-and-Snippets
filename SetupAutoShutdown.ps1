$taskName   = "AutoShutdownMonitor"
$scriptPath = "C:\ProgramData\AutoShutdown\AutoShutdown.ps1"

# Remove old task if present
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger1 = New-ScheduledTaskTrigger -AtStartup
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -RepetitionDuration (New-TimeSpan -Days 365)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger1,$trigger2 -RunLevel Highest -Description "Shutdown if no sleep blockers for 5 hours"