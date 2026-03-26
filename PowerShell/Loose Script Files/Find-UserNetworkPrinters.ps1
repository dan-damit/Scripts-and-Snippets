$user = "jdoe"
$profilePath = "C:\Users\$user"
$hive = "$profilePath\NTUSER.DAT"
$tempKey = "HKU\Offline_$user"

# Load the hive
reg load $tempKey $hive | Out-Null

# Enumerate network printers
Get-ChildItem "Registry::$tempKey\Printers\Connections" |
    Select-Object PSChildName

# Enumerate printer-device mappings
Get-ItemProperty "Registry::$tempKey\Software\Microsoft\Windows NT\CurrentVersion\Devices"

# Unload hive
reg unload $tempKey | Out-Null