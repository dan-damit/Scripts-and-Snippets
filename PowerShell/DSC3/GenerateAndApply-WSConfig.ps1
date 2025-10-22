# Prompt for firewall state
$firewallState = Read-Host "Enter desired firewall state (On/Off)"
if ($firewallState -notin @("On", "Off")) { Write-Host "Invalid input. Please enter 'On' or 'Off'." -ForegroundColor Red; exit 1 }
$firewallValue = if ($firewallState -eq "On") { 1 } else { 0 }

# Paths
$templatePath = "C:\DSC\WSConfig.Firewall.template.yaml"
$outputPath   = "C:\DSC\WSConfig.Firewall.runtime.yaml"
$dscExePath   = "C:\DSC\DSC.exe"

# Ensure running elevated
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
  Write-Host "This script must be run as Administrator." -ForegroundColor Red
  exit 1
}
if (-not (Test-Path $templatePath)) { Write-Host "Template not found: $templatePath" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $dscExePath)) { Write-Host "DSC.exe not found at $dscExePath" -ForegroundColor Red; exit 1 }

# UTF-8 no BOM writer (atomic)
function Write-FileUtf8NoBom {
  param([string]$Path, [string]$Content)
  $encoding = New-Object System.Text.UTF8Encoding($false)
  $temp = "$Path.tmp"
  [System.IO.File]::WriteAllText($temp, $Content, $encoding)
  Move-Item -Force $temp $Path
}

# Load template and inject value
$content = Get-Content $templatePath -Raw
$content = $content -replace [regex]::Escape('FIREWALL_VALUE'), $firewallValue.ToString()

# Normalize and trim, remove extra YAML docs
$content = ($content -split "(?m)^---$")[0].TrimEnd()
$content = $content.TrimEnd("`r","`n",[char]0)

# Sanity checks
if ($content -match 'FIREWALL_VALUE') { Write-Host "Placeholder not replaced." -ForegroundColor Red; exit 1 }
$docCount = ($content -split "(?m)^---$").Count
if ($docCount -gt 1) { Write-Host "Multiple YAML documents detected: $docCount" -ForegroundColor Red; exit 1 }

# Write runtime file as UTF-8 no BOM
Write-FileUtf8NoBom -Path $outputPath -Content $content

Write-Host "Generated config with Firewall set to '$firewallState'"

# Run DSC.exe, stream output
$arg = @('config','set','-f',$outputPath)
$proc = Start-Process -FilePath $dscExePath -ArgumentList $arg -NoNewWindow -Wait -PassThru
$exitCode = $proc.ExitCode

if ($exitCode -eq 0) {
  Write-Host "DSC applied successfully." -ForegroundColor Green
} else {
  Write-Host "DSC exited with code $exitCode. Check logs for details." -ForegroundColor Yellow
}