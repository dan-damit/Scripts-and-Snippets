
function Clear-CacheForProfile {
    <#
    .SYNOPSIS
        Clears multiple cache locations for a Chromium profile.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $cacheTargets = @(
        (Join-Path $ProfilePath 'Cache'),
        (Join-Path $ProfilePath 'Code Cache'),
        (Join-Path $ProfilePath 'GPUCache'),
        (Join-Path $ProfilePath 'Service Worker'),
        (Join-Path $ProfilePath 'Application Cache'),
        (Join-Path $ProfilePath 'Network\Cache')
    )

    foreach ($cachePath in $cacheTargets) {
        try {
            if (Test-Path -LiteralPath $cachePath) {
                if ($PSCmdlet.ShouldProcess($cachePath, 'Clear cache contents')) {
                    # Remove contents not the folder itself
                    $target = Join-Path $cachePath '*'
                    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log -Level Ok -Message "Cleared cache content: $cachePath"
                }
            }
            else {
                Write-Log -Level Info -Message "Cache path not present: $cachePath"
            }
        }
        catch {
            Write-Log -Level Warn -Message ("Error clearing cache at '{0}': {1}" -f $cachePath, $_.Exception.Message)
        }
    }
}
