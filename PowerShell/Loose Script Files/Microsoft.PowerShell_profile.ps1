# =====================================================================
#  Operator Profile — Clean, Professional, TechToolbox‑Aware
# =====================================================================

# ─── SETTINGS ─────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "Operator Console"
# Path to module
$TechToolboxRoot = "C:\TechToolbox"
if (-not (Test-Path (Join-Path $TechToolboxRoot "TechToolbox.psd1"))) {
    Write-Host "`nTechToolbox manifest not found in: $TechToolboxRoot" -ForegroundColor Yellow
    return
}

# ─── TOOLBOX ──────────────────────────────────
function tt {
    <#
    .SYNOPSIS
        Load, reload, or unload the TechToolbox module. 
    #>
    [CmdletBinding()]
    param(
        [switch]$Reload,
        [switch]$Unload
    )

    if (-not (Test-Path $TechToolboxRoot)) {
        Write-Host "`nTechToolbox path not found: $TechToolboxRoot" -ForegroundColor Yellow
        return
    }

    # --- Unload only ---
    if ($Unload) {
        if (Get-Module TechToolbox) {
            try {
                Remove-Module TechToolbox -Force -ErrorAction Stop
                Write-Host "`nTechToolbox unloaded." -ForegroundColor DarkYellow
            }
            catch {
                Write-Host "`nFailed to unload TechToolbox: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "`nTechToolbox is not currently loaded." -ForegroundColor Yellow
        }
        return
    }

    # --- Reload path ---
    if ($Reload) {
        if (Get-Module TechToolbox) {
            try {
                Remove-Module TechToolbox -Force -ErrorAction Stop
                Write-Host "TechToolbox unloaded." -ForegroundColor DarkYellow
            }
            catch {
                Write-Host "Failed to unload TechToolbox: $($_.Exception.Message)" -ForegroundColor Red
                return
            }
        }
    }

    # --- Already loaded (no reload requested) ---
    if ((Get-Module TechToolbox -ErrorAction SilentlyContinue -OutVariable existing) -and -not $Reload) {
        Write-Host "`nTechToolbox already loaded." -ForegroundColor Green
        return
    }

    # --- Load module ---
    try {
        Import-Module $TechToolboxRoot -Force -ErrorAction Stop
        Write-Host "`nTechToolbox loaded." -ForegroundColor Green
    }
    catch {
        Write-Host "`nTechToolbox failed to load: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ─── CLEAN PROFESSIONAL PROMPT ────────────────────────────
function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    $path = (Get-Location)

    Write-Host "`n[$time] " -ForegroundColor DarkCyan -NoNewline
    Write-Host "$path" -ForegroundColor White -NoNewline
    return "`nλ "
}

# =====================================================================
#  END PROFILE
# =====================================================================