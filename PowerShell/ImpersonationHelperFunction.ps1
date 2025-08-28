# Impersonation helper
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Security.Principal;
public class CredImpersonator {
    [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool LogonUser(
        string lpszUsername,
        string lpszDomain,
        string lpszPassword,
        int dwLogonType,
        int dwLogonProvider,
        out IntPtr phToken);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
}
"@ -PassThru | Out-Null

function Test-PathWithCredentials {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][pscredential]$Credential
    )

    # Split domain\user if present
    $parts  = $Credential.UserName.Split('\',2)
    if ($parts.Count -eq 2) {
        $domain   = $parts[0]
        $username = $parts[1]
    } else {
        $domain   = $env:USERDOMAIN
        $username = $parts[0]
    }
    $password = $Credential.GetNetworkCredential().Password

    # LogonType: 9 = NewCredentials, Provider: 3 = WinNT
    $tokenPtr = [IntPtr]::Zero
    $success = [CredImpersonator]::LogonUser(
       $username, $domain, $password, 9, 3, [ref]$tokenPtr)

    if (-not $success) {
        return $false
    }

    $context = [System.Security.Principal.WindowsIdentity]::new($tokenPtr).Impersonate()
    try {
        return Test-Path $Path
    }
    finally {
        $context.Undo()
        [CredImpersonator]::CloseHandle($tokenPtr) | Out-Null
    }
}