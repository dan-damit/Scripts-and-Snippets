<# Delete inactive computers from Active Directory 

    Author: Dan.Damit
    (https://github.com/dan-damit)
    
#>

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module ActiveDirectory

# Console Title
$host.UI.RawUI.WindowTitle = "Inactive AD Cleanup"

# Create form
$form = New-Object Windows.Forms.Form
$form.Text = "Inactive AD Cleanup"
$form.Size = '600,500'
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Topmost = $true

# Label: Organizational Unit
$lblOU = New-Object Windows.Forms.Label
$lblOU.Text = "Select an Organizational Unit:"
$lblOU.Location = '20,20'
$lblOU.AutoSize = $true
$form.Controls.Add($lblOU)

# OU input
$cbOU = New-Object Windows.Forms.ComboBox
$cbOU.Size = '540,20'
$cbOU.Location = '20,40'
$cbOU.DropDownStyle = 'DropDownList'
$form.Controls.Add($cbOU)

$txtOU = New-Object Windows.Forms.TextBox
$txtOU.Size = '540,20'
$txtOU.Location = '20,40'
$form.Controls.Add($txtOU)

# Days input
$lblDays = New-Object Windows.Forms.Label
$lblDays.Text = "Days inactive:"
$lblDays.Location = '20,70'
$lblDays.AutoSize = $true
$form.Controls.Add($lblDays)

$txtDays = New-Object Windows.Forms.TextBox
$txtDays.Size = '100,20'
$txtDays.Location = '20,90'
$form.Controls.Add($txtDays)

# Preview list
$lstComputers = New-Object Windows.Forms.ListBox
$lstComputers.Size = '540,200'
$lstComputers.Location = '20,130'
$form.Controls.Add($lstComputers)

# Status label
$status = New-Object Windows.Forms.Label
$status.Text = "Status: Ready"
$status.Location = '20,340'
$status.AutoSize = $true
$form.Controls.Add($status)

# Button: Scan
$btnScan = New-Object Windows.Forms.Button
$btnScan.Text = "Scan Inactive Computers"
$btnScan.Size = '200,30'
$btnScan.Location = '20,370'
$btnScan.Add_Click({
        $lstComputers.Items.Clear()
        $OU = $cbOU.SelectedItem
        $DaysInactive = $txtDays.Text
        if (-not $OU -or -not $DaysInactive) {
            $status.Text = "Please enter both OU and days."
            return
        }
        try {
            $CutOffDate = (Get-Date).AddDays( - [int]$DaysInactive)
            $InactiveComputers = Get-ADComputer -Filter { LastLogonDate -lt $CutOffDate } -SearchBase $OU
            foreach ($Computer in $InactiveComputers) {
                $lstComputers.Items.Add($Computer.Name)
            }
            $status.Text = "$($InactiveComputers.Count) inactive computers found."
        }
        catch {
            $status.Text = "Error: $_"
        }
    })
$form.Controls.Add($btnScan)

# Button: Delete
$btnDelete = New-Object Windows.Forms.Button
$btnDelete.Text = "Delete Selected"
$btnDelete.Size = '200,30'
$btnDelete.Location = '240,370'
$btnDelete.Add_Click({
        if ($lstComputers.Items.Count -eq 0) {
            $status.Text = "No computers to delete."
            return
        }
        $Confirm = [Windows.Forms.MessageBox]::Show("Delete all listed computers?", "Confirm", "YesNo", "Warning")
        if ($Confirm -eq "Yes") {
            foreach ($ComputerName in $lstComputers.Items) {
                $Computer = Get-ADComputer -Identity $ComputerName
                Remove-ADComputer -Identity $Computer.DistinguishedName -Confirm:$false
            }
            $status.Text = "Deletion complete."
            $lstComputers.Items.Clear()
        }
        else {
            $status.Text = "Operation canceled."
        }
    })
$form.Controls.Add($btnDelete)

# Run form
[Windows.Forms.Application]::EnableVisualStyles()
[Windows.Forms.Application]::Run($form)

# Populate OU ComboBox
try {
    $OUs = Get-ADOrganizationalUnit -Filter 'Name -like "*Computers*" -or Name -like "*Workstations*" -or Name -like "*Servers*"' | Sort-Object DistinguishedName
    foreach ($ou in $OUs) {
        $cbOU.Items.Add($ou.DistinguishedName)
    }
    if ($cbOU.Items.Count -gt 0) {
        $cbOU.SelectedIndex = 0
    }
} catch {
    [Windows.Forms.MessageBox]::Show("Failed to load OUs. Are you connected to a domain?", "Error", "OK", "Error")
    $form.Close()
}