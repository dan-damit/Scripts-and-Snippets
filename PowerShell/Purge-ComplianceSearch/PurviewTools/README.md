
# Purge-ComplianceSearch

A PowerShell module for purging compliance search results.
Run the main execution script in the PurviewTools folder.

## Overview

This module provides functionality to purge compliance search results from the organization. It has been refactored from a single script into a modular structure using PowerShell module best practices.

## Contents

- **PurviewTools.psm1** - Module script containing core cmdlets
- **PurviewTools.psd1** - Module manifest with metadata and configuration
- Removed commenting mostly for brevity here.
- All comments are in the original script one dir up.

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
..\MainExecutionScript\Purge-ComplianceSearch.ps1
```

## Requirements

- PowerShell 7+
- Appropriate Microsoft 365 permissions
