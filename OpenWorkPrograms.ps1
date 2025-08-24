# Author: Dan.Damit
# e: Dan@thedamits.com
# 
# Date Created: 20250224
# Date Last Modified: 20250325
#
# Description: This script opens a few programs I use for working at ADV-Tech
#
#------------------------------------------------------------------------------------------------------
#
# Path to the programs
$vonagePath = "C:\Users\dan\AppData\Local\Programs\vonage\Vonage Business.exe"
$teamsPath = "C:\Program Files\WindowsApps\MSTeams_25031.805.3440.5290_x64__8wekyb3d8bbwe\ms-Teams.exe"
$outlookPath = "C:\Program Files\Microsoft Office\root\Office16\Outlook.exe"
$oneNotePath = "C:\Program Files\Microsoft Office\root\Office16\OneNote.exe"

# Start the programs
Start-Process $vonagePath
Start-Process $teamsPath
Start-Process $outlookPath
Start-Process $oneNotePath
