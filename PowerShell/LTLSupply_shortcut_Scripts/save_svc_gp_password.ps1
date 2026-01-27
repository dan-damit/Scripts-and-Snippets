
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredXmlPath')]

param(
    [string]$DomainUser   = '[YourUserNameHere}',
    [string]$BaseDir      = 'C:\ProgramData\TechToolbox',
    [string]$KeyPath      = 'C:\ProgramData\TechToolbox\dpapi_machine.key',
    [string]$CredXmlPath  = 'C:\ProgramData\TechToolbox\svc_gp.cred.xml'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
if (-not (Test-Path $BaseDir)) { New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null }

Write-Host "[Init] Creating/validating LocalMachine DPAPI-protected key..."
if (-not (Test-Path $KeyPath)) {
    # 32 random bytes; protect with LocalMachine DPAPI
    $keyBytes = New-Object byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($keyBytes)
    $protected = [Convert]::ToBase64String(
        [Security.Cryptography.ProtectedData]::Protect(
            $keyBytes, $null,
            [Security.Cryptography.DataProtectionScope]::LocalMachine
        )
    )
    Set-Content -Path $KeyPath -Value $protected -Force
    Write-Host "[Init] Machine key created at $KeyPath"
} else {
    Write-Host "[Init] Machine key already exists at $KeyPath"
}

# Unprotect key for use now
$keyBytes = [Security.Cryptography.ProtectedData]::Unprotect(
    [Convert]::FromBase64String((Get-Content $KeyPath -Raw)),
    $null,
    [Security.Cryptography.DataProtectionScope]::LocalMachine
)

# Prompt for svc password and write a small XML with encrypted password (machine-usable)
$user = $DomainUser
$sec  = Read-Host -AsSecureString -Prompt "Enter password for $user"
$enc  = $sec | ConvertFrom-SecureString -Key $keyBytes

$xml = @"
<Credential>
  <User>$user</User>
  <EncryptedPassword>$enc</EncryptedPassword>
</Credential>
"@

$xml | Set-Content -Path $CredXmlPath -Encoding UTF8 -Force
Write-Host "[Init] Credential XML saved to $CredXmlPath"
Write-Host "[Init] Done."

