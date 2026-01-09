function Write-Err {
    param([string]$Message)
    Write-Host "[ERR ] $Message" -ForegroundColor Red
}