
param(
    [string]$TaskName = '\Launch_GP_TimeClock'   # include folder if applicable
)
$ErrorActionPreference = 'Stop'

$sched = New-Object -ComObject 'Schedule.Service'
$sched.Connect()
$folderPath = [System.IO.Path]::GetDirectoryName($TaskName)
$leafName   = [System.IO.Path]::GetFileName($TaskName)
if ([string]::IsNullOrWhiteSpace($folderPath) -or $folderPath -eq '.') { $folderPath = '\' }
$folder = $sched.GetFolder($folderPath)
$task   = $folder.GetTask($leafName)

# System & Admins = Full, Users = Read/Execute
$sddl = 'D:(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGX;;;BU)'
$task.SetSecurityDescriptor($sddl, 0)
"Updated SDDL on task $TaskName to: $sddl"
