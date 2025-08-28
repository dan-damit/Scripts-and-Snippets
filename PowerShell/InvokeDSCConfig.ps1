function Invoke-BaselineConfig {
    [CmdletBinding()]
    param(
        # The directory that contains your WSConfig.yml file.
        [Parameter(Mandatory = $true)]
        [string]$BaseDir,
        
        # UI elements passed in from your main form.
        [Parameter(Mandatory = $true)]
        $statusToolStripLabel,
        
        [Parameter(Mandatory = $true)]
        $progressBar,
        
        [Parameter(Mandatory = $true)]
        $form
    )
    
    Write-Log "Starting baseline configuration process."
    
    # --- Step 1: Configure the network location to Private.
    $statusToolStripLabel.Text = "Configuring network location to Private."
    $form.Refresh()
    Write-Log "Setting all network profiles to Private."
    try {
        Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction Stop
        Write-Log "Network profiles successfully set to Private."
    }
    catch {
        Write-Log "Error setting network location to Private: $($_.Exception.Message)"
        throw $_
    }
    Start-Sleep -Seconds 2
    
    # --- Step 2: Enable remote management.
    $statusToolStripLabel.Text = "Configuring Remote Management."
    $form.Refresh()
    Write-Log "Enabling PowerShell remoting using Enable-PSRemoting -Force."
    try {
        Enable-PSRemoting -Force -ErrorAction Stop
        Write-Log "Remote Management enabled successfully."
    }
    catch {
        Write-Log "Error enabling PowerShell Remoting: $($_.Exception.Message)"
        throw $_
    }
    Start-Sleep -Seconds 2
    
    # --- Step 3: Install PowerShell 7 if not already installed.
    $statusToolStripLabel.Text = "Checking for PowerShell 7 installation."
    $form.Refresh()
    Write-Log "Checking for PowerShell 7 installation."
    if (-not (Get-Command pwsh.exe -ErrorAction SilentlyContinue)) {
        $statusToolStripLabel.Text = "PowerShell 7 not found. Installing the latest stable release."
        $form.Refresh()
        Write-Log "PowerShell 7 not detected. Initiating download and installation."

        # Retrieve the latest stable release info from GitHub.
        $uri = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $headers = @{ "User-Agent" = "Mozilla/5.0" }  # GitHub requires a User-Agent header.
        try {
            Write-Log "Fetching latest PowerShell release info from GitHub."
            $release = Invoke-RestMethod -Uri $uri -Headers $headers -UseBasicParsing -ErrorAction Stop
            Write-Log "Successfully retrieved release info."
        }
        catch {
            Write-Log "Failed to retrieve the latest PowerShell release info: $($_.Exception.Message)"
            throw $_
        }
        
        # Filter for the Windows x64 MSI asset (excluding preview releases).
        $installerAsset = $release.assets | Where-Object {
            $_.name -match "win-x64\.msi$" -and $_.name -notmatch "preview"
        } | Select-Object -First 1

        if ($installerAsset -and $installerAsset.browser_download_url) {
            $ps7InstallerUrl = $installerAsset.browser_download_url
            $ps7InstallerPath = Join-Path $BaseDir "PowerShell7.msi"
            
            $statusToolStripLabel.Text = "Downloading PowerShell 7 installer."
            $form.Refresh()
            Write-Log "Downloading PS7 installer from: $ps7InstallerUrl to $ps7InstallerPath."
            try {
                Invoke-WebRequest -Uri $ps7InstallerUrl -OutFile $ps7InstallerPath -ErrorAction Stop
                Write-Log "Download complete."
            }
            catch {
                Write-Log "Error downloading PS7 installer: $($_.Exception.Message)"
                throw $_
            }
            
            $statusToolStripLabel.Text = "Installing PowerShell 7."
            $form.Refresh()
            Write-Log "Starting installation of PowerShell 7 via msiexec."
            try {
                Start-Process msiexec.exe -ArgumentList "/i `"$ps7InstallerPath`" /qn" -Wait -Verb RunAs -ErrorAction Stop
                Write-Log "PowerShell 7 installed successfully."
            }
            catch {
                Write-Log "Error installing PowerShell 7: $($_.Exception.Message)"
                throw $_
            }
            Start-Sleep -Seconds 5
        }
        else {
            $errMsg = "Could not find the appropriate MSI asset in the latest PowerShell release."
            Write-Log $errMsg
            throw $errMsg
        }
    }
    else {
        $statusToolStripLabel.Text = "PowerShell 7 is already installed."
        Write-Log "PowerShell 7 is already present on the system."
    }
    $form.Refresh()
    Start-Sleep -Seconds 2
    
    # --- Step 5: Kick off the DSC configuration portion using PowerShell 7.
    $statusToolStripLabel.Text = "Applying Baseline."
    $progressBar.Value = 80
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    Write-Log "Initiating DSC baseline configuration."
    
    # Validate that WSConfig.yml exists.
    $sourceYmlPath = Join-Path $BaseDir 'WSConfig.yml'
    if (-not (Test-Path $sourceYmlPath)) {
        $msg = "WSConfig.yml not found in $BaseDir."
        Write-Log $msg
        [System.Windows.Forms.MessageBox]::Show($msg, 'Missing file', 'OK', 'Error')
        return
    }
    Write-Log "Found WSConfig.yml at: $sourceYmlPath."
    
    # Create a separate script file to apply the DSC configuration via PS7
	$applyDSCPath = Join-Path $BaseDir "ApplyBaseline.ps1"
@'
try {
    dsc config set -f "$BaseDir\WSConfig.yml"
} catch {
    Write-Error "DSC configuration error: " + $_.Exception.Message
}
'@ | Out-File -Encoding UTF8 $applyDSCPath

	Write-Log "Waiting 5 seconds before invoking DSC baseline configuration via PS7..."
	Start-Sleep -Seconds 5

	Write-Log "Invoking DSC baseline configuration using PowerShell 7 from: $applyDSCPath"
	try {
		# Use pwsh.exe to launch the separate DSC apply script
		$proc = Start-Process -FilePath "pwsh.exe" -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File', $applyDSCPath -Verb RunAs -PassThru
		$proc.WaitForExit()
		Write-Log "DSC configuration completed successfully via PowerShell 7."
	}
	catch {
		Write-Log "Error executing DSC configuration via PS7: $($_.Exception.Message)"
		throw $_
	}
    
    $statusToolStripLabel.Text = "DSC configuration process completed."
    $form.Refresh()
    Write-Log "Baseline DSC configuration process finished."
    Start-Sleep -Seconds 2

    Write-Log "Baseline configuration process completed successfully."
}