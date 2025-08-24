# Check for administrative privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    if ($env:ScriptRelaunchFlag -eq "True") {
        Write-host "Script has already attempted to relaunch with elevated privileges. Exiting to prevent infinite loop." -ForegroundColor Red
        Pause
    }

    Write-host "This script needs to be run as an administrator. Restarting with elevated privileges..."

    # Set an environment variable as a flag
    [System.Environment]::SetEnvironmentVariable("ScriptRelaunchFlag", "True", "Process")

    # Countdown for 5 seconds
    for ($i = 5; $i -ge 1; $i--) {
        Write-host "$i seconds remaining..." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }

    # Reopen the script with elevated privileges
    $ScriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$ScriptPath`"" -Verb RunAs
    exit
}
Write-host #
Write-host "--------------------------------------------"
Write-host #

# Check TPM version
$tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
if ($tpm) {
    Write-host "TPM version:" $tpm.SpecVersion -ForegroundColor Green
} else {
    Write-host "TPM not detected." -ForegroundColor Red
}
Write-host #

# Check Secure Boot
$secureBoot = Confirm-SecureBootUEFI
if ($secureBoot) {
    Write-host "Secure Boot is enabled." -ForegroundColor Green
} else {
    Write-host "Secure Boot is not enabled." -ForegroundColor Red
    Write-host "Please Enable Secure Boot." -ForegroundColor Red
}
Write-host #

# Check system memory
$memory = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
if ($memory -ge 4GB) {
    Write-host "RAM meets the minimum requirement: 4 GB or more." -ForegroundColor Green
} else {
    Write-host "Insufficient RAM: Less than 4 GB." -ForegroundColor Red
}
Write-host #

# Check CPU compatibility
$cpu = (Get-WmiObject -Class Win32_Processor).Name
Write-host "Processor:" $cpu -ForegroundColor Yellow
Write-host "Check processor compatibility on Microsoft's official list." -ForegroundColor Cyan
Write-host #
Write-host "Check Complete." -ForegroundColor Green
Write-host #
Pause

Write-host #
Write-host "--------------------------------------------"
Write-host #

$downloadUrl = "https://aka.ms/PCHealthCheckSetup"
$installerPath = "$env:TEMP\PCHealthCheckSetup.msi"

# Download the installer
Write-host "Downloading PC Health Check tool..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

# Install the PC Health Check tool silently
Write-host "Installing PC Health Check tool..."
Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait

# Check if installation was successful
if (Test-Path "C:\Program Files\PCHealthCheck\PCHealthCheck.exe") {
    Write-host "PC Health Check installed successfully."

    # Run the PC Health Check tool
    Write-host "Launching PC Health Check tool..."
    Start-Process "C:\Program Files\PCHealthCheck\PCHealthCheck.exe"
} else {
    Write-host "Installation failed. Please check for errors."
}
Write-host #
Write-host "Script closing in 5 seconds." -ForegroundColor Cyan
# Countdown for 5 seconds
    for ($i = 5; $i -ge 1; $i--) {
        Write-host "$i seconds remaining..." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
Exit