Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "PowerShell GUI Wrapper"
$form.Size = New-Object System.Drawing.Size(400,300)
$form.StartPosition = "CenterScreen"

# Label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Choose an action:"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(20,20)
$form.Controls.Add($label)

# Button 1 - Example Action
$button1 = New-Object System.Windows.Forms.Button
$button1.Text = "Run SFC Scan"
$button1.Size = New-Object System.Drawing.Size(120,30)
$button1.Location = New-Object System.Drawing.Point(20,60)
$button1.Add_Click({
    Start-Process powershell -ArgumentList "-Command sfc /scannow" -Verb RunAs
})
$form.Controls.Add($button1)

# Button 2 - Another Action
$button2 = New-Object System.Windows.Forms.Button
$button2.Text = "Check Updates"
$button2.Size = New-Object System.Drawing.Size(120,30)
$button2.Location = New-Object System.Drawing.Point(160,60)
$button2.Add_Click({
    Start-Process powershell -ArgumentList "-Command Get-WindowsUpdate" -Verb RunAs
})
$form.Controls.Add($button2)

# Exit Button
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Size = New-Object System.Drawing.Size(80,30)
$exitButton.Location = New-Object System.Drawing.Point(300,220)
$exitButton.Add_Click({ $form.Close() })
$form.Controls.Add($exitButton)

# Show the form
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()