$sysInfo = @{
  'Computer Name'   = $env:COMPUTERNAME
  'User'            = "$env:USERDOMAIN\$env:USERNAME"
  'OS Version'      = (Get-CimInstance Win32_OperatingSystem).Caption
  'Build Number'    = (Get-CimInstance Win32_OperatingSystem).BuildNumber
  'Architecture'    = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
  'Uptime (hrs)'    = [Math]::Round((New-TimeSpan -Start (gcim Win32_OperatingSystem).LastBootUpTime).TotalHours, 1)
  'Memory (GB)'     = "{0:N1}" -f ((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB)
  'Processor'       = (Get-CimInstance Win32_Processor)[0].Name
  'PowerShell Host' = $host.Name
  'Script Launch'   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

Write-Log "=== Workstation Environment Summary ==="
$sysInfo.GetEnumerator() | ForEach-Object {
  Write-Log ("{0}: {1}" -f $_.Key, $_.Value)
}
Write-Log "========================================"