
function Format-Text {
    <#
    .SYNOPSIS
        Strips tags/whitespace and decodes HTML entities.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text)

    $t = $Text -replace '(?is)<br\s*/?>', ' ' -replace '(?is)<[^>]+>', ' '
    $t = [System.Net.WebUtility]::HtmlDecode($t)
    $t = ($t -replace '\s+', ' ').Trim()
    return $t
}
