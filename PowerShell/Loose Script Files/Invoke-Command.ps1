$LTLcred = Get-Credential -Message "Enter credentials for LTL Server"

Invoke-Command -ComputerName LTL-GP1 -Credential $LTLcred -ScriptBlock {
    New-NetFirewallRule -DisplayName "Allow WinRM 5985 from Admin Subnet" `
        -Direction Inbound -Protocol TCP -LocalPort 5985 `
        -RemoteAddress 10.5.10.0/24, 10.19.10.0/24 `
        -Profile Domain -Action Allow
}

Invoke-Command -ComputerName LTL-GP1 -Credential $LTLcred -ScriptBlock {
    New-NetFirewallRule -DisplayName "Allow SQL 1433 from GP Clients" `
        -Direction Inbound -Protocol TCP -LocalPort 1433 `
        -RemoteAddress 10.19.10.0/24 `
        -Profile Domain -Action Allow
}

Invoke-Command -ComputerName LTL-GP1 -Credential $LTLcred -ScriptBlock {
    New-NetFirewallRule `
        -DisplayName "Allow SSRS HTTP (TCP 80) from Approved Subnets" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 80 `
        -RemoteAddress 10.0.0.0/24, 10.5.10.0/24, 10.19.20.0/24, 10.19.10.0/24 `
        -Profile Domain `
        -Action Allow `
        -Enabled True
}

Invoke-Command -ComputerName LTL-GP1 -Credential $LTLcred -ScriptBlock {
    New-NetFirewallRule -DisplayName "Allow SMB 445 from Data Subnet" `
        -Direction Inbound -Protocol TCP -LocalPort 445 `
        -RemoteAddress 10.19.10.0/24 `
        -Profile Domain -Action Allow
}

Invoke-Command -ComputerName LTL-FS1 -Credential $LTLcred -ScriptBlock {
    Get-NetFirewallProfile |
    Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
}

Invoke-Command -ComputerName LTL-FS1 -Credential $LTLcred -ScriptBlock {
    Set-NetFirewallProfile -Profile Domain -Enabled True
}

Invoke-Command -ComputerName LTL-FS1 -Credential $LTLcred -ScriptBlock {
    Get-ChildItem "\\LTL-FS1\shared\Data\A-R INVOICES 2026" `
        -Recurse `
        -Filter *.pdf | Unblock-File
}

Invoke-Command -ComputerName LTL-FS1 -Credential $LTLcred -ScriptBlock {
    Get-SmbShare -Name 'Shared' | Select-Object Name, Path, Description
}

Invoke-Command -ComputerName LTL-FS1 -Credential $LTLcred -ScriptBlock {
    & "C:\Scripts\NewUnblockPDFsTask.ps1"
}