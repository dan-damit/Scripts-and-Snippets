### Author: Dan.Damit https://github.com/dan-damit

### Set external NTP source and mark this server as reliable
w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update

### Restart time service
Restart-Service w32time

### Enable NTP server mode in registry
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer" -Name "Enabled" -Value 1

### Optional: Set AnnounceFlags to 5 (always reliable)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name "AnnounceFlags" -Value 5

### Open UDP 123 for inbound NTP traffic
New-NetFirewallRule -DisplayName "Allow NTP Server (UDP 123)" -Direction Inbound -Protocol UDP -LocalPort 123 -Action Allow

### Define task action (use full path to avoid PATH issues)
$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\w32tm.exe" -Argument "/resync"

### Define trigger: daily at 12:00 PM
$trigger = New-ScheduledTaskTrigger -Daily -At 12:00PM

### Register task as SYSTEM
Register-ScheduledTask -TaskName "DailyNTPServerResync" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest -Force