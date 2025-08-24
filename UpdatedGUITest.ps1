#-------------------#
#-----GUI Setup-----#
#-------------------#

# Load necessary assemblies.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the main form.
$form = New-Object System.Windows.Forms.Form
$form.Text = "AdvTech Onboarding"
$form.Size = '420,240'   # Increased height to accommodate our status bar.
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true

# Set the AdvTech logo icon.
$iconPath = Join-Path $PSScriptRoot "AdvTechLogo.ico"
if (Test-Path $iconPath) {
    $form.Icon = New-Object System.Drawing.Icon($iconPath)
} else {
    Write-Warning "Icon file not found: $iconPath"
}

# Create a label for additional instructions (optional).
$mainLabel = New-Object System.Windows.Forms.Label
$mainLabel.Text = "Initializing onboarding process..."
$mainLabel.Location = '30,40'
$mainLabel.Size = '360,30'
$mainLabel.Font = 'Segoe UI,12'
$form.Controls.Add($mainLabel)

#-----------------------------#
#---- StatusStrip Setup ------#
#-----------------------------#

# Create a StatusStrip to serve as the status bar.
$statusStrip = New-Object System.Windows.Forms.StatusStrip

# Create a ToolStripStatusLabel for textual status updates.
$statusToolStripLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusToolStripLabel.Text = "Starting..."
$statusStrip.Items.Add($statusToolStripLabel)

# Create a ToolStripProgressBar for visual progress.
$progressBar = New-Object System.Windows.Forms.ToolStripProgressBar
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0  # Starting at 0.
$progressBar.Step = 25  # For example, 4 steps = 100%.
$statusStrip.Items.Add($progressBar)

# Add StatusStrip to the form. It will dock automatically at the bottom.
$form.Controls.Add($statusStrip)

# Show and refresh the form.
$form.Show()
$form.Refresh()

#-------------------------------------#
#--- Collect NinjaRMM URI Prompt -----#
#-------------------------------------#

# Temporarily disable TopMost so that the InputBox appears on top.
$form.TopMost = $false
Add-Type -AssemblyName Microsoft.VisualBasic
$ninjaURI = [Microsoft.VisualBasic.Interaction]::InputBox(
    "Paste the full NinjaRMM installer URL:",
    "NinjaRMM Installer URL",
    ""
)
if ([string]::IsNullOrWhiteSpace($ninjaURI)) {
    Write-Warning "No NinjaRMM URL entered. Exiting..."
    Exit 1
}
# Restore TopMost behavior.
$form.TopMost = $true
Start-Sleep -Milliseconds 500

#-------------------------------------#
#--- DSC Configuration Phase Setup ---#
#-------------------------------------#

# Update status and progress.
$statusToolStripLabel.Text = "Decoding DSC configuration..."
$progressBar.Value = 10
$form.Refresh()
[System.Windows.Forms.Application]::DoEvents()

#--------------------------------#
#-- Grabbing Configs from YAML --#
#--------------------------------#

# Function to extract YAML payload from an embedded Base64 string.
$YamlBase64 = @'
IyB5YW1sLWxhbmd1YWdlLXNlcnZlcjogJHNjaGVtYT1odHRwczovL2FrYS5tcy9kc2Mvc2NoZW1hcy92My9idW5kbGVkL2NvbmZpZy9kb2N1bWVudC52c2NvZGUuanNvbg0KJHNjaGVtYTogaHR0cHM6Ly9ha2EubXMvZHNjL3NjaGVtYXMvdjMvYnVuZGxlZC9jb25maWcvZG9jdW1lbnQuanNvbg0KbWV0YWRhdGE6DQogIE1pY3Jvc29mdC5EU0M6DQogICAgc2VjdXJpdHlDb250ZXh0OiBlbGV2YXRlZA0KcmVzb3VyY2VzOg0KLSBuYW1lOiBTZXRBZHZhbnRhZ2VQb3dlclBsYW4NCiAgdHlwZTogTWljcm9zb2Z0LldpbmRvd3MvV2luZG93c1Bvd2VyU2hlbGwNCiAgcHJvcGVydGllczoNCiAgICByZXNvdXJjZXM6DQogICAgLSBuYW1lOiBTZXRBZHZhbnRhZ2VQb3dlclBsYW4NCiAgICAgIHR5cGU6IFBTRGVzaXJlZFN0YXRlQ29uZmlndXJhdGlvbi9TY3JpcHQNCiAgICAgIHByb3BlcnRpZXM6DQogICAgICAgICMgVGhlIEdldFNjcmlwdCBibG9jayBjYW4gcmV0dXJuIGEgYmFzaWMgcGxhY2Vob2xkZXIuDQogICAgICAgICMgTWF5YmUgdGhpcyBjb3VsZCBiZSB3aGVyZSBwYXJhbWV0ZXJzIGFyZSBwYXNzZWQgZnJvbSBOaW5qYSB0byB0aGUgc2NyaXB0Pw0KICAgICAgICBHZXRTY3JpcHQ6IHwNCiAgICAgICAgICBAeyBSZXN1bHQgPSAiTm90IG5lY2Vzc2FyeSIgfQ0KICAgICAgICAjIFRlc3RTY3JpcHQgc2hvdWxkIHJldHVybiAkdHJ1ZSBpZiB0aGUgY29uZmlndXJhdGlvbiBpcyBhbHJlYWR5IGluIHRoZSBkZXNpcmVkIHN0YXRlLg0KICAgICAgICAjIExvZ2ljIGhlcmUgVEJELiBQb3NzaWJsZSB0byBjaGVjayB3aXRoIE1pY3Jvc29mdC5XaW5kb3dzL1dNSSBhbmQgcmV0dXJuICR0cnVlIG9yICRmYWxzZSBiYXNlZCBvbiBmaW5kaW5ncz8NCiAgICAgICAgIyBGb3IgYSBzaW1wbGUgaW1wbGVtZW50YXRpb24gKG9yIHRlc3RpbmcpLCByZXR1cm4gJGZhbHNlIHRvIGVuZm9yY2UgU2V0U2NyaXB0IG9uIGV2ZXJ5IHJ1bi4NCiAgICAgICAgVGVzdFNjcmlwdDogfA0KICAgICAgICAgIHJldHVybiAkZmFsc2UNCiAgICAgICAgIyBTZXRTY3JpcHQgY29udGFpbnMgdGhlIHNjcmlwdCAvIGNvbW1hbmRzLg0KICAgICAgICBTZXRTY3JpcHQ6IHwNCiAgICAgICAgICB0cnkgew0KICAgICAgICAgICAgV3JpdGUtVmVyYm9zZSAiQ2hhbmdpbmcgcG93ZXIgcGxhbiB0byBIaWdoIFBlcmZvcm1hbmNlIg0KICAgICAgICAgICAgJEhpZ2hQZXJmID0gcG93ZXJjZmcgLWwgfCBGb3JFYWNoLU9iamVjdCB7DQogICAgICAgICAgICAgICAgaWYgKCRfLmNvbnRhaW5zKCJIaWdoIHBlcmZvcm1hbmNlIikpIHsgJF8uU3BsaXQoKVszXSB9DQogICAgICAgICAgICB9DQogICAgICAgICAgICAkQ3VyclBsYW4gPSAocG93ZXJjZmcgLWdldGFjdGl2ZXNjaGVtZSkuU3BsaXQoKVszXQ0KICAgICAgICAgICAgaWYgKCRDdXJyUGxhbiAtbmUgJEhpZ2hQZXJmKSB7DQogICAgICAgICAgICAgICAgcG93ZXJjZmcgLXNldGFjdGl2ZSAkSGlnaFBlcmYNCiAgICAgICAgICAgIH0NCiAgICAgICAgICB9IGNhdGNoIHsNCiAgICAgICAgICAgICAgdGhyb3cgIlVuYWJsZSB0byBzZXQgcG93ZXIgcGxhbiB0byBIaWdoIFBlcmZvcm1hbmNlIg0KICAgICAgICAgIH0NCiAgICAgICAgICBXcml0ZS1WZXJib3NlICJEdXBsaWNhdGUgY3VycmVudGx5IGFjdGl2ZSBwbGFuIGFzIEFkdmFudGFnZSBQZXJmb3JtYW5jZSINCiAgICAgICAgICBTdGFydC1TbGVlcCAtU2Vjb25kcyAzDQogICAgICAgICAgJEN1cnJQbGFuID0gKHBvd2VyY2ZnIC1nZXRhY3RpdmVzY2hlbWUpLnNwbGl0KClbM10NCiAgICAgICAgICAkbmV3cFBsYW4gPSAocG93ZXJjZmcgLWR1cGxpY2F0ZXNjaGVtZSAkQ3VyclBsYW4pLnNwbGl0KClbM10NCiAgICAgICAgICBwb3dlcmNmZyAtY2hhbmdlbmFtZSAkbmV3cFBsYW4gIkFkdmFudGFnZSBQZXJmb3JtYW5jZSINCiAgICAgICAgICBwb3dlcmNmZyAtc2V0YWN0aXZlICRuZXdwUGxhbg0KDQotIG5hbWU6IERpc2FibGVQb3dlck1hbmFnZW1lbnRPblVTQkh1YnMNCiAgdHlwZTogTWljcm9zb2Z0LldpbmRvd3MvV2luZG93c1Bvd2VyU2hlbGwNCiAgcHJvcGVydGllczoNCiAgICByZXNvdXJjZXM6DQogICAgLSBuYW1lOiBEaXNhYmxlUG93ZXJNYW5hZ2VtZW50T25VU0JIdWJzDQogICAgICB0eXBlOiBQc0Rlc2lyZWRTdGF0ZUNvbmZpZ3VyYXRpb24vU2NyaXB0DQogICAgICBwcm9wZXJ0aWVzOg0KICAgICAgICAjIFRoZSBHZXRTY3JpcHQgYmxvY2sgY2FuIHJldHVybiBhIGJhc2ljIHBsYWNlaG9sZGVyLg0KICAgICAgICAjIE1heWJlIHRoaXMgY291bGQgYmUgd2hlcmUgcGFyYW1ldGVycyBhcmUgcGFzc2VkIGZyb20gTmluamEgdG8gdGhlIHNjcmlwdD8NCiAgICAgICAgR2V0U2NyaXB0OiB8DQogICAgICAgICAgQHsgUmVzdWx0ID0gIk5vdCBuZWNlc3NhcnkiIH0NCiAgICAgICAgIyBUZXN0U2NyaXB0IHNob3VsZCByZXR1cm4gJHRydWUgaWYgdGhlIGNvbmZpZ3VyYXRpb24gaXMgYWxyZWFkeSBpbiB0aGUgZGVzaXJlZCBzdGF0ZS4NCiAgICAgICAgIyBMb2dpYyBoZXJlIFRCRC4gUG9zc2libGUgdG8gY2hlY2sgd2l0aCBNaWNyb3NvZnQuV2luZG93cy9XTUkgYW5kIHJldHVybiAkdHJ1ZSBvciAkZmFsc2UgYmFzZWQgb24gZmluZGluZ3M
'@

function Extract-YamlConfig {
    param ([string]$TargetPath)
    try {
        [IO.File]::WriteAllBytes($TargetPath, [Convert]::FromBase64String($YamlBase64))
    }
    catch {
        Write-Error "Failed to decode YAML: $($_.Exception.Message)"
    }
}

#--------------------#
#-- Working Folder --#
#--------------------#
$workingDir = Join-Path $env:TEMP 'AdvTechInstall'
New-Item -Path $workingDir -ItemType Directory -Force | Out-Null
$ymlPath = Join-Path $workingDir 'WSConfig.yml'
Extract-YamlConfig -TargetPath $ymlPath

#------------------------------#
#-----Apply DSC Configs--------#
#------------------------------#
if (Test-Path $ymlPath) {
    Write-Host "Applying DSC configuration...Please be patient. This will take a few minutes." -ForegroundColor Yellow
    Write-Log "Applying DSC configuration from YAML file: $ymlPath"
    try {
        $dscOutput = dsc config set -f $ymlPath
        $dscOutput | ForEach-Object { Write-Log $_ }
        Write-Log "DSC configuration applied successfully."
    }
    catch {
        Write-Log "Error during execution: $($_.Exception.Message)"
    }
} else {
    Write-Output "Error: YAML file not found!"
    Write-Log "Error: YAML file not found at $ymlPath"
}

#-----------------------------#
#-----Finalize & Exit---------#
#-----------------------------#
$statusLabel.Text = "All onboarding steps completed. Finalizing..."
$form.Refresh()
Start-Sleep -Seconds 5
$form.Close()



# Run installers with status updates and progress increments

# Step 1: Installing NinjaRMM
$statusLabel.Text = "Installing Ninja..."
$progressBar.Value = 10   # Increment progress bar (e.g., up to 10% for this stage)
$form.Refresh()
[System.Windows.Forms.Application]::DoEvents()  # Force GUI update
Install-NinjaRMM -ninjaURI $ninjaURI
Start-Sleep -Seconds 5

# Step 2: Installing Chrome
$statusLabel.Text = "Installing Chrome..."
$progressBar.Value = 40   # Now increase to 40%
$form.Refresh()
[System.Windows.Forms.Application]::DoEvents()
Install-Chrome
Start-Sleep -Seconds 5

# Step 3: Installing Adobe Reader
$statusLabel.Text = "Installing Adobe Reader..."
$progressBar.Value = 70   # Increase to 70%
$form.Refresh()
[System.Windows.Forms.Application]::DoEvents()
Install-AdobeReader
Start-Sleep -Seconds 5

# Step 4: Applying DSC Configuration (if you have this step after installs)
$statusLabel.Text = "Applying DSC configuration..."
$progressBar.Value = 100  # Set progress to 100%
$form.Refresh()
[System.Windows.Forms.Application]::DoEvents()
# Place your DSC configuration call/code here.
Start-Sleep -Seconds 3

# Finalize
$statusLabel.Text = "All onboarding steps completed. Finalizing..."
$form.Refresh()
Start-Sleep -Seconds 5
$form.Close()