# Func to show progress banner with new ETA calculation
function Show-ProgressBanner {
    param(
        [int]$current,
        [int]$total,
        [double]$displayPct,
        [TimeSpan]$eta
    )
    $width = 48
    $percent = [math]::Round($displayPct)
    $filled = [math]::Floor(($percent / 100) * $width)
    $bar = ('#' * $filled).PadRight($width)
    $etaText = if ($eta.TotalSeconds -le 0) { '00:00:00' } else { $eta.ToString("hh\:mm\:ss") }
    Write-Host -NoNewline "`rProgress: [$bar] $percent% ($current/$total) ETA: $etaText" -ForegroundColor Yellow
}