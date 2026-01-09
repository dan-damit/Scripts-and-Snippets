<# Cleanup Stale DNS entries

 - Author: Dan.Damit (https://github.com/dan-damit/)

#>

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module DnsServer

# Console Title
$host.UI.RawUI.WindowTitle = "Cleanup Stale DNS Records"

# Create form
$form = New-Object Windows.Forms.Form
$form.Text = "Cleanup Stale DNS Records"
$form.Size = '600,500'
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Topmost = $true

# Label: DNS Zone
$lblZone = New-Object Windows.Forms.Label
$lblZone.Text = "Select a DNS Zone:"
$lblZone.Location = '20,20'
$lblZone.AutoSize = $true
$form.Controls.Add($lblZone)

# Zone input
$cbZone = New-Object Windows.Forms.ComboBox
$cbZone.Size = '540,20'
$cbZone.Location = '20,40'
$cbZone.DropDownStyle = 'DropDownList'
$form.Controls.Add($cbZone)

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
$lstRecords = New-Object Windows.Forms.ListBox
$lstRecords.Size = '540,200'
$lstRecords.Location = '20,130'
$form.Controls.Add($lstRecords)

# Status label
$status = New-Object Windows.Forms.Label
$status.Text = "Status: Ready"
$status.Location = '20,340'
$status.AutoSize = $true
$form.Controls.Add($status)

# Global record cache
$Global:StaleRecords = @()

# Button: Scan
$btnScan = New-Object Windows.Forms.Button
$btnScan.Text = "Scan for stale entries"
$btnScan.Size = '200,30'
$btnScan.Location = '20,370'
$btnScan.Add_Click({
        $lstRecords.Items.Clear()
        $Global:StaleRecords = @()
        $Zone = $cbZone.SelectedItem
        $DaysInactive = $txtDays.Text
        if (-not $Zone -or -not $DaysInactive) {
            $status.Text = "Please enter both zone and days."
            return
        }
        try {
            $CutoffDate = (Get-Date).AddDays( - [int]$DaysInactive)
            $StaleRecords = Get-DnsServerResourceRecord -ZoneName $Zone |
            Where-Object {
                $_.Timestamp -and $_.Timestamp -lt $CutoffDate -and
                $_.RecordType -eq "A" -and
                $_.TimeToLive -ne 0
            }
            $Global:StaleRecords = $StaleRecords
            foreach ($Record in $StaleRecords) {
                $lstRecords.Items.Add("$($Record.HostName) → $($Record.RecordData.IPv4Address)")
            }
            $status.Text = "$($StaleRecords.Count) stale records found."
        }
        catch {
            $status.Text = "Error: $_"
        }
    })
$form.Controls.Add($btnScan)

# Button: Delete
$btnDelete = New-Object Windows.Forms.Button
$btnDelete.Text = "Delete Selected Records"
$btnDelete.Size = '200,30'
$btnDelete.Location = '240,370'
$btnDelete.Add_Click({
        if ($Global:StaleRecords.Count -eq 0) {
            $status.Text = "No records to delete."
            return
        }
        $Confirm = [Windows.Forms.MessageBox]::Show("Delete all listed DNS records?", "Confirm", "YesNo", "Warning")
        if ($Confirm -eq "Yes") {
            foreach ($Record in $Global:StaleRecords) {
                Remove-DnsServerResourceRecord -ZoneName $cbZone.SelectedItem -InputObject $Record -Force
            }
            $status.Text = "Deletion complete."
            $lstRecords.Items.Clear()
            $Global:StaleRecords = @()
        }
        else {
            $status.Text = "Operation canceled."
        }
    })
$form.Controls.Add($btnDelete)

# Button: Export
$btnExport = New-Object Windows.Forms.Button
$btnExport.Text = "Export to CSV"
$btnExport.Size = '200,30'
$btnExport.Location = '20,410'
$btnExport.Add_Click({
        if ($Global:StaleRecords.Count -eq 0) {
            $status.Text = "No records to export."
            return
        }
        $Global:StaleRecords | Select-Object HostName, RecordType, Timestamp, RecordData | Export-Csv "$env:TEMP\StaleDNS.csv" -NoTypeInformation
        $status.Text = "Exported to $env:TEMP\StaleDNS.csv"
    })
$form.Controls.Add($btnExport)

# Populate Zone ComboBox
$Zones = Get-DnsServerZone | Select-Object -ExpandProperty ZoneName
foreach ($zone in $Zones) {
    $cbZone.Items.Add($zone)
}
if ($cbZone.Items.Count -gt 0) { $cbZone.SelectedIndex = 0 }

# Run form
[Windows.Forms.Application]::EnableVisualStyles()
[Windows.Forms.Application]::Run($form)