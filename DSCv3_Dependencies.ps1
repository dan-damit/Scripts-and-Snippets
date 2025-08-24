# --- Step 1: Configure the network location to Private ---
$statusToolStripLabel.Text = "Configuring network location to Private..."
$form.Refresh()
# This sets all network profiles to Private. (You may want to restrict this to specific interfaces.)
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
Start-Sleep -Seconds 2

# --- Step 2: Configure WinRM ---
$statusToolStripLabel.Text = "Configuring WinRM..."
$form.Refresh()
# Quietly configure WinRM (or use Enable-PSRemoting instead)
winrm quickconfig -q
Start-Sleep -Seconds 2

# --- Step 3: Install PowerShell 7 if not already installed ---
$statusToolStripLabel.Text = "Checking for PowerShell 7 installation..."
$form.Refresh()
if (-not (Get-Command pwsh.exe -ErrorAction SilentlyContinue)) {
    $statusToolStripLabel.Text = "PowerShell 7 not found. Installing the latest stable release..."
    $form.Refresh()
    
    # Use GitHub API to retrieve the latest stable release info.
    $uri = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $headers = @{ "User-Agent" = "Mozilla/5.0" }  # GitHub requires a User-Agent header.
    try {
        $release = Invoke-RestMethod -Uri $uri -Headers $headers -UseBasicParsing
    }
    catch {
        Write-Error "Failed to retrieve the latest PowerShell release info: $_"
        return
    }
    
    # Filter for the Windows x64 MSI asset and ensure it's not a preview.
    $installerAsset = $release.assets | Where-Object {
        $_.name -match "win-x64\.msi$" -and $_.name -notmatch "preview"
    } | Select-Object -First 1

    if ($installerAsset -and $installerAsset.browser_download_url) {
        $ps7InstallerUrl = $installerAsset.browser_download_url
        $ps7InstallerPath = Join-Path $env:TEMP "PowerShell7.msi"
        
        $statusToolStripLabel.Text = "Downloading PowerShell 7 installer..."
        $form.Refresh()
        Invoke-WebRequest -Uri $ps7InstallerUrl -OutFile $ps7InstallerPath
        
        $statusToolStripLabel.Text = "Installing PowerShell 7..."
        $form.Refresh()
        # Install the MSI silently.
        Start-Process msiexec.exe -ArgumentList "/i `"$ps7InstallerPath`" /qn" -Wait -Verb RunAs
        Start-Sleep -Seconds 5
    }
    else {
        Write-Error "Could not find the appropriate MSI asset in the latest PowerShell release."
        return
    }
}
else {
    $statusToolStripLabel.Text = "PowerShell 7 is already installed."
}
$form.Refresh()
Start-Sleep -Seconds 2

# --- Step 5: Kick off the DSC configuration portion using PowerShell 7 ---
$statusToolStripLabel.Text = "Applying DSC configuration (via PowerShell 7)..."
$progressBar.Value = 80
$form.Refresh()
[System.Windows.Forms.Application]::DoEvents()

# Validate the existence of WSConfig.yml
$sourceYmlPath = Join-Path $BaseDir 'WSConfig.yml'
if (-not (Test-Path $sourceYmlPath)) {
    [System.Windows.Forms.MessageBox]::Show("WSConfig.yml not found in `$BaseDir", 'Missing file', 'OK', 'Error')
    return
}

# (Optional) Check system uptime and wait if the machine is very new
$os = Get-CimInstance Win32_OperatingSystem
$uptime = (Get-Date) - $os.LastBootUpTime
if ($uptime.TotalSeconds -lt 120) {
    $waitTime = [math]::Round(120 - $uptime.TotalSeconds)
    $statusToolStripLabel.Text = "System initializing... waiting $waitTime seconds before applying DSC baseline."
    $form.Refresh()
    Start-Sleep -Seconds $waitTime
}

# Define the DSC baseline command (adjust if using YAML DSC or DSCv3-specific commands)
$ps7Command = @"
Copy-Item -Path '$sourceYmlPath' -Destination '$env:TEMP\WSConfig.yml' -Force;
try {
    dsc config set -f '$env:TEMP\WSConfig.yml'
    Remove-Item '$env:TEMP\WSConfig.yml' -Force
} catch {
    Write-Error 'DSC configuration error: ' + \$_.Exception.Message
}
"@

# Launch the DSC command using PowerShell 7 (pwsh.exe)
$proc = Start-Process -FilePath "pwsh.exe" -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$ps7Command -Verb RunAs -PassThru
Start-Sleep -Seconds 2
$proc.WaitForExit()

$statusToolStripLabel.Text = "DSC configuration process completed."
$form.Refresh()
Start-Sleep -Seconds 2