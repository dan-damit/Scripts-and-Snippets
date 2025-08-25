# Check for admin and relaunch hidden if needed
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $ScriptPath = $MyInvocation.MyCommand.Definition
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    $psi.Verb = "runas"
    # $psi.WindowStyle = "Hidden"  # Uncomment this to run hidden
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    Exit
}

<# If already elevated, hide the current console window
Add-Type -Name Win -Namespace Console -MemberDefinition '
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
$consolePtr = [Console.Win]::GetConsoleWindow()
[Console.Win]::ShowWindow($consolePtr, 0)  # 0 = SW_HIDE
#>

# Uncomment above to make window hidden if relaunch isn't needed
#
#---------------------------------
# Run DISM to repair Windows image
Write-Host "Running DISM to repair Windows image..." -ForegroundColor Green
DISM /Online /Cleanup-Image /RestoreHealth

Write-Host #

# Run SFC to scan and fix corrupted files
Write-Host "Running SFC to scan and repair system files..." -ForegroundColor Green
sfc /scannow

Write-Host #

Write-Host "Process completed. Please restart your computer if needed." -ForegroundColor Yellow
Pause