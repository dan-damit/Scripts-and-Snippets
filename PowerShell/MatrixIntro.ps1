[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# Matrix-style script intro
function Show-MatrixIntro {
    Clear-Host
    Write-Host "`nInitializing Matrix shell..." -ForegroundColor DarkBlue
    Start-Sleep -Milliseconds 500

    for ($i = 0; $i -lt 20; $i++) {
        $line = -join (1..(Get-Random -Min 40 -Max 80) | ForEach-Object { $glyphs | Get-Random })
        Write-Host $line -ForegroundColor DarkGreen
        Start-Sleep -Milliseconds (Get-Random -Min 30 -Max 80)
    }

	Write-Host "`nDecryption Complete..." -ForegroundColor DarkBlue
    Write-Host "`nWelcome, Operator." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 500
}
Invoke-MatrixIntro