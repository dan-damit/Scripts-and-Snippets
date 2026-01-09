function Resolve-TTSearchName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$SearchName
    )

    if ($null -eq $SearchName) {
        throw "Resolve-TTSearchName: SearchName is null."
    }

    if ($SearchName -is [string]) {
        return $SearchName.Trim()
    }

    if ($SearchName -is [array]) {
        return Resolve-TTSearchName -SearchName $SearchName[0]
    }

    if ($SearchName.PSObject -and $SearchName.PSObject.Properties['Name']) {
        $n = [string]$SearchName.Name
        if (-not [string]::IsNullOrWhiteSpace($n)) {
            return $n.Trim()
        }
    }

    $s = $SearchName.ToString()
    if ($s -match '^Microsoft\.Exchange\.Compliance.*ComplianceSearch\s(.+)$') {
        return $Matches[1].Trim()
    }

    throw "Resolve-TTSearchName: Unable to resolve search name from input type '$($SearchName.GetType().FullName)'."
}