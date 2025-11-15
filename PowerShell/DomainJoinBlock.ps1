#---------------------------------#
# --- DOMAIN-JOIN HELPER -------- #
#---------------------------------#

# Load required assemblies
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Windows.Forms

function Show-LogBox {
    param(
        [string]$Message,
        [string]$Title = "Log",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, $Icon)
}

function Invoke-DomainJoinPrompt {
    param(
        [System.Windows.Forms.Button]$ExitButton = $null
    )

    # Prompt: Join domain?
    $joinPrompt = [System.Windows.Forms.MessageBox]::Show(
        "Join this workstation to a domain now?",
        "Domain Join",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($joinPrompt -ne [System.Windows.Forms.DialogResult]::Yes) {
        Show-LogBox "Domain join skipped." "Info"
        if ($ExitButton) { $ExitButton.Visible = $true }
        return
    }

    # Prompt for domain name
    do {
        $domain = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter the domain FQDN (e.g. contoso.local):",
            "Domain Name"
        ).Trim()

        if ([string]::IsNullOrWhiteSpace($domain)) {
            Show-LogBox "No domain entered—skipping domain join." "Join Skipped" "Warning"
            if ($ExitButton) { $ExitButton.Visible = $true }
            return
        }

        if (Test-NetConnection -ComputerName $domain -Port 389 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Quiet) {
            break
        }
        else {
            Show-LogBox "Cannot reach '$domain' on port 389. Check FQDN and network connectivity." "Invalid Domain" "Warning"
        }
    } while ($true)

    # Prompt for credentials and attempt domain join
    $maxTries = 3
    for ($i = 1; $i -le $maxTries; $i++) {
        $creds = Get-Credential -Message "Credentials to join '$domain' (attempt $i of $maxTries)"
        try {
            Add-Computer -DomainName $domain -Credential $creds -ErrorAction Stop

            Show-LogBox "Successfully joined '$domain'. The machine will now restart." "Join Successful"
            Restart-Computer -Force
            return
        }
        catch {
            Show-LogBox "Domain join attempt $i failed:`n$($_.Exception.Message)" "Join Failed" "Error"
            if ($i -lt $maxTries) {
                Show-LogBox "Join failed—check credentials and try again." "Retry" "Warning"
            }
            else {
                Show-LogBox "Maximum retries reached—skipping domain join." "Join Skipped" "Error"
            }
        }
    }

    if ($ExitButton) { $ExitButton.Visible = $true }
}

# Example usage (standalone)
Invoke-DomainJoinPrompt