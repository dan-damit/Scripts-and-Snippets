[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# Matrix-style script intro
function Invoke-MatrixIntro {
    $green = "DarkGreen"
    $chars = @("0", "1", "░", "▒", "▓", "|", "-", "+", "*")

    cls
    for ($i = 0; $i -lt 20; $i++) {
        $line = ""
        for ($j = 0; $j -lt 60; $j++) {
            $line += $chars | Get-Random
        }
        Write-Host $line -ForegroundColor $green
        Start-Sleep -Milliseconds (Get-Random -Minimum 30 -Maximum 120)
    }

    Write-Host "`n🟩 Welcome to the System..." -ForegroundColor Green
    Start-Sleep -Seconds 2
    cls
}
Invoke-MatrixIntro