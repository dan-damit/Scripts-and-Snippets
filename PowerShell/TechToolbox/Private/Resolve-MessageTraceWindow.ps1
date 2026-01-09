
function Resolve-MessageTraceWindow {
    <#
    .SYNOPSIS
        Resolves Start/End datetime for message trace, using explicit values or
        a config-driven lookback.
    .PARAMETER StartDate
        Explicit UTC start datetime (optional).
    .PARAMETER EndDate
        Explicit UTC end datetime (optional).
    .PARAMETER LookbackHours
        Hours to subtract from now when Start/End are not provided.
    .OUTPUTS
        [pscustomobject] with StartDate and EndDate
    #>
    [CmdletBinding()]
    param(
        [Parameter()][datetime]$StartDate,
        [Parameter()][datetime]$EndDate,
        [Parameter()][int]$LookbackHours = 48
    )

    if (-not $StartDate -and -not $EndDate) {
        $EndDate = (Get-Date).ToUniversalTime()
        $StartDate = $EndDate.AddHours( - [math]::Abs($LookbackHours))
    }
    elseif (-not $StartDate -and $EndDate) {
        $StartDate = $EndDate.AddHours( - [math]::Abs($LookbackHours))
    }
    elseif ($StartDate -and -not $EndDate) {
        $EndDate = $StartDate.AddHours([math]::Abs($LookbackHours))
    }

    # Ensure UTC (EXO V2 expects UTC)
    $StartDate = $StartDate.ToUniversalTime()
    $EndDate = $EndDate.ToUniversalTime()

    [pscustomobject]@{ StartDate = $StartDate; EndDate = $EndDate }
}
