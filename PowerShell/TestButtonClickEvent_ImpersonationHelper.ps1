$testButton.Add_Click({

    $path = $uncTextBox.Text.Trim()

    # Skip logic
    if ([string]::IsNullOrEmpty($path)) {
        $ans = [Windows.Forms.MessageBox]::Show(
            "No installer path provided. Skip Ninja Agent install?",
            "Skip Installer?",
            "YesNo",
            "Question")
        if ($ans -eq "Yes") {
            $global:SkipAgent = $true
            $installButton.Enabled = $true
            [Windows.Forms.MessageBox]::Show("Skipping agent install.","Info")
        }
        else {
            $installButton.Enabled = $false
            [Windows.Forms.MessageBox]::Show("Enter path and test again.","Warning")
        }
        return
    }

    # First try as current user
    if (Test-Path $path) {
        $installButton.Enabled = $true
        [Windows.Forms.MessageBox]::Show("Path valid.","Success")
        return
    }

    # Offer credentials
    $retry = [Windows.Forms.MessageBox]::Show(
        "Cannot access path. Supply credentials?",
        "Access Denied",
        "YesNo",
        "Question")
    if ($retry -ne "Yes") {
        $installButton.Enabled = $true
		$global:SkipAgent = $true
        return
    }

    $creds = Get-Credential -Message "Enter share credentials"
    if (Test-PathWithCredentials -Path $path -Credential $creds) {
        $installButton.Enabled = $true
        [Windows.Forms.MessageBox]::Show("Path valid with credentials.","Success")
    }
    else {
        $installButton.Enabled = $true
		$global:SkipAgent = $true
        [Windows.Forms.MessageBox]::Show("Still cannot access. Proceeding without Agent installation.","Error")
    }
})