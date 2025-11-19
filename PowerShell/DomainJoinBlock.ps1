<# Domain Join script 

    Author: Dan.Damit (https://github.com/dan-damit)

    This script provides a GUI for joining a computer to a domain.
    It allows the user to select a domain from a dropdown list and enter credentials.
    The script attempts to join the selected domain and provides feedback via message boxes.

#>

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Domain Join Utility"
$form.Size = New-Object System.Drawing.Size(400, 300)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(20, 90)
$form.Controls.Add($statusLabel)

# Domain ComboBox
$domainComboBox = New-Object System.Windows.Forms.ComboBox
$domainComboBox.Location = New-Object System.Drawing.Point(20, 50)
$domainComboBox.Width = 200
$domainComboBox.DropDownStyle = 'DropDownList'
$form.Controls.Add($domainComboBox)

# Button 1 - Join Domain
$joinButton = New-Object System.Windows.Forms.Button
$joinButton.Text = "Join Domain"
$joinButton.Location = New-Object System.Drawing.Point(240, 50)
$joinButton.Add_Click({
        $selectedDomain = $domainComboBox.SelectedItem
        if (-not $selectedDomain) {
            Show-LogBox "No domain selected." "Error" "Error"
            return
        }

        $creds = Get-Credential -Message "Credentials to join '$selectedDomain'"
        Join-Domain -Domain $selectedDomain -Credential $creds -StatusLabel $statusLabel
    })
$form.Controls.Add($joinButton)

# Exit Button
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Size = New-Object System.Drawing.Size(80, 30)
$exitButton.Location = New-Object System.Drawing.Point(300, 220)
$exitButton.Add_Click({ $form.Close() })
$form.Controls.Add($exitButton)

# Log Box Function
function Show-LogBox {
    param(
        [string]$Message,
        [string]$Title = "Log",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, $Icon)
}

# Domain Join Functions
function Join-Domain {
    param (
        [string]$Domain,
        [System.Management.Automation.PSCredential]$Credential,
        [System.Windows.Forms.Label]$StatusLabel = $null,
        [System.Windows.Forms.Button]$ExitButton = $null
    )

    if ($StatusLabel) {
        $StatusLabel.Text = "Attempting to join domain '$Domain'..."
    }

    if (-not (Test-NetConnection -ComputerName $Domain -Port 389 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Quiet)) {
        Show-LogBox "Cannot reach '$Domain' on port 389. Check FQDN and network connectivity." "Invalid Domain" "Warning"
        if ($StatusLabel) { $StatusLabel.Text = "Domain unreachable." }
        if ($ExitButton) { $ExitButton.Visible = $true }
        return
    }

    try {
        Add-Computer -DomainName $Domain -Credential $Credential -ErrorAction Stop
        Show-LogBox "Successfully joined '$Domain'. Reboot the computer to finalize." "Join Successful"
        if ($StatusLabel) { $StatusLabel.Text = "Successfully joined '$Domain'" }
    }
    catch {
        Show-LogBox "Domain join failed:`n$($_.Exception.Message)" "Join Failed" "Error"
        if ($StatusLabel) { $StatusLabel.Text = "Join failed. See message box for details." }
        if ($ExitButton) { $ExitButton.Visible = $true }
    }
}

# Populate domain list dynamically
try {
    $domains = ([System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()).Domains | ForEach-Object { $_.Name }
    if ($domains.Count -gt 0) {
        $domainComboBox.Items.AddRange($domains)
        $domainComboBox.SelectedIndex = 0
    }
}
catch {
    if ($domainComboBox.Items.Count -eq 0) {
        $domainComboBox.Items.Add("contoso.local")
        $domainComboBox.SelectedIndex = 0
    }
}

# Show the form
$form.Topmost = $false
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()