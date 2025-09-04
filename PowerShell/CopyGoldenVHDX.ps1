# Check for admin and relaunch hidden if needed
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $ScriptPath = $MyInvocation.MyCommand.Definition
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    $psi.Verb = "runas"
    $psi.WindowStyle = "Hidden"  # Uncomment this to run hidden
    [System.Diagnostics.Process]::Start($psi) | Out-Null
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
# Disable checkpoints
Set-VM -Name $vmName -CheckpointType Disabled
# Start new VM
Start-VM $vmName

# Shift+F10 :: reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f
#           :: shutdown /r /t 0