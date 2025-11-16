<# System Repair Toolkit - GUI for DISM and SFC operations 

    Author: Dan.Damit
    https://github.com/dan-damit/scripts-and-snippets/powershell 
    
#>

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Set custom console title
$host.UI.RawUI.WindowTitle = "System Repair Toolkit"

# Create form
$form = New-Object Windows.Forms.Form
$form.Text = "System Repair Toolkit"
$form.Size = '410,350'
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Topmost = $true

# Status label
$status = New-Object Windows.Forms.Label
$status.Text = "Select an operation:"
$status.AutoSize = $true
$status.Location = '20,20'
$form.Controls.Add($status)

# Button factory
function New-Button {
    param ($text, $x, $y, $action)
    $btn = New-Object Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = '175,30'
    $btn.Location = "$x,$y"
    $btn.Add_Click($action)
    return $btn
}

# Ignore Reboot checkbox
$chkIgnoreReboot = New-Object Windows.Forms.CheckBox
$chkIgnoreReboot.Text = "Ignore Reboot"
$chkIgnoreReboot.AutoSize = $true
$chkIgnoreReboot.Location = '20,180'
$form.Controls.Add($chkIgnoreReboot)

# DISM /RestoreHealth
$form.Controls.Add((New-Button "DISM: RestoreHealth" 20 60 {
            $status.Text = "Running DISM /RestoreHealth..."
            Start-Process dism -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow
            $status.Text = "RestoreHealth completed."
        }))

# DISM /StartComponentCleanup
$form.Controls.Add((New-Button "DISM: StartComponentCleanup" 200 60 {
            $status.Text = "Running DISM /StartComponentCleanup..."
            Start-Process dism -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -Wait -NoNewWindow
            $status.Text = "StartComponentCleanup completed."
        }))

# DISM /ResetBase
$form.Controls.Add((New-Button "DISM: ResetBase" 20 100 {
            $status.Text = "Running DISM /ResetBase..."
            Start-Process dism -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait -NoNewWindow
            $status.Text = "ResetBase completed."
        }))

# SFC /scannow
$form.Controls.Add((New-Button "SFC: Scan and Repair" 200 100 {
            $status.Text = "Running SFC /scannow..."
            Start-Process sfc -ArgumentList "/scannow" -Wait -NoNewWindow
            $status.Text = "SFC scan completed."
        }))

# Install and run Windows Updates via PSWindowsUpdate
$form.Controls.Add((New-Button "Install Windows Updates" 20 140 {
            $status.Text = "Installing Windows Updates..."
            Set-ExecutionPolicy Bypass -Scope Process -Force
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            Install-Module PSWindowsUpdate -Force
            Import-Module PSWindowsUpdate

            $arguments = "-Install -AcceptAll -MicrosoftUpdate"
            if ($chkIgnoreReboot.Checked) {
                $arguments += " -IgnoreReboot"
            }

            Invoke-Expression "Get-WindowsUpdate $arguments"
            $status.Text = "Windows Updates installed."
        }))

# Reset Windows Update Components
$form.Controls.Add((New-Button "Reset Update Components" 200 140 {
            $status.Text = "Resetting Windows Update components..."
            Stop-Service -Name wuauserv -Force
            Stop-Service -Name cryptsvc -Force
            Stop-Service -Name bits -Force
            Stop-Service -Name msiserver -Force

            Remove-Item -Path "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -Force -ErrorAction SilentlyContinue
            Rename-Item -Path "$env:SystemRoot\SoftwareDistribution" -NewName "SoftwareDistribution.old" -Force
            Rename-Item -Path "$env:SystemRoot\System32\catroot2" -NewName "catroot2.old" -Force

            Start-Service -Name wuauserv
            Start-Service -Name cryptsvc
            Start-Service -Name bits
            Start-Service -Name msiserver

            $status.Text = "Windows Update components reset."
        }))

# Exit button
$form.Controls.Add((New-Button "Exit" 110 260 {
            $form.Close()
        }))

# Run form
[Windows.Forms.Application]::EnableVisualStyles()
[Windows.Forms.Application]::Run($form)