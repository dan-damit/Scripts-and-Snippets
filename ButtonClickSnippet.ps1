$installButton.Add_Click({
	# Disable the install button to prevent re-clicks.
    $installButton.Enabled = $false
    $checkedItems = $checkboxes | Where-Object { $_.Checkbox.Checked }

    # If no checkbox is selected, give feedback and do nothing.
    if ($checkedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select an option before beginning the onboarding process.","Selection Required")
        return
    }

    # Otherwise, proceed with your installation logic.
    # Step 1: Install Ninja Agent (skip if service exists).
    $statusToolStripLabel.Text = "Installing Ninja Agent."
    $progressBar.Value = 20

    foreach ($entry in $checkboxes) {
        if ($entry.Checkbox.Checked) {
            if (Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue) {
                $statusToolStripLabel.Text = "Ninja Agent already installed."
                Start-Sleep -Seconds 3
            } else {
                $statusToolStripLabel.Text = "Installing: $($entry.Checkbox.Text) Agent."
                try {
                    $localInstaller = Join-Path $env:TEMP ("NinjaAgent_" + [guid]::NewGuid().ToString() + ".msi")
                    Invoke-WebRequest -Uri $entry.Uri -OutFile $localInstaller -UseBasicParsing -Headers $headers
                    Start-Process msiexec.exe -ArgumentList "/i `"$localInstaller`" /qn" -Wait
                    Remove-Item $localInstaller -Force
                } catch {
                    Write-Warning "Installation failed for $($entry.Checkbox.Text): $($_.Exception.Message)"
                }
            }
            $progressBar.Value += 20
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    
    $statusToolStripLabel.Text = "Ninja Agent installations completed."
    Start-Sleep -Seconds 3
})