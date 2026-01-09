
function Clear-CookiesForProfile {
    <#
    .SYNOPSIS
        Deletes Chromium cookie DB files and (optionally) Local Storage.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$ProfilePath,

        [Parameter()]
        [bool]$SkipLocalStorage = $false
    )

    $cookieTargets = @(
        (Join-Path $ProfilePath 'Network\Cookies'),
        (Join-Path $ProfilePath 'Network\Cookies-journal'),
        (Join-Path $ProfilePath 'Cookies'),
        (Join-Path $ProfilePath 'Cookies-journal')
    )

    foreach ($cookiesPath in $cookieTargets) {
        try {
            if (Test-Path -LiteralPath $cookiesPath) {
                if ($PSCmdlet.ShouldProcess($cookiesPath, 'Delete cookie DB')) {
                    Remove-Item -LiteralPath $cookiesPath -Force -ErrorAction SilentlyContinue
                    Write-Log -Level Ok -Message "Removed cookie DB: $cookiesPath"
                }
            }
            else {
                Write-Log -Level Info -Message "Cookie DB not present: $cookiesPath"
            }
        }
        catch {
            Write-Log -Level Warn -Message ("Error removing cookies DB '{0}': {1}" -f $cookiesPath, $_.Exception.Message)
        }
    }

    if (-not $SkipLocalStorage) {
        $localStoragePath = Join-Path $ProfilePath 'Local Storage'
        if (Test-Path -LiteralPath $localStoragePath) {
            try {
                if ($PSCmdlet.ShouldProcess($localStoragePath, 'Clear Local Storage')) {
                    Remove-Item -LiteralPath (Join-Path $localStoragePath '*') -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log -Level Ok -Message "Cleared Local Storage: $localStoragePath"
                }
            }
            catch {
                Write-Log -Level Warn -Message ("Error clearing Local Storage: {0}" -f $_.Exception.Message)
            }
        }
        else {
            Write-Log -Level Info -Message "Local Storage path not present: $localStoragePath"
        }
    }
}
