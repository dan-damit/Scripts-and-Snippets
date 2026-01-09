
# TechToolbox

A PowerShell 7+ module for day-to-day IT automation: browser profile cleanup, remote software inventory, Purview eDiscovery workflows, EXO message trace, battery health parsing, and AAD Connect remote sync.

---

## Contents

- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Public Commands](#public-commands)
  - [Clear-BrowserProfileData](#clear-browserprofiledata)
  - [Get-RemoteInstalledSoftware](#get-remoteinstalledsoftware)
  - [Invoke-PurviewPurge](#invoke-purviewpurgeref)
  - [Get-MessageTrace](#get-messagetrace)
  - [Get-BatteryHealth](#get-batteryhealth)
  - [Invoke-AADSyncRemote](#invoke-aadsyncremote)
- [Design & Conventions](#design--conventions)
- [Troubleshooting](#troubleshooting)
- [Development & QA](#development--qa)

---

## Getting Started

```powershell
# PowerShell 7+ recommended
# Import module from a local path
Import-Module .\TechToolbox -Force

# See exported commands
Get-Command -Module TechToolbox | Sort-Object Name

# View help for any command
Get-Help Clear-BrowserProfileData -Detailed
```

> The module auto-loads functions from `Private/` (helpers) and `Public/` (exported), and caches configuration via `Get-TechToolboxConfig`.

---

## Configuration

Create `Config\config.json` and tailor to your environment. Below is a **minimal example** with commonly used sections. Omit any you do not need; defaults will be applied where sensible.

```json
{
  "paths": {
    "temp": "C:\\Temp\\TechToolbox",
    "logs": "C:\\LogsAndExports\\Logs\\TechToolbox",
    "exportDirectory": "C:\\LogsAndExports\\Exports\\TechToolbox"
  },
  "settings": {
    "logging": {
      "enableConsole": true,
      "enableFileLogging": false,
      "includeTimestamps": true,
      "logFileNameFormat": "TechToolbox_{yyyyMMdd}.log",
      "minimumLevel": "Info"
    },
    "output": {
      "writeTable": true,
      "encoding": "UTF8"
    },
    "remoteSoftwareInventory": {
      "includeAppx": false,
      "consolidated": false,
      "throttleLimit": 32,
      "promptForCredentials": true,
      "outDir": "C:\\LogsAndExports\\Exports\\RemoteSoftwareInventory"
    },
    "compliance": {
      "searchBatchSize": 50,
      "purgeBatchSize": 25,
      "maxRetryAttempts": 3
    },
    "aadSync": {
      "defaultPort": 5985,
      "defaultPolicyType": "Delta",
      "allowKerberos": true
    },
    "exchangeOnline": {
      "autoConnect": true,
      "autoDisconnectPrompt": true,
      "showProgress": false
    },
    "messageTrace": {
      "promptForMissingInputs": true,
      "defaultLookbackHours": 48,
      "autoExport": false,
      "defaultExportFolder": "C:\\LogsAndExports\\Exports\\MessageTraces"
    },
    "batteryReport": {
      "reportPath": "C:\\Temp\\battery-report.html",
      "outputJson": "C:\\Temp\\installed-batteries.json",
      "debugInfo": "C:\\Temp\\installed-batteries_debug.txt",
      "waitTimeoutSeconds": 10
    },
    "purview": {
      "autoConnect": true,
      "autoDisconnectPrompt": true,
      "search": {
        "maxAttempts": 40,
        "delaySeconds": 10
      },
      "purge": {
        "timeoutSeconds": 1200,
        "pollSeconds": 5,
        "requireConfirmation": true
      }
    },
    "browserCleanup": {
      "killProcesses": true,
      "sleepAfterKillMs": 1500,
      "includeCookies": true,
      "includeCache": true,
      "skipLocalStorage": false,
      "defaultBrowser": "All",
      "defaultProfiles": null
    },
    "defaults": {
      "promptForHostname": true,
      "promptForCredentials": true,
      "promptForDateRanges": true,
      "promptForCaseName": true,
      "promptForSearchName": true,
      "promptForKqlQuery": true
    }
  }
}
```

> Tip: Environment-specific overrides can be added to your config logic if desired (e.g., via `TECHTOOLBOX_ENV`).

---

## Public Commands

### Clear-BrowserProfileData

Deletes cache, cookies, and (optionally) local storage for **Chrome/Edge** profiles. Supports `-WhatIf/-Confirm`.

```powershell
# Preview cleanup for both browsers
Clear-BrowserProfileData -WhatIf

# Target Chrome only and just cache
Clear-BrowserProfileData -Browser Chrome -IncludeCache:$true -IncludeCookies:$false

# Target specific profiles, skip local storage
Clear-BrowserProfileData -Browser Edge -Profiles 'Default','Profile 2' -SkipLocalStorage
```

---

### Get-RemoteInstalledSoftware

Collects installed software from remote Windows hosts via **PSRemoting** (registry uninstall keys; optional Appx/MSIX). Exports per-host or consolidated CSV.

```powershell
# Query two servers, consolidated CSV
Get-RemoteInstalledSoftware -ComputerName srv01,srv02 -Consolidated

# Include Appx packages, prompt for credentials
Get-RemoteInstalledSoftware -ComputerName laptop01 -IncludeAppx -Credential (Get-Credential)

# Preview without writing any files
Get-RemoteInstalledSoftware -ComputerName srv01,srv02 -WhatIf
```

---

### Invoke-PurviewPurge (ref)

End-to-end **Purview HardDelete** workflow: connect, clone/create mailbox-only search, wait for completion, submit purge, optional disconnect.

```powershell
# Normal run
Invoke-PurviewPurge -UserPrincipalName admin@contoso.com -CaseName "Case-001" -SearchName "CustodianSearch-01"

# Preview purge submission
Invoke-PurviewPurge -UserPrincipalName admin@contoso.com -CaseName "Case-001" -SearchName "CustodianSearch-01" -WhatIf
```

> Internally calls: `New-MailboxSearchClone`, `Wait-SearchCompletion`, `Invoke-HardDelete`, `Wait-PurgeCompletion` (private helpers).

---

### Get-MessageTrace

Runs **EXO V2** message trace by RFC822 Message-ID, shows summary and per-recipient details, and optionally exports CSVs.

```powershell
# 24-hour lookback window (defaults from config)
Get-MessageTrace -MessageId '<abc123@contoso.com>'

# Custom date window
Get-MessageTrace -MessageId '<abc123@contoso.com>' -StartDate (Get-Date).AddHours(-12) -EndDate (Get-Date)

# Auto-export to default folder
Get-MessageTrace -MessageId '<abc123@contoso.com>' -WhatIf
```

---

### Get-BatteryHealth

Generates `powercfg /batteryreport`, parses the **Installed batteries** table from HTML, computes health metrics, and writes JSON.

```powershell
# Use config defaults
Get-BatteryHealth

# Custom paths, preview only
Get-BatteryHealth -ReportPath 'C:\Temp\battery-report.html' -OutputJson 'C:\Temp\batteries.json' -WhatIf
```

---

### Invoke-AADSyncRemote

Remotely triggers **Azure AD Connect** (`Start-ADSyncSyncCycle`) using PSRemoting. Kerberos or credential-based.

```powershell
# Delta sync using defaults
Invoke-AADSyncRemote -ComputerName 'aadconnect01'

# Initial sync via Kerberos, preview only
Invoke-AADSyncRemote -ComputerName 'aadconnect01' -PolicyType Initial -UseKerberos -WhatIf

# HTTPS WinRM (5986) with transcript in Logs
Invoke-AADSyncRemote -ComputerName 'aadconnect01.contoso.com' -Port 5986 -EnableTranscript
```

---

## Design & Conventions

- **Structure**: `Private/` (helpers), `Public/` (exported), `Config/` (json), `TechToolbox.psm1` (loader), `TechToolbox.psd1` (manifest).
- **One function per file** with matching names for clean auto-export.
- **Advanced Functions**: `[CmdletBinding()]`, validated parameters, `ShouldProcess` for state changes.
- **Logging**: centralized `Write-Log` using streams (`Write-Information`, `Write-Warning`, `Write-Error`) and optional file logging via config.
- **Config cache**: `Get-TechToolboxConfig` returns a cached object; add `Reset-TechToolboxConfig` if you need runtime reloads.
- **Cross-platform**: Target is Windows; Chromium paths, EXO/Purview cmdlets assume Windows/EXO contexts.

---

## Troubleshooting

- **Module import**: Ensure `TechToolbox.psd1` points to `TechToolbox.psm1` and PowerShell 7+.
- **Permissions**:
  - **Remote inventory** / **AADSync** require WinRM and appropriate rights on target hosts.
  - **Purview** workflows require eDiscovery roles and ExchangeOnlineManagement module.
- **Message trace**: V2 retention limits apply; widen the window or verify Message-ID.
- **Battery report**: `powercfg` must be present; run PowerShell as admin if report generation fails.
- **Logging to file**: Confirm `Paths.LogDirectory` exists or `EnableFileLogging` is false.

---

## Development & QA

```powershell
# Analyzer (configurable rules)
Invoke-ScriptAnalyzer -Path .\TechToolbox -Recurse -Severity Error,Warning

# Smoke tests (dry runs)
Clear-BrowserProfileData -WhatIf
Get-RemoteInstalledSoftware -ComputerName srv01 -WhatIf
Invoke-PurviewPurge -UserPrincipalName you@contoso.com -CaseName Case-001 -SearchName Search-001 -WhatIf
Get-MessageTrace -MessageId '<test@contoso.com>' -WhatIf
Get-BatteryHealth -WhatIf
Invoke-AADSyncRemote -ComputerName aadconnect01 -PolicyType Delta -WhatIf
```

> Consider adding a `PSScriptAnalyzerSettings.psd1` for rule enforcement and Pester tests for key workflows.

---

**Author:** Dan Damit  
**License:** Internal use (customize as needed)  
**Version:** 0.3.0 (example)
