
function Write-Log {
    <#
    .SYNOPSIS
        Centralized logging for TechToolbox (Info/Ok/Warn/Error).
    .DESCRIPTION
        Uses module config (Paths, Logging) and writes to PowerShell streams and (optionally) to a daily log file.
    .PARAMETER Level
        One of: Info, Ok, Warn, Error.
    .PARAMETER Message
        Text to log.
    .EXAMPLE
        Write-Log -Level Info -Message "Starting task."
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Ok', 'Warn', 'Error')]
        [string] $Level,

        [Parameter(Mandatory)]
        [string] $Message
    )

    $cfg = Get-TechToolboxConfig
    $log = $cfg.Logging
    $paths = $cfg.Paths

    # Level map for filtering (MinimumLevel from config)
    $severityMap = @{
        'Info'  = 1
        'Ok'    = 2
        'Warn'  = 3
        'Error' = 4
    }
    $minLevel = $log.MinimumLevel
    if (-not $severityMap.ContainsKey($minLevel)) { $minLevel = 'Info' }  # fallback
    if ($severityMap[$Level] -lt $severityMap[$minLevel]) { return }

    # Timestamp
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry = if ($log.IncludeTimestamps) {
        "[{0}] [{1}] {2}" -f $timestamp, $Level.ToUpper(), $Message
    }
    else {
        "[{0}] {1}" -f $Level.ToUpper(), $Message
    }

    # --- Console/Streams ---
    if ($log.EnableConsole) {
        switch ($Level) {
            'Info' { Write-Information -MessageData $Message -Tags 'TechToolbox', 'Info' }
            'Ok' { Write-Information -MessageData $Message -Tags 'TechToolbox', 'Ok' }
            'Warn' { Write-Warning -Message $Message }
            'Error' { Write-Error -Message $Message }
        }
    }

    # --- File logging ---
    if ($log.EnableFileLogging -and $paths.LogDirectory) {
        try {
            if (-not (Test-Path -LiteralPath $paths.LogDirectory)) {
                New-Item -ItemType Directory -Path $paths.LogDirectory -Force | Out-Null
            }
            $fileName = $log.LogFileNameFormat
            # honor pattern "TechToolbox_{yyyyMMdd}.log"
            $fileName = $fileName -replace '\{yyyyMMdd\}', (Get-Date -Format 'yyyyMMdd')
            $logFile = Join-Path -Path $paths.LogDirectory -ChildPath $fileName

            # Reliable append with StreamWriter
            $sw = [System.IO.StreamWriter]::new($logFile, $true)
            try {
                $sw.WriteLine($entry)
            }
            finally {
                $sw.Flush()
                $sw.Dispose()
            }
        }
        catch {
            # Fall back to warning stream if file write fails
            Write-Warning ("Write-Log failed to write to file: {0}" -f $_.Exception.Message)
        }
    }
}
