# Reset Windows Update Components
Write-Host "Stopping Windows Update services..." -ForegroundColor Green
Stop-Service -Name wuauserv -Force
Stop-Service -Name cryptsvc -Force
Stop-Service -Name bits -Force
Stop-Service -Name msiserver -Force

Write-Host "Deleting temporary update files..." -ForegroundColor Green
Remove-Item -Path "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -Force
Rename-Item -Path "$env:SystemRoot\SoftwareDistribution" -NewName "SoftwareDistribution.old" -Force
Rename-Item -Path "$env:SystemRoot\System32\catroot2" -NewName "catroot2.old" -Force

Write-Host "Restarting Windows Update services..." -ForegroundColor Green
Start-Service -Name wuauserv
Start-Service -Name cryptsvc
Start-Service -Name bits
Start-Service -Name msiserver

Write-Host "Windows Update components reset completed!" -ForegroundColor Green