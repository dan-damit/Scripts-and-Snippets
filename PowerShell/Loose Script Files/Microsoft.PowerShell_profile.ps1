# =====================================================================
#  Operator Profile — Clean, Professional, TechToolbox‑Aware
# =====================================================================

# ─── SETTINGS ─────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "Operator Console"
# Path to module
$TechToolboxRoot = "C:\TechToolbox"

# ─── AUTO‑IMPORT TOOLBOX ──────────────────────────────────
if (Test-Path $TechToolboxRoot) {
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