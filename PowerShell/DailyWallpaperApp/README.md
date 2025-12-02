# DailyWallpaperApp

A lightweight PowerShell utility to fetch a daily wallpaper (from Bing,
Unsplash, or a local folder) and set it as the Windows desktop background
automatical
- Download daily images from configurable sources (Bing, Unsplash, custom URL, local folder).
- Save images to a local cache directory and rotate by date.
- Set desktop wallpaper for current user (supports common scale modes).
- Run on demand or scheduled automatically via Windows Task Scheduler.
- Minimal logging and configurable retention of cached images.

## Requirements
- Windows 10/11
- PowerShell 5.1+ (or PowerShell 7+)
- Internet access for online sources

## Quick Start
1. Clone the repo:
    git clone <repo-url>
2. Allow running scripts if needed:
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
3. Run the script once to verify:
    .\DailyWallpaperApp.ps1 -Source bing -Destination

## Configuration (example)
Use a JSON or PowerShell config block:
{
  "Source": "bing",
  "Destination": "C:\\Users\\You\\Pictures\\Wallpapers",
  "Resolution": "1920x1080",
  "KeepDays": 30,
  "Scale": "Fill"
}

## Scheduling
Create a scheduled task to run daily:
- Trigger: Daily at desired time
- Action: PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File

## Troubleshooting
- If image doesn't change, verify file path and that the script has permission to update the registry or call SystemParametersInfo.
- Check logs (if enabled) for download or permission errors.

## Contributing & License
- Contributions welcome via PR.
- Include tests for source-parsing and file-handling logic.
- Add license file (MIT recommended).
  "C:\path\DailyWallpaperApp.ps1"
    "C:\Users\<you>\Pictures\Wallpapers"
ly.

## Features