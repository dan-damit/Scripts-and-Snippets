function Update-Text {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    if (-not $Text) { return "" }

    # Decode HTML entities if possible
    try {
        $decoded = [System.Web.HttpUtility]::HtmlDecode($Text)
    }
    catch {
        $decoded = $Text
    }

    # Strip HTML tags, normalize whitespace, remove non-breaking spaces
    $clean = ($decoded -replace '<[^>]+>', '')
    $clean = $clean -replace [char]0xA0, ' '
    $clean = $clean -replace '\s+', ' '

    return $clean.Trim()
}