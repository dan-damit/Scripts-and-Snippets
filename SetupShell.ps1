Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to extract embedded resources
function Extract-Resource {
    param (
        [string]$resName,
        [string]$targetPath
    )
    $assembly = [System.Reflection.Assembly]::GetExecutingAssembly()
    $stream = $assembly.GetManifestResourceStream($resName)
    if ($stream) {
        $reader = New-Object System.IO.BinaryReader($stream)
        [System.IO.File]::WriteAllBytes($targetPath, $reader.ReadBytes($stream.Length))
    } else {
        [System.Windows.Forms.MessageBox]::Show("Failed to find embedded resource: $resName", "Error", 'OK', 'Error')
    }
}

# Temp extraction path
$tempPath = "$env:TEMP\AdvTechInstaller"
New-Item -Path $tempPath -ItemType Directory -Force | Out-Null

# Extract resources (names must match embedded names exactly)
$resourceMap = @{
    "SetupShell.NewPCSetup.exe"      = "$tempPath\NewPCSetup.exe"
    "SetupShell.DSC3Baseline.exe"    = "$tempPath\DSC3Baseline.exe"
    "SetupShell.WSConfig.yml"        = "$tempPath\WSConfig.yml"
    "SetupShell.AcroRdrInstaller.exe" = "$tempPath\AcroRdrInstaller.exe"
}

foreach ($res in $resourceMap.Keys) {
    Extract-Resource $res $resourceMap[$res]
}

# GUI Setup
$form = New-Object System.Windows.Forms.Form
$form.Text = "Advantage Tech New PC Setup"
$form.Size = '360,250'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon(".\AdvTechLogo.ico")

$button = New-Object System.Windows.Forms.Button
$button.Text = "Run Setup"
$button.Font = 'Segoe UI,10'
$button.Size = '120,40'
$button.Location = '115,65'
$button.Add_Click({
    Start-Process "$tempPath\NewPCSetup.exe" -Verb RunAs -Wait
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$tempPath\DSC3Baseline.ps1`"" -Verb RunAs -Wait
    [System.Windows.Forms.MessageBox]::Show("Setup complete!", "Success")
    $form.Close()
})

$footer = New-Object System.Windows.Forms.Label
$footer.Text = "Advantage Tech - New PC Setup"
$footer.AutoSize = $true
$footer.Font = 'Segoe UI,8'
$footer.Location = '10,180'

$form.Controls.Add($button)
$form.Controls.Add($footer)
$form.Topmost = $true
$form.ShowDialog()