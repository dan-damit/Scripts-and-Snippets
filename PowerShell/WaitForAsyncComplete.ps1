function Wait-ForCompletion {
    [CmdletBinding()]
    param(
        # The asynchronous result from BeginInvoke
        [Parameter(Mandatory = $true)]
        [System.IAsyncResult]$AsyncResult,

        # Optional maximum wait time (in seconds) before aborting
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        # How often (in milliseconds) to check the completion flag (default 250ms)
        [Parameter(Mandatory = $false)]
        [int]$CheckIntervalMilliseconds = 250
    )

    $startTime = Get-Date

    while (-not $AsyncResult.IsCompleted) {
        Start-Sleep -Milliseconds $CheckIntervalMilliseconds

        # Check for timeout within the loop
        if (((Get-Date) - $startTime).TotalSeconds -ge $TimeoutSeconds) {
            throw "Asynchronous operation timed out after $TimeoutSeconds seconds"
        }
    }

    # Return the completed AsyncResult in case you need further processing
    return $AsyncResult
}