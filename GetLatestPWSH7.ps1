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