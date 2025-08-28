# Create a label for the branding information.
$brandLabel = New-Object System.Windows.Forms.Label
$brandLabel.Text = "© 2025 Dan Damit"  # The © symbol can be typed directly or as "`u00A9"
$brandLabel.AutoSize = $true
$brandLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$brandLabel.ForeColor = [System.Drawing.Color]::Gray

# Option 1: Use anchoring so the label stays at bottom right.
$brandLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right

# Option 2: If the form size is fixed, you can calculate its location. 
# (Here a 10-pixel margin is used from the bottom and right edges.)
$brandLabel.Location = New-Object System.Drawing.Point($form.ClientSize.Width - $brandLabel.Width - 10, $form.ClientSize.Height - $brandLabel.Height - 10)

# If the form isn’t rendered yet, updating the label’s location during the form's Shown event ensures the label is placed correctly:
$form.Add_Shown({
    $brandLabel.Location = New-Object System.Drawing.Point($form.ClientSize.Width - $brandLabel.Width - 10, 
                                                              $form.ClientSize.Height - $brandLabel.Height - 10)
})

# Add the label to the form’s controls
$form.Controls.Add($brandLabel)