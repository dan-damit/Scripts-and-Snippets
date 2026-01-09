function Update-CamelKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Label
    )

    # Normalize text first
    $clean = Update-Text $Label

    # Lowercase, remove non-alphanumerics except spaces
    $clean = ($clean.ToLower() -replace '[^a-z0-9 ]', '').Trim()

    if ([string]::IsNullOrWhiteSpace($clean)) {
        return ""
    }

    $parts = $clean -split '\s+'
    $key = $parts[0]

    for ($i = 1; $i -lt $parts.Length; $i++) {
        $part = $parts[$i]
        $key += ($part.Substring(0, 1).ToUpper() + $part.Substring(1))
    }

    return $key
}