Set-ExecutionPolicy Bypass
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Install-Module PSWindowsUpdate
	Import-Module PSWindowsUpdate
Get-WindowsUpdate -Install -AcceptAll -MicrosoftUpdate -IgnoreReboot