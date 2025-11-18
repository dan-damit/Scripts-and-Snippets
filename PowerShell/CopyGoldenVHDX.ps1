<# Check for admin and relaunch hidden if wanted #>
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $ScriptPath = $MyInvocation.MyCommand.Definition
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    $psi.Verb = "runas"
    $psi.UseShellExecute = $true
    # $psi.WindowStyle = "Hidden"  # Optional: comment out for debugging
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    Start-Sleep -Seconds 2
    Exit
}

# Initial Params - Adjust as needed for the enviornment (Paths, etc)
$vmName = "Win11_Sandbox"
$baseVHDX = "D:\VMs\Win11_Golden.vhdx"
$testVHDX = "D:\VMs\$vmName\$vmName.vhdx"

# Copy golden VHDX to a new VHDX for testing
New-Item -ItemType Directory -Path "D:\VMs\$vmName" -Force
Copy-Item $baseVHDX $testVHDX

# Create VM with copied VHDX
New-VM -Name $vmName -MemoryStartupBytes 8GB -Generation 2 -VHDPath $testVHDX -SwitchName "Internet"
Set-VMProcessor -VMName $vmName -Count 4
# Disable checkpoints
Set-VM -Name $vmName -CheckpointType Disabled
# Start new VM
Start-VM $vmName
Write-Host "VM '$vmName' has been created and started."

<#
# Instructions for user to bypass NRO on first boot
Write-Host "To bypass Network Requirement on first boot, press Shift+F10 to open Command Prompt,"
Write-Host "then run the following commands:"
Write-Host "reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f"
Write-host "then shutdown /r /t 0"
Write-Host "The VM will restart and allow you to complete OOBE without network."
#>

# End of script
Pause