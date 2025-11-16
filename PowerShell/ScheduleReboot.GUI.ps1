Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Schedule Reboot"
$form.Size = New-Object System.Drawing.Size(300,180)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Select reboot time (24-hour):"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(20,20)
$form.Controls.Add($label)

# Hour dropdown
$hourBox = New-Object System.Windows.Forms.ComboBox
$hourBox.Location = New-Object System.Drawing.Point(20,50)
$hourBox.Size = New-Object System.Drawing.Size(60,25)
0..23 | ForEach-Object { $hourBox.Items.Add($_.ToString("D2")) }
$hourBox.SelectedIndex = 20  # Default to 20:00
$form.Controls.Add($hourBox)

# Minute dropdown
$minuteBox = New-Object System.Windows.Forms.ComboBox
$minuteBox.Location = New-Object System.Drawing.Point(100,50)
$minuteBox.Size = New-Object System.Drawing.Size(60,25)
0..59 | ForEach-Object { $minuteBox.Items.Add($_.ToString("D2")) }
$minuteBox.SelectedIndex = 0
$form.Controls.Add($minuteBox)

# OK button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "Schedule"
$okButton.Location = New-Object System.Drawing.Point(180,50)
$okButton.Size = New-Object System.Drawing.Size(80,25)
$form.Controls.Add($okButton)

# Status label
$status = New-Object System.Windows.Forms.Label
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(20,90)
$form.Controls.Add($status)

# Button click event
$okButton.Add_Click({
    $hour = $hourBox.SelectedItem
    $minute = $minuteBox.SelectedItem
    if ($hour -and $minute) {
        $now = Get-Date
        $scheduledTime = Get-Date -Hour $hour -Minute $minute -Second 0
        if ($scheduledTime -lt $now) { $scheduledTime = $scheduledTime.AddDays(1) }

        $action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /t 0"
        $trigger = New-ScheduledTaskTrigger -Once -At $scheduledTime
        $taskName = "ScheduledReboot$($scheduledTime.ToString('HHmm'))"

        Register-ScheduledTask -TaskName $taskName `
            -Action $action -Trigger $trigger `
            -Description "One-time reboot at $($scheduledTime.ToString('HH:mm'))" `
            -User "SYSTEM" -RunLevel Highest -Force

        $status.Text = "Reboot scheduled for $($scheduledTime.ToString('HH:mm'))"
    } else {
        $status.Text = "Please select both hour and minute."
    }
})

$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()