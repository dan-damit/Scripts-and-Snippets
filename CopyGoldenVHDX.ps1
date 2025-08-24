# Check for admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Restarting as admin..." -ForegroundColor Yellow
    $ScriptPath = $MyInvocation.MyCommand.Definition
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`"" -Verb RunAs
    Start-Sleep -Seconds 2
    Exit
}

$vmName = "Win11_Sandbox"
$baseVHDX = "F:\VMs\Win11_Golden.vhdx"
$testVHDX = "F:\VMs\$vmName\$vmName.vhdx"

New-Item -ItemType Directory -Path "D:\VMs\$vmName" -Force
Copy-Item $baseVHDX $testVHDX

New-VM -Name $vmName -MemoryStartupBytes 8GB -Generation 2 -VHDPath $testVHDX -SwitchName "VM_Network"
Start-VM $vmName