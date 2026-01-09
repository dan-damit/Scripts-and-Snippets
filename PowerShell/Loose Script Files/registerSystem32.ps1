# Register System32 in SYSTEM PATH env variables
# Requires running elevated
$existing = [Environment]::GetEnvironmentVariable("Path", "Machine")
$new = "$existing;C:\Windows\System32"
[Environment]::SetEnvironmentVariable("Path", $new, "Machine")