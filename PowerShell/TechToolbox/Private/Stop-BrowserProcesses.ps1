function Stop-BrowserProcesses {
    <#
    .SYNOPSIS
        Stops Chrome/Edge processes and waits briefly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Chrome', 'Edge')]
        [string]$Browser,

        [Parameter()]
        [ValidateRange(0, 60000)]
        [int]$SleepAfterKillMs = 1500
    )

    $name = if ($Browser -eq 'Chrome') { 'chrome' } else { 'msedge' }
    try {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Log -Level Info -Message ("Stopping {0} {1} process(es)..." -f (($procs | Measure-Object).Count), $Browser)
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            if ($SleepAfterKillMs -gt 0) { Start-Sleep -Milliseconds $SleepAfterKillMs }
        }
        else {
            Write-Log -Level Info -Message "No $Browser processes found."
        }
    }
    catch {
        Write-Log -Level Warn -Message ("Failed to stop {0} processes: {1}" -f $Browser, $_.Exception.Message)
    }
}
