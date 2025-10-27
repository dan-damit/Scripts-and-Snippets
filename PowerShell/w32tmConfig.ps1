# Set external NTP source
w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update

# Restart time service
Restart-Service w32time

# Define task action
$action = New-ScheduledTaskAction -Execute "w32tm.exe" -Argument "/resync"

# Define trigger: daily at 12:00 PM
$trigger = New-ScheduledTaskTrigger -Daily -At 12:00PM

# Register task as SYSTEM
Register-ScheduledTask -TaskName "DailyTimeResync" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force