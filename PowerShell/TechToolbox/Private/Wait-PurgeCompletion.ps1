
function Wait-PurgeCompletion {
    [CmdletBinding(DefaultParameterSetName = 'BySearch')]
    param(
        [Parameter(ParameterSetName = 'BySearch', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SearchName,

        [Parameter(ParameterSetName = 'ByAction', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ActionIdentity,

        [Parameter()]
        [string]$CaseName,

        [Parameter()]
        [int]$TimeoutSeconds = 1200,

        [Parameter()]
        [int]$PollSeconds = 5
    )

    # --- Pull defaults from config if caller did not explicitly set them ---
    $cfg = Get-TechToolboxConfig
    $purv = $cfg.Purview

    if (-not $PSBoundParameters.ContainsKey('TimeoutSeconds') -and [int]$purv.Purge.TimeoutSeconds -gt 0) {
        $TimeoutSeconds = [int]$purv.Purge.TimeoutSeconds
    }
    if (-not $PSBoundParameters.ContainsKey('PollSeconds') -and [int]$purv.Purge.PollSeconds -gt 0) {
        $PollSeconds = [int]$purv.Purge.PollSeconds
    }

    $target = if ($PSCmdlet.ParameterSetName -eq 'ByAction') { $ActionIdentity } else { $SearchName }
    Write-Log -Level Info -Message ("Monitoring purge for '{0}' (Timeout={1}s, Poll={2}s)..." -f $target, $TimeoutSeconds, $PollSeconds)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        $action = if ($PSCmdlet.ParameterSetName -eq 'ByAction') {
            Get-ComplianceSearchAction -Identity $ActionIdentity -ErrorAction SilentlyContinue
        }
        else {
            # If CaseName is provided, scope to case; otherwise look across all purge actions and pick latest for the search
            $scope = if ([string]::IsNullOrWhiteSpace($CaseName)) {
                Get-ComplianceSearchAction -Purge -ErrorAction SilentlyContinue
            }
            else {
                Get-ComplianceSearchAction -Purge -Case $CaseName -ErrorAction SilentlyContinue
            }

            $scope |
            Where-Object { $_.SearchName -eq $SearchName } |
            Sort-Object CreatedTime -Descending |
            Select-Object -First 1
        }

        if ($action) {
            $status = $action.Status
            Write-Log -Level Info -Message ("Purge status: {0}" -f $status)

            switch ($status) {
                'Completed' {
                    Write-Log -Level Ok -Message "Purge completed successfully."
                    return $action
                }
                'PartiallySucceeded' {
                    Write-Log -Level Warn -Message ("Purge partially succeeded: {0}" -f $action.ErrorMessage)
                    return $action
                }
                'Failed' {
                    Write-Log -Level Error -Message ("Purge failed: {0}" -f $action.ErrorMessage)
                    return $action
                }
            }
        }
        else {
            Write-Log -Level Info -Message "No purge action found yet..."
        }

        Start-Sleep -Seconds $PollSeconds
    }

    throw "Timed out waiting for purge completion."
}
