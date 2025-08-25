#---------------------------------#
# --- DOMAIN-JOIN HELPER ------- #
#---------------------------------#
function Invoke-DomainJoinPrompt {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Button]$ExitButton
    )

    # Ask if they want to join a domain
    $joinPrompt = [System.Windows.Forms.MessageBox]::Show(
        "Join this workstation to a domain now?",
        "Domain Join",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($joinPrompt -ne [System.Windows.Forms.DialogResult]::Yes) {
        # Skip domain join
        $ExitButton.Visible = $true
        return
    }

    # Bring in VB InputBox
    Add-Type -AssemblyName Microsoft.VisualBasic

    # Loop until a reachable domain or blank (to skip)
    do {
        $domain = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter the domain FQDN (e.g. contoso.local):",
            "Domain Name"
        ).Trim()

        if ([string]::IsNullOrEmpty($domain)) {
            [System.Windows.Forms.MessageBox]::Show(
                "No domain entered—skipping domain join.",
                "Join Skipped",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            $ExitButton.Visible = $true
            return
        }

        # Test LDAP port reachability
        if (Test-NetConnection -ComputerName $domain -Port 389 -Quiet) {
            break
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                "Cannot reach $domain on port 389. Verify the FQDN and network connectivity.",
                "Invalid Domain",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
    } while ($true)

    # Retry loop for credentials + Add-Computer
    $maxTries = 3
    for ($i = 1; $i -le $maxTries; $i++) {
        $creds = Get-Credential -Message "Credentials to join '$domain' (attempt $i of $maxTries)"
        try {
            Add-Computer -DomainName $domain `
                         -Credential  $creds `
                         -ErrorAction Stop

            Write-Log "Domain join to '$domain' succeeded on attempt $i."
            [System.Windows.Forms.MessageBox]::Show(
                "Successfully joined '$domain'. The machine will now restart.",
                "Join Successful",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            Restart-Computer -Force
            return
        }
        catch {
            Write-Log "Domain join attempt $i failed: $($_.Exception.Message)"
            if ($i -lt $maxTries) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Join failed—check credentials and try again.",
                    "Join Failed",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
            }
            else {
                [System.Windows.Forms.MessageBox]::Show(
                    "Maximum retries reached—skipping domain join.",
                    "Join Skipped",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    }

    # Finally, reveal the Exit button
    $ExitButton.Visible = $true
}
