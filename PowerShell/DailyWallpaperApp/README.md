# DailyWallpaperApp

A lightweight PowerShell utility to fetch a daily wallpaper (from Bing,
Unsplash, or a local folder) and set it as the Windows desktop background
automaticaly)

- Download daily images from configurable sources (Bing is default).
- Save images to a local cache directory and rotate by date (set in config.json).
- Set desktop wallpaper for current user.
- Run on demand or scheduled automatically via Windows Task Scheduler.
- Minimal logging and configurable retention of cached images.

## Requirements

- Windows 10/11
- PowerShell 5.1+ (or PowerShell 7+)
- Internet access for online sources

## Configuration (example)

Use a JSON config block (included in folder):
```JSON
{
  "Source": "bing",
  "Destination": "C:\\Users\\You\\Pictures\\Wallpapers",
  "Resolution": "1920x1080",
  "KeepDays": 30,
  "Scale": "Fill"
}
```

## Scheduling

Create a scheduled task to run daily:

- Trigger: Daily at desired time
- Action: PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Path\to\Archive.ps1
