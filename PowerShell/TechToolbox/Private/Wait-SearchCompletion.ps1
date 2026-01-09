
function Wait-PurgeCompletion {
    <#
    .SYNOPSIS
        Monitors a Purge ComplianceSearchAction until completion or timeout.
    .DESCRIPTION
        Supports two parameter sets: by action identity or by search name.
        Uses config-driven TimeoutSeconds and PollSeconds, and logs status changes.
    #>
    [CmdletBinding(DefaultParameterSetName = 'BySearch')]
    param(
        [Parameter(ParameterSetName = 'BySearch', Mandatory)][ValidateNotNullOrEmpty()][string]$SearchName,
        [Parameter(ParameterSetName = 'ByAction', Mandatory)][ValidateNotNullOrEmpty()][string]$ActionIdentity,
        [Parameter()][string]$CaseName
    )

    $cfg = Get-TechToolboxConfig
    $purv = $cfg.Purview
    $timeout = [int]($purv.Purge.TimeoutSeconds)
    $poll = [int]($purv.Purge.PollSeconds)
    if ($timeout -le 0) { $timeout = 1200 }
    if ($poll -le 0) { $poll = 5 }

    $target = if ($PSCmdlet.ParameterSetName -eq 'ByAction') { $ActionIdentity } else { $SearchName }
    Write-Log -Level Info -Message ("Monitoring purge for '{0}' (Timeout={1}s, Poll={2}s)..." -f $target, $timeout, $poll)

    $deadline = (Get-Date).AddSeconds($timeout)
    while ((Get-Date) -lt $deadline) {
        $action = if ($PSCmdlet.ParameterSetName -eq 'ByAction') {
            Get-ComplianceSearchAction -Identity $ActionIdentity -ErrorAction SilentlyContinue
        }
        else {
            Get-ComplianceSearchAction -Purge -Case $CaseName -ErrorAction SilentlyContinue |
            Where-Object { $_.SearchName -eq $SearchName } |
            Sort-Object CreatedTime -Descending |
            Select-Object -First 1
        }

        if ($action) {
            $status = $action.Status
            Write-Log -Level Info -Message ("Purge status: {0}" -f $status)
            switch ($status) {
                'Completed' { Write-Log -Level Ok   -Message "Purge completed successfully."; return $action }
                'PartiallySucceeded' { Write-Log -Level Warn -Message ("Purge partially succeeded: {0}" -f $action.ErrorMessage); return $action }
                'Failed' { Write-Log -Level Error -Message ("Purge failed: {0}" -f $action.ErrorMessage); return $action }
            }
        }
        else {
            Write-Log -Level Info -Message "No purge action found yet..."
        }

        Start-Sleep -Seconds $poll
    }

    throw "Timed out waiting for purge completion."
}
