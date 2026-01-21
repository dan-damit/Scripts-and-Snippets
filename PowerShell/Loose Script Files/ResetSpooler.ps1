
# Run as Administrator

Write-Host "Stopping Print Spooler..." -ForegroundColor Cyan
Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue

# Clear stuck print jobs (if any)
$spoolPath = "$env:WINDIR\System32\spool\PRINTERS"
if (Test-Path $spoolPath) {
    Write-Host "Clearing spool folder: $spoolPath" -ForegroundColor Cyan
    Get-ChildItem -Path $spoolPath -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

Write-Host "Starting Print Spooler..." -ForegroundColor Cyan
Start-Service -Name Spooler

# Use CIM instead of Get-Printer to avoid 0x800706be issues
Write-Host "Removing all printers via Win32_Printer..." -ForegroundColor Yellow
Get-CimInstance Win32_Printer | ForEach-Object {
    Write-Host "  - Removing $($_.Name)" -ForegroundColor Yellow
    Try {
        $_ | Remove-CimInstance -ErrorAction Stop
    } Catch {
        Write-Warning "    Failed to remove $($_.Name): $($_.Exception.Message)"
    }
}

# Optional: remove all TCP/IP ports (skip standard FILE:/LPT:/XPS/etc.)
Write-Host "Removing TCP/IP printer ports..." -ForegroundColor Yellow
$standardPrefixes = @('FILE:', 'LPT', 'COM', 'WSD', 'XPS', 'SHRFAX:')
Get-PrinterPort -ErrorAction SilentlyContinue | Where-Object {
    $n = $_.Name
    -not ($standardPrefixes | ForEach-Object { $n.StartsWith($_, 'CurrentCultureIgnoreCase') }) `
    -and ($n -notmatch '^(nul:|PDF:)')
} | ForEach-Object {
    Write-Host "  - Removing port $($_.Name)" -ForegroundColor Yellow
    Try {
        Remove-PrinterPort -Name $_.Name -ErrorAction Stop
    } Catch {
        Write-Warning "    Failed to remove port $($_.Name): $($_.Exception.Message)"
    }
}

# Optional: Remove all printer drivers
Get-PrinterDriver | ForEach-Object {
    Write-Host "Removing driver: $($_.Name)" -ForegroundColor Yellow
    Try {
        Remove-PrinterDriver -Name $_.Name -ErrorAction Stop
    } Catch {
        Write-Warning "Failed to remove driver $($_.Name): $($_.Exception.Message)"
    }
}

Write-Host "All done." -ForegroundColor Green