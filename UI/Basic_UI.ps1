Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = "WS Setup Builder"
$form.Size = New-Object System.Drawing.Size(600, 400)
$form.StartPosition = "CenterScreen"

# Build Button
$buildButton = New-Object System.Windows.Forms.Button
$buildButton.Text = "Build Setup"
$buildButton.Size = New-Object System.Drawing.Size(100, 30)
$buildButton.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($buildButton)

# Close Button
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Size = New-Object System.Drawing.Size(100, 30)
$closeButton.Location = New-Object System.Drawing.Point(140, 20)
$closeButton.Add_Click({ $form.Close() })
$form.Controls.Add($closeButton)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready"
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(260, 27)
$form.Controls.Add($statusLabel)

# Log TextBox
$UpdateStatusBox = New-Object System.Windows.Forms.TextBox
$UpdateStatusBox.Multiline = $true
$UpdateStatusBox.ScrollBars = "Vertical"
$UpdateStatusBox.ReadOnly = $true
$UpdateStatusBox.Size = New-Object System.Drawing.Size(540, 280)
$UpdateStatusBox.Location = New-Object System.Drawing.Point(20, 60)
$UpdateStatusBox.Anchor = "Top, Bottom, Left, Right"
$form.Controls.Add($UpdateStatusBox)

# Update Status func
function UpdateStatus($msg) {
    $statusLabel.Text = $msg
    $UpdateStatusBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $msg`r`n")
}