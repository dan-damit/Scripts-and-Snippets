# Start Logging
$logPath = "$PSScriptRoot\DSC_log.txt"
$VerbosePreference = "Continue"
[console]::ForegroundColor = "DarkCyan"
# Function to log messages (captures verbose details)
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $logPath
}
