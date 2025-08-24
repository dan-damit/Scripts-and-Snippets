# --- Step 5: Kick off the DSC configuration portion using PowerShell 7.
    $statusToolStripLabel.Text = "Applying Baseline."
    $progressBar.Value = 80
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    Write-Log "Initiating Baseline configuration."
    
    # Validate that WSConfig.yml exists.
    $sourceYmlPath = Join-Path $BaseDir 'WSConfig.yml'
    if (-not (Test-Path $sourceYmlPath)) {
        $msg = "WSConfig.yml not found in $BaseDir."
        Write-Log $msg
        [System.Windows.Forms.MessageBox]::Show($msg, 'Missing file', 'OK', 'Error')
        return
    }
    Write-Log "Found WSConfig.yml at: $sourceYmlPath."
	Start-Sleep -Milliseconds 100
	Write-Log "Waiting 5 seconds before invoking DSC baseline configuration via PS7..."
	Start-Sleep -Seconds 5
	
	# Define the path to the prepackaged ApplyBaseline.ps1 script
	$applyDSCPath = Join-Path $BaseDir "ApplyBaseline.ps1"
	Write-Log "Invoking DSC baseline configuration using PowerShell 7 from: $applyDSCPath"

	# Launch a new PowerShell 7 process to run the DSC configuration script in a fresh environment.
	Start-Process -FilePath "pwsh.exe" `
		-ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $applyDSCPath `
		-WindowStyle Hidden -Wait

	$statusToolStripLabel.Text = "DSC configuration process completed."
	$form.Refresh()
	Write-Log "Baseline DSC configuration process finished."
	Start-Sleep -Seconds 2
	Write-Log "Onboarding Process completed successfully."