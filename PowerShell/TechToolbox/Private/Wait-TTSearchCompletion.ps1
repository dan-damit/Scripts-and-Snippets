function Wait-TTSearchCompletion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$SearchName,
        [string]$CaseName,
        [int]$MaxAttempts = 40,
        [int]$DelaySec = 10
    )

    $name = Resolve-TTSearchName -SearchName $SearchName
    Write-Log -Level Info -Message "Waiting for search '$name' to complete..."

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        $s = Get-ComplianceSearch -Identity $name -Case $CaseName -ErrorAction Stop
        Write-Log -Level Info -Message ("Status: {0} (attempt {1}/{2})" -f $s.Status, $i, $MaxAttempts)

        if ($s.Status -eq 'Completed') {
            Write-Log -Level Ok -Message "Search '$name' completed."
            return $s
        }

        Start-Sleep -Seconds $DelaySec
    }

    throw "Search '$name' did not complete within $MaxAttempts attempts."
}