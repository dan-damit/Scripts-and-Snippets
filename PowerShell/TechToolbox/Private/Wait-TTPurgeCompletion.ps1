function Wait-TTPurgeCompletion {
    [CmdletBinding(DefaultParameterSetName = 'BySearch')]
    param(
        [Parameter(ParameterSetName = 'BySearch', Mandatory)][object]$SearchName,
        [Parameter(ParameterSetName = 'ByAction', Mandatory)][string]$ActionIdentity,
        [string]$CaseName,
        [int]$TimeoutSeconds = 1200,
        [int]$PollSeconds = 5
    )

    $name = if ($PSCmdlet.ParameterSetName -eq 'BySearch') {
        Resolve-TTSearchName -SearchName $SearchName
    }

    $target = if ($PSCmdlet.ParameterSetName -eq 'ByAction') { $ActionIdentity } else { $name }
    Write-Log -Level Info -Message "Monitoring purge for '$target'..."

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        $action = if ($PSCmdlet.ParameterSetName -eq 'ByAction') {
            Get-ComplianceSearchAction -Identity $ActionIdentity -ErrorAction SilentlyContinue
        }
        else {
            Get-ComplianceSearchAction -Purge -Case $CaseName -ErrorAction SilentlyContinue |
            Where-Object { $_.SearchName -eq $name } |
            Sort-Object CreatedTime -Descending |
            Select-Object -First 1
        }

        if ($action) {
            $status = $action.Status
            Write-Log -Level Info -Message "Purge status: $status"

            switch ($status) {
                'Completed' {
                    Write-Log -Level Ok -Message "Purge completed successfully."
                    return
                }
                'PartiallySucceeded' {
                    Write-Log -Level Warn -Message "Purge partially succeeded: $($action.ErrorMessage)"
                    return
                }
                'Failed' {
                    Write-Log -Level Error -Message "Purge failed: $($action.ErrorMessage)"
                    return
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