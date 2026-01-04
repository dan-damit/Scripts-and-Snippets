
<#
O365_Sales_Report_Graph.ps1
Weekly send/receive report using EXO CBA + Microsoft Graph app-only (certificate)
Anchor group: sales@vadtek.com (synced DL)
Author: Dan Damit (https://github.com/dan-damit)

Prereqs:
- ExchangeOnlineManagement module
- Microsoft.Graph module
- App "VAC Unattended Scripts" with Graph Mail.Send (Application) + admin
    consent: Which looks to be good to go on UTILITY-1 as of 12/2025
- Certificate installed in LocalMachine Store to run as SYSTEM in PDQ (thumbprint below)
#>

[CmdletBinding()]
param(
    # ======= Tenant/App/Cert =======
    [string]$TenantId = "e1b83792-ab2b-418b-9481-fe12c76f201e",
    [string]$ClientId = "9c0e43db-f3fc-4bba-9530-10b5d063730b",
    [string]$CertThumb = "F226D64FF93DE27A1CFC9F9078829FBBD5B21770",

    # ======= Mail settings =======
    [string]$SenderUpn = "office365@vadtek.com",
    [string]$AnchorAddress = "sales@vadtek.com",
    [string]$To = "llambie@vadtek.com",   # change to desired recipient(s) after testing
    [string]$Bcc = "alerts@vadtek.com",   # change to desired recipient(s) after testing

    # ======= Working directory =======
    [string]$WorkingDir = "C:\Users\Public\Documents\Admin Arsenal\PDQ Deploy\Repository\VAC Scripts\Office365_Send_Recieve_Reports"
)

# ------------------------- SETUP -------------------------
New-Item -ItemType Directory -Path $WorkingDir -Force | Out-Null
Set-Location -Path $WorkingDir

# ======= Load exclusions from _SalesEmailReport_Exclusions.txt =======
# \\UTILITY-1.vadtek.com\C$\Users\Public\Documents\Admin Arsenal\PDQ Deploy\Repository\VAC Scripts\Office365_Send_Recieve_Reports\_SalesEmailReport_Exclusions.txt
$ExclusionFile = Join-Path $WorkingDir '_SalesEmailReport_Exclusions.txt'
$Exclusions = @()
if (Test-Path -LiteralPath $ExclusionFile) {
    $Exclusions = Get-Content -LiteralPath $ExclusionFile |
    Where-Object { $_ -and $_.Trim() -ne '' } |
    ForEach-Object { $_.Trim().ToLower() }
    Write-Host "Loaded $($Exclusions.Count) exclusions from $ExclusionFile"
}
else {
    Write-Host "No exclusions file found at $ExclusionFile"
}

# ======= Labels/filenames (Sales only) =======
$mailboxGrpName = "Sales"
$dateStamp = (Get-Date).ToString("MM-dd-yyyy")

# Transcript/log
$logFile = Join-Path $WorkingDir "O365_Sales_$((Get-Date).ToString('MM-dd-yyyy')).log"
Start-Transcript -Path $logFile

# ======= Connect to Exchange Online (CBA) =======
Import-Module ExchangeOnlineManagement -ErrorAction Stop
$exoParams = @{
    AppId                 = $ClientId
    Organization          = "vadtek.com"        # must be tenant domain, not GUID
    CertificateThumbprint = $CertThumb
    ShowBanner            = $false
}
Connect-ExchangeOnline @exoParams  # [3](https://michev.info/blog/post/5704/reporting-on-microsoft-365-groups-links-2023-updated-version)


# ======= Date window (previous Mon–Sun) =======
$startDate = (Get-Date).AddDays(-7).Date
$endDate = (Get-Date).AddDays(-1).Date.AddHours(23).AddMinutes(59).AddSeconds(59)
$subject = "Weekly e-mail report (Sales) $($startDate.ToShortDateString()) - $($endDate.ToShortDateString())"

# ======= Resolve Sales DL members (recursive, returns Address+DisplayName) =======
# Recursive DL expansion function to loop through the anchor group and grab
# member data (email + display name), handling nested groups if present (futureproofing).
function Resolve-AddressesFromAnchor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Anchor
    )

    $dg = Get-DistributionGroup -Identity $Anchor -ErrorAction SilentlyContinue
    if ($dg) {
        $visitedGroups = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        function Expand-Group {
            param([string]$GroupId)
            if (-not $visitedGroups.Add($GroupId)) { return @() }

            $members = Get-DistributionGroupMember -Identity $GroupId -ResultSize Unlimited -ErrorAction SilentlyContinue
            $memberInfo = @()

            foreach ($m in $members) {
                switch -Regex ($m.RecipientType) {
                    # Mailboxes and mail users
                    "UserMailbox|SharedMailbox|MailUser|TeamMailbox" {
                        if ($m.PrimarySmtpAddress) {
                            $memberInfo += [pscustomobject]@{
                                EmailAddress = $m.PrimarySmtpAddress
                                DisplayName  = $m.DisplayName
                            }
                        }
                    }

                    # Nested groups: recurse
                    "MailUniversalDistributionGroup|MailUniversalSecurityGroup|Group" {
                        $memberInfo += Expand-Group -GroupId $m.Identity
                    }

                    # Mail contacts (external)
                    "MailContact" {
                        if ($m.ExternalEmailAddress) {
                            # ExternalEmailAddress can be prefixed (e.g., SMTP:someone@ext.com), normalize to SMTP form
                            $addr = $m.ExternalEmailAddress.ToString()
                            if ($addr -match 'SMTP:(.+)') { $addr = $Matches[1] }
                            $memberInfo += [pscustomobject]@{
                                EmailAddress = $addr
                                DisplayName  = $m.DisplayName
                            }
                        }
                    }
                }
            }

            return $memberInfo
        }

        # Expand, then de-dupe by EmailAddress while keeping the first DisplayName encountered
        $expanded = Expand-Group -GroupId $dg.Identity
        $dedup = $expanded | Group-Object -Property EmailAddress |
        ForEach-Object {
            # Prefer a non-empty DisplayName if available
            $first = $_.Group | Where-Object { $_.DisplayName } | Select-Object -First 1
            if (-not $first) { $first = $_.Group[0] }
            [pscustomobject]@{
                EmailAddress = $first.EmailAddress
                DisplayName  = $first.DisplayName
            }
        }

        # Sort by EmailAddress for stability
        return ($dedup | Sort-Object EmailAddress)
    }

    # Fallback: if not a DL, accept a single recipient
    $rec = Get-Recipient -Identity $Anchor -ErrorAction SilentlyContinue
    if ($rec -and $rec.PrimarySmtpAddress) {
        return @([pscustomobject]@{
                EmailAddress = $rec.PrimarySmtpAddress
                DisplayName  = $rec.DisplayName
            })
    }

    throw "Unable to resolve members for $Anchor"
}

# Resolve once: produces objects with EmailAddress + DisplayName
$memberInfo = Resolve-AddressesFromAnchor -Anchor $AnchorAddress


# ======= Normalizer for edge cases (e.g., SMTP: prefix) =======
# Can update regex as needed for other edge cases when found
function Format-Emails {
    param([string]$Email)
    if ($Email -match '^SMTP:(.+)$') { $Email = $Matches[1] }
    return $Email.Trim().ToLower()
}

# ======= Build address list and display-name cache =======
$emailAddresses = $memberInfo.EmailAddress
$DisplayCache = @{}

foreach ($mi in $memberInfo) {
    if (-not $DisplayCache.ContainsKey($mi.EmailAddress)) {
        $DisplayCache[$mi.EmailAddress] = if ($mi.DisplayName -and $mi.DisplayName.Trim() -ne '') { $mi.DisplayName }
        else {
            "[Display name not found]"
        }
    }
}

# ======= Pre-filter addresses using exclusions (exact match, normalized) =======
$FilteredAddresses = $emailAddresses | Where-Object {
    $Exclusions -notcontains (Format-Emails $_)
}

# (Optional) Align display cache to filtered addresses
$FilteredDisplayCache = @{}
foreach ($addr in $FilteredAddresses) {
    $FilteredDisplayCache[$addr] = $DisplayCache[$addr]
}

# ======= Trace (V2) and build CSV =======
$outputFile = Join-Path $WorkingDir ($mailboxGrpName + "_" + $dateStamp + ".csv")
Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue

$TotalSendCount = 0
$TotalReceiveCount = 0
$result = @()

foreach ($addr in $FilteredAddresses) {
    $send = Get-MessageTraceV2 -SenderAddress    $addr -StartDate $startDate -EndDate $endDate -ResultSize 5000 -ErrorAction SilentlyContinue
    $recv = Get-MessageTraceV2 -RecipientAddress $addr -StartDate $startDate -EndDate $endDate -ResultSize 5000 -ErrorAction SilentlyContinue

    $sendCount = ($send | Group-Object -Property MessageTraceId).Count
    $receiveCount = ($recv  | Group-Object -Property MessageTraceId).Count

    $TotalSendCount += $sendCount
    $TotalReceiveCount += $receiveCount

    $displayName = $FilteredDisplayCache[$addr]

    $result += [pscustomobject]@{
        'Display Name'  = $displayName
        'Email Address' = $addr
        'Send Count'    = $sendCount
        'Receive Count' = $receiveCount
    }
}

# Output CSV
$result | ConvertTo-Csv -NoTypeInformation | Out-File $outputFile -Encoding utf8
Write-Host "Sales report CSV written: $outputFile"

# ======= HTML body =======
$head = @"
<style>
 body { font-family: Calibri; font-size: 11pt; color: #000; }
 th, td { text-align:left; border:1px solid #000; border-collapse:collapse; padding:3px 10px 3px 3px; }
 th { font-size:12pt; background-color:#d4d7d9; color:#000; }
 td { color:#000; }
</style>
"@
$importHtml = Import-Csv -Path $outputFile | ConvertTo-Html -Head $head
$bodyHtml = @"
<p><b>Range:</b> $($startDate.ToShortDateString()) - $($endDate.ToShortDateString())</p>
<p><b>Total Sent:</b> $TotalSendCount<br/><b>Total Received:</b> $TotalReceiveCount</p>
$importHtml
"@

# ======= Send via Microsoft Graph (app-only cert) =======
# Built for PowerShell 7+; if running Windows PowerShell 5.1, avoid loading the
# full meta-module to reduce function/variable count issues. Ran into this for 
# initial testing using Windows PowerShell 5.1 on UTILITY-1.
$psIsWin = $PSVersionTable.PSEdition -eq 'Desktop'
if ($psIsWin) {
    $Script:MaximumFunctionCount = 18000
    $Script:MaximumVariableCount = 18000
}
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertThumb -NoWelcome

# Only load the small submodule that contains Send-MgUserMail
Import-Module Microsoft.Graph.Users.Actions -ErrorAction Stop

# --- Preflight: ensure the attachment exists ---
if (-not (Test-Path -LiteralPath $outputFile)) {
    Write-Error "Attachment file not found: $outputFile. Aborting send."
    throw
}

# Attachment
$bytes = [System.IO.File]::ReadAllBytes($outputFile)
$base64 = [System.Convert]::ToBase64String($bytes)
$attachment = @{
    "@odata.type" = "#microsoft.graph.fileAttachment"
    Name          = [System.IO.Path]::GetFileName($outputFile)
    ContentType   = "text/csv"
    ContentBytes  = $base64
}

# Payload
$payload = @{
    Message         = @{
        Subject       = $subject
        Body          = @{ ContentType = "HTML"; Content = $bodyHtml }
        ToRecipients  = @(@{ EmailAddress = @{ Address = $To } })
        BccRecipients = @(@{ EmailAddress = @{ Address = $Bcc } })
        Attachments   = @($attachment)
        ReplyTo       = @(
            @{ EmailAddress = @{ Address = "office365@vadtek.com" } }
            # Can add more if needed
        )
    }
    SaveToSentItems = $true
}

# ======= Send and error handling tailored to PDQ Connect Automations =======
# Fail-fast on non-terminating errors from cmdlets
$ErrorActionPreference = 'Stop'

try {
    Send-MgUserMail -UserId $SenderUpn -BodyParameter $payload
    Write-Output ("SUCCESS: Sales report email sent as {0} at {1}." -f $SenderUpn, (Get-Date))
    # Optional: Be explicit for PDQ Connect (return code 0 = success)
    $global:LASTEXITCODE = 0
    return
}
catch {
    Write-Error ("Graph send failed: {0}" -f $_.Exception.Message)
    if ($_.Exception.PSObject.Properties['Response']) {
        Write-Error ("Status: {0}" -f $_.Exception.Response.StatusCode)
        Write-Error ("Headers: {0}" -f ($_.Exception.Response.Headers | Out-String))
    }
    # Non-zero exit code so PDQ Connect marks this as an error and shows 'Errors'
    $global:LASTEXITCODE = 1
    return
}
finally {
    # Cleanup always runs (even after 'exit' in try/catch in PowerShell 7+)
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
}
Stop-Transcript | Out-Null
