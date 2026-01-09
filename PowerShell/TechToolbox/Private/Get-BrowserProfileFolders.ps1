function Get-BrowserProfileFolders {
    <#
    .SYNOPSIS
        Returns Chromium profile directories (Default, Profile N).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserDataPath
    )

    if (-not (Test-Path -LiteralPath $UserDataPath)) {
        Write-Log -Level Error -Message "User Data path not found: $UserDataPath"
        return @()
    }

    Get-ChildItem -Path $UserDataPath -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile \d+$' }
}
