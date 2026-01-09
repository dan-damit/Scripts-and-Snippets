# Author: Dan.Damit https://github.com/dan-damit

# Set external NTP source and only used if NTP server isn't found locally
w32tm /config /syncfromflags:all /manualpeerlist:"time.windows.com,0x1" /reliable:YES /update

# Restart time service
Restart-Service w32time

# Define task action
# C:\Windows\System32 must be registered in at least the current session PATH
# Ideally register it system wide for future task scheduled event
# Or use full path in the -Execute param
$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\w32tm.exe" -Argument "/resync"

# Define trigger: daily at 12:00 PM
$trigger = New-ScheduledTaskTrigger -Daily -At 12:00PM

# Register task as SYSTEM
Register-ScheduledTask -TaskName "DailyTimeResync" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force