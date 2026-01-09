
function Invoke-BatteryReport {
    <#
    .SYNOPSIS
        Runs 'powercfg /batteryreport' to generate the HTML report and waits
        until the file is non-empty.
    .OUTPUTS
        [bool] True when the report is present and non-zero length; otherwise
        False.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ReportPath,
        [Parameter()][int]$MaxTries = 40,
        [Parameter()][int]$SleepMs = 250
    )

    $reportDir = Split-Path -Parent $ReportPath
    if ($reportDir -and $PSCmdlet.ShouldProcess($reportDir, 'Ensure report directory')) {
        if (-not (Test-Path -LiteralPath $reportDir)) {
            New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        }
    }

    # Generate report (matches original behavior)
    if ($PSCmdlet.ShouldProcess($ReportPath, 'Generate battery report')) {
        & powercfg.exe /batteryreport /output "$ReportPath" | Out-Null
    }

    # Poll for presence & non-zero size (40 tries x 250ms ~= 10s default)
    $tries = 0
    while ($tries -lt $MaxTries) {
        if (Test-Path -LiteralPath $ReportPath) {
            $size = (Get-Item -LiteralPath $ReportPath).Length
            if ($size -gt 0) { return $true }
        }
        Start-Sleep -Milliseconds $SleepMs
        $tries++
    }
    return $false
}
