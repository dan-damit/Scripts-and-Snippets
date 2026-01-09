# Relaunch script as admin if needed
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
    Exit
}