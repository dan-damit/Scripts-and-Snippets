
# DumpBrowserCache.ps1
### Author: Dan.Damit (https://github.com/dan-damit)

---

A PowerShell script to **clear cache and cookies** for **Chrome** and **Edge** profiles (Default, Profile N).  
Supports **dry-run mode**, **logging**, **selective profiles**, and **safe process handling**.

---

## Features
- Supports **Chrome** and **Edge** (Chromium-based)
- Clears:
  - Cache (multiple cache directories)
  - Cookies (modern `Network\Cookies` and legacy paths)
- Handles locked files by stopping browser processes (optional)
- Dry-run mode with `-WhatIf`
- Detailed logging with `-LogPath`
- Target specific profiles or all
- Verbose output for troubleshooting

---

## Requirements
- Windows 10/11
- PowerShell 5.1+ (or PowerShell Core)
- Run in **user context** for correct profile paths

---

## Parameters

| Parameter           | Description                                      |
|----------------------|--------------------------------------------------|
| `-Browser`          | Chrome, Edge, or All                            |
| `-Profiles`         | Specific profiles (e.g., 'Default','Profile 1') |
| `-IncludeCookies`   | Include cookie cleanup (default: true)          |
| `-IncludeCache`     | Include cache cleanup (default: true)           |
| `-KillProcesses`    | Stop browser processes before cleanup (default: true) |
| `-SleepAfterKillMs` | Wait time after killing processes (default: 1500 ms) |
| `-LogPath`          | Optional log file path                          |
| `-WhatIf`           | Dry-run mode                                    |
| `-Verbose`          | Detailed output                                 |

---

## Example Usage
```powershell
.\DumpBrowserCache.ps1 -Browser Chrome -Verbose
```

### Dry run (see what would be removed), both browsers, all profiles
```powershell
.\DumpBrowserCache.ps1 -Browser All -WhatIf -Verbose
```
