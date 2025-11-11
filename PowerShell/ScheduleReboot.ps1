$action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /t 0"
$trigger = New-ScheduledTaskTrigger -Once -At "20:00"
Register-ScheduledTask -TaskName "ScheduledReboot8PM" -Action $action -Trigger $trigger -Description "OneTime reboot at 8PM" -User "SYSTEM" -RunLevel Highest -Force