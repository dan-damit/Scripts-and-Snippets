
# Purge-ComplianceSearch

- A PowerShell module for purging compliance search results.
- Run the main execution script in the PurviewTools folder.
- Edge cases considered - e.g. clones the search with mailbox 
    only workload if onedrive or sharepoint data source(s) 
    are found.
- Includes logic to poll status and wait for success flag
    before moving ong

### All in-line comments are in the original script one dir up.

## Overview

This module provides functionality to purge compliance search results from the organization. It has been refactored from a single script into a modular structure using PowerShell module best practices.

## Contents

- **PurviewTools.psm1** - Module script containing core cmdlets
- **PurviewTools.psd1** - Module manifest with metadata and configuration
- Removed commenting mostly for brevity in these files (original script has in-line commenting).

## Installation

1. Clone or download this folder to your PowerShell modules directory:
    ```
    $PROFILE\Modules\PurviewTools\
    ```

2. Import the module:
    ```powershell
    Import-Module PurviewTools
    ```

## Usage

```powershell
..\MainExecutionScript > .\Purge-ComplianceSearch.ps1
```

## Requirements

- PowerShell 7+
- Appropriate Microsoft 365 permissions
- A search and/or case query to be created and ran in MS Purview Web app initially.









