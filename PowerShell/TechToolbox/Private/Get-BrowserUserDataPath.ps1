function Get-BrowserUserDataPath {
    <#
    .SYNOPSIS
        Returns the Chromium 'User Data' path for Chrome/Edge on Windows.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Chrome', 'Edge')]
        [string]$Browser
    )
    switch ($Browser) {
        'Chrome' { Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data' }
        'Edge' { Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data' }
    }
}
