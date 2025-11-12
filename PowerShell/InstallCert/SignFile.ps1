param(
    [string] $TimestampDefault = "http://timestamp.digicert.com"
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# === Embedded PFX base64 (replace with your full base64) ===
$certBase64 = @"
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
"@

# Helper: convert plaintext string to SecureString
function Convert-ToSecureString([string]$plain) {
    $ss = New-Object -TypeName System.Security.SecureString
    foreach ($c in $plain.ToCharArray()) { $ss.AppendChar($c) }
    $ss.MakeReadOnly()
    return $ss
}

# Build form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sign a File (embedded cert, runtime password)"
$form.Size = New-Object System.Drawing.Size(480,330)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# File label + textbox + browse
$lblFile = New-Object System.Windows.Forms.Label
$lblFile.Location = New-Object System.Drawing.Point(10,16)
$lblFile.Size = New-Object System.Drawing.Size(100,20)
$lblFile.Text = "File to sign:"
$form.Controls.Add($lblFile)

$txtFile = New-Object System.Windows.Forms.TextBox
$txtFile.Location = New-Object System.Drawing.Point(120,14)
$txtFile.Size = New-Object System.Drawing.Size(260,20)
$form.Controls.Add($txtFile)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(385,12)
$btnBrowse.Size = New-Object System.Drawing.Size(75,23)
$btnBrowse.Text = "Browse..."
$btnBrowse.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "All files (*.*)|*.*"
    if ($ofd.ShowDialog() -eq "OK") { $txtFile.Text = $ofd.FileName }
})
$form.Controls.Add($btnBrowse)

# Password label + secure textbox
$lblPwd = New-Object System.Windows.Forms.Label
$lblPwd.Location = New-Object System.Drawing.Point(10,52)
$lblPwd.Size = New-Object System.Drawing.Size(100,20)
$lblPwd.Text = "PFX Password:"
$form.Controls.Add($lblPwd)

$txtPwd = New-Object System.Windows.Forms.TextBox
$txtPwd.Location = New-Object System.Drawing.Point(120,50)
$txtPwd.Size = New-Object System.Drawing.Size(260,20)
$txtPwd.UseSystemPasswordChar = $true
$form.Controls.Add($txtPwd)

# Timestamp label + combobox
$lblTs = New-Object System.Windows.Forms.Label
$lblTs.Location = New-Object System.Drawing.Point(10,88)
$lblTs.Size = New-Object System.Drawing.Size(100,20)
$lblTs.Text = "Timestamp server:"
$form.Controls.Add($lblTs)

$cbTs = New-Object System.Windows.Forms.ComboBox
$cbTs.Location = New-Object System.Drawing.Point(120,86)
$cbTs.Size = New-Object System.Drawing.Size(260,22)
$cbTs.DropDownStyle = 'DropDown'
$cbTs.Items.AddRange(@(
    "http://timestamp.digicert.com",
    "http://timestamp.comodoca.com/rfc3161",
    "http://timestamp.sectigo.com",
    "http://timestamp.globalsign.com/scripts/timstamp.dll"  
))
$cbTs.Text = $TimestampDefault
$form.Controls.Add($cbTs)

# Dry-run checkbox
$chkDry = New-Object System.Windows.Forms.CheckBox
$chkDry.Location = New-Object System.Drawing.Point(10,118)
$chkDry.Size = New-Object System.Drawing.Size(300,20)
$chkDry.Text = "Dry-run: show cert info and file hash only (no signing)"
$form.Controls.Add($chkDry)

# Status label (multi-line)
$lblStatus = New-Object System.Windows.Forms.TextBox
$lblStatus.Location = New-Object System.Drawing.Point(10,150)
$lblStatus.Size = New-Object System.Drawing.Size(455,140)
$lblStatus.ReadOnly = $true
$lblStatus.Multiline = $true
$lblStatus.ScrollBars = 'Vertical'
$form.Controls.Add($lblStatus)

# Sign button
$btnSign = New-Object System.Windows.Forms.Button
$btnSign.Location = New-Object System.Drawing.Point(315,118)
$btnSign.Size = New-Object System.Drawing.Size(75,23)
$btnSign.Text = "Run"
$btnSign.Add_Click({
    $lblStatus.Text = ""
    try {
        if ([string]::IsNullOrWhiteSpace($txtFile.Text)) { throw "Select a file to sign." }
        if (-not (Test-Path $txtFile.Text)) { throw "File not found: $($txtFile.Text)" }
        if ([string]::IsNullOrEmpty($txtPwd.Text)) { throw "Enter the PFX password." }

        # Decode PFX into memory
        $pfxBytes = [Convert]::FromBase64String($certBase64)

        # Secure password
        $securePwd = Convert-ToSecureString $txtPwd.Text

        # Choose flags: prefer EphemeralKeySet to avoid persisting keys if available
        $flagsEnum = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]
        $flags = $flagsEnum::Exportable -bor $flagsEnum::MachineKeySet
        if ($flagsEnum -as [type] -and $flagsEnum.GetEnumNames() -contains 'EphemeralKeySet') {
            $flags = $flags -bor $flagsEnum::EphemeralKeySet
        } else {
            # fallback: include PersistKeySet when Ephemeral not present
            $flags = $flags -bor $flagsEnum::PersistKeySet
        }

        # Instantiate certificate from bytes (in-memory)
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pfxBytes, $securePwd, $flags)

        # Show cert info for dry-run or for operator info
        $thumb = $cert.Thumbprint
        $subject = $cert.Subject
        $expire = $cert.NotAfter
        $lblStatus.AppendText("Cert subject: $subject`r`n")
        $lblStatus.AppendText("Thumbprint: $thumb`r`n")
        $lblStatus.AppendText("Expires: $expire`r`n")

        # File hash (SHA256)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fs = [IO.File]::OpenRead($txtFile.Text)
        $hashBytes = $sha.ComputeHash($fs)
        $fs.Close()
        $hashHex = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
        $lblStatus.AppendText("File SHA256: $hashHex`r`n")

        if ($chkDry.Checked) {
            $lblStatus.AppendText("Dry-run enabled. No signing performed.`r`n")
        } else {
            # Perform signing with timestamp
            $ts = $cbTs.Text
            $lblStatus.AppendText("Signing with timestamp server: $ts`r`n")
            $sig = Set-AuthenticodeSignature -FilePath $txtFile.Text -Certificate $cert -TimestampServer $ts
            $lblStatus.AppendText("Signature status: $($sig.Status)`r`n")
            if ($sig.StatusMessage) { $lblStatus.AppendText("Message: $($sig.StatusMessage)`r`n") }
        }
    } catch {
        $lblStatus.AppendText("Error: $($_.Exception.Message)`r`n")
    } finally {
        # Cleanup: zero and dispose sensitive objects
        try { if ($pfxBytes) { [System.Array]::Clear($pfxBytes,0,$pfxBytes.Length) } } catch {}
        try { if ($hashBytes) { [System.Array]::Clear($hashBytes,0,$hashBytes.Length) } } catch {}
        try { if ($sha) { $sha.Dispose() } } catch {}
        try { if ($cert) { $cert.Reset(); $cert.Dispose() } } catch {}
        # clear plaintext password from textbox variable
        $txtPwd.Text = ""
    }
})
$form.Controls.Add($btnSign)

# Show the form
[void]$form.ShowDialog()