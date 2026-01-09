function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Info','Ok','Warn','Error')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    # Pull logging config
    $cfg = $Global:TechToolboxConfig.Logging
    $paths = $Global:TechToolboxConfig.Paths

    # Timestamp
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    # Build log entry
    $entry = "[{0}] [{1}] {2}" -f $timestamp, $Level.ToUpper(), $Message

    # ----- Console Output -----
    if ($cfg.EnableConsole) {
        switch ($Level) {
            'Info'  { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
            'Ok'    { Write-Host "[ OK ] $Message" -ForegroundColor Green }
            'Warn'  { Write-Warning $Message }
            'Error' { Write-Host "[ERR ] $Message" -ForegroundColor Red }
        }
    }

    # ----- File Logging -----
    if ($cfg.EnableFileLogging -and $paths.LogDirectory) {

        # Ensure directory exists
        if (-not (Test-Path $paths.LogDirectory)) {
            New-Item -ItemType Directory -Path $paths.LogDirectory -Force | Out-Null
        }

        # Build log file path
        $fileName = $cfg.LogFileNameFormat
        $fileName = $fileName -replace '{yyyyMMdd}', (Get-Date -Format 'yyyyMMdd')
        $logFile = Join-Path $paths.LogDirectory $fileName

        # Write entry
        Add-Content -Path $logFile -Value $entry
    }
}