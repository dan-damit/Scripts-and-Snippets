<#
    Standalone Mail Header Analyzer  
    Author: Dan Damit / (https://github.com/dan-damit/)
#>

# ------------------------------
# Minimal Logging System
# ------------------------------
function Write-Log {
    param (
        [string]$Level,
        [string]$Message
    )

    switch ($Level.ToLower()) {
        "info"  { $color = "Gray" }
        "warn"  { $color = "Yellow" }
        "error" { $color = "Red" }
        "ok"    { $color = "Green" }
        default { $color = "White" }
    }

    Write-Host "[$Level] $Message" -ForegroundColor $color
}

# ------------------------------
# HEADER UNFOLDING + NORMALIZATION
# ------------------------------
function Get-HeaderBlock {
    param([Parameter(Mandatory)][string]$HeadersText)

    # Unfold continuation lines
    $unfolded = [regex]::Replace($HeadersText, "(`r?`n)[ \t]+", ' ')
    $unfolded = $unfolded -replace "`r?`n", "`n"
    $lines = $unfolded -split "`n"

    [pscustomobject]@{
        Text  = $unfolded
        Lines = $lines
    }
}

# ------------------------------
# Extract First Public IP
# ------------------------------
function Get-FirstPublicIP {
    param([Parameter(Mandatory)][string[]]$ReceivedLines)

    $privateRanges = @(
        '^10\.', '^127\.', '^169\.254\.', '^172\.(1[6-9]|2[0-9]|3[0-1])\.', '^192\.168\.',
        '^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\.' # CGNAT
    )

    $isPrivate = {
        param($ip)
        foreach ($pat in $privateRanges) { if ($ip -match $pat) { return $true } }
        return $false
    }

    $ipv4Regex = [regex]'(?<!\d)(?:\d{1,3}\.){3}\d{1,3}(?!\d)'

    for ($i = $ReceivedLines.Count - 1; $i -ge 0; $i--) {
        $line = $ReceivedLines[$i]
        $matches = $ipv4Regex.Matches($line)

        foreach ($m in $matches) {
            $ip = $m.Value

            # sanity check: octets ≤ 255
            if (($ip -split '\.') | ForEach-Object { [int]$_ } | Where-Object { $_ -gt 255 }) {
                continue
            }

            if (-not (& $isPrivate $ip)) {
                return $ip
            }
        }
    }

    return $null
}

# ------------------------------
# Extract Domain
# ------------------------------
function Get-Domain {
    param([Parameter(Mandatory)][string]$Value)

    $clean = $Value -replace '[<>"]', '' -replace '^\s+|\s+$',''

    if ($clean -match '[^@\s]+@(?<dom>[A-Za-z0-9.-]+\.[A-Za-z]{2,})') {
        return $Matches.dom.ToLower()
    }
    elseif ($clean -match '(?<dom>[A-Za-z0-9.-]+\.[A-Za-z]{2,})') {
        return $Matches.dom.ToLower()
    }
    
    return $null
}

# ------------------------------
# Parse Authentication-Results
# ------------------------------
function Format-AuthResults {
    param(
        [Parameter(Mandatory)][string[]]$Lines,
        [string]$Label = 'edge'
    )

    $result = [ordered]@{
        Label        = $Label
        SPF          = $null
        SPF_MailFrom = $null
        DKIM         = $null
        DKIM_Domains = @()
        DMARC        = $null
        DMARC_From   = $null
        CompAuth     = $null
        ARC          = $null
        Raw          = @()
    }

    $re = @{
        spf      = [regex]'\bspf=(?<val>[a-z]+)\b'
        spf_mf   = [regex]'smtp\.mailfrom=(?<val>[^;\s]+)'
        dkim     = [regex]'\bdkim=(?<val>[a-z]+)\b'
        dkim_d   = [regex]'header\.d=(?<val>[^;\s]+)'
        dmarc    = [regex]'\bdmarc=(?<val>[a-z]+)\b'
        dmarcF   = [regex]'header\.from=(?<val>[^;\s]+)'
        comp     = [regex]'\bcompauth=(?<val>[a-z]+)\b'
        arc      = [regex]'\barc=(?<val>[a-z]+)\b'
    }

    foreach ($line in $Lines) {
        $result.Raw += $line

        if ($line -match $re.spf)     { $result.SPF = $Matches.val }
        if ($line -match $re.spf_mf)  { $result.SPF_MailFrom = $Matches.val }
        if ($line -match $re.dkim)    { $result.DKIM = $Matches.val }
        if ($line -match $re.dkim_d)  { $result.DKIM_Domains += $Matches.val.ToLower() }
        if ($line -match $re.dmarc)   { $result.DMARC = $Matches.val }
        if ($line -match $re.dmarcF)  { $result.DMARC_From = $Matches.val.ToLower() }
        if ($line -match $re.comp)    { $result.CompAuth = $Matches.val }
        if ($line -match $re.arc)     { $result.ARC = $Matches.val }
    }

    $result.DKIM_Domains = $result.DKIM_Domains | Select-Object -Unique

    return [pscustomobject]$result
}

# ------------------------------
# MAIN ANALYZER
# ------------------------------
function Test-MailHeaderAuth {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName='Text', Mandatory)][string]$HeadersText,
        [Parameter(ParameterSetName='File', Mandatory)][string]$Path,
        [Parameter(ParameterSetName='Clipboard')][switch]$FromClipboard,

        [ValidateSet('Summary','Markdown','Object','Json')]
        [string]$Format = 'Summary',

        [switch]$AsObject
    )

    $ErrorActionPreference = 'Stop'
    Write-Log Info "Starting standalone header analysis..."

    try {
        if ($PSCmdlet.ParameterSetName -eq 'File') {
            if (-not (Test-Path $Path)) { throw "File not found: $Path" }
            $HeadersText = Get-Content -LiteralPath $Path -Raw
            Write-Log Warn "Loaded headers from file: $Path"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Clipboard') {
            if (-not $IsWindows) { throw "-FromClipboard supported only on Windows." }
            $HeadersText = Get-Clipboard -Raw
            if (-not $HeadersText) { throw "Clipboard is empty." }
            Write-Log Warn "Loaded headers from clipboard."
        }

        $block = Get-HeaderBlock -HeadersText $HeadersText
        $lines = $block.Lines

        # Extract key headers
        $kv = @{
            From       = ($lines | Where-Object { $_ -match '^(?i)From:' } | Select-Object -First 1)
            Sender     = ($lines | Where-Object { $_ -match '^(?i)Sender:' } | Select-Object -First 1)
            ReturnPath = ($lines | Where-Object { $_ -match '^(?i)Return-Path:' } | Select-Object -First 1)
            Subject    = ($lines | Where-Object { $_ -match '^(?i)Subject:' } | Select-Object -First 1)
            MessageID  = ($lines | Where-Object { $_ -match '^(?i)Message-Id:' } | Select-Object -First 1)
        }

        $fromAddr    = $kv.From -replace '^(?i)From:\s*',''
        $senderAddr  = $kv.Sender -replace '^(?i)Sender:\s*',''
        $returnPath  = $kv.ReturnPath -replace '^(?i)Return-Path:\s*',''

        $fromDomain   = if ($fromAddr) { Get-Domain $fromAddr }
        $senderDomain = if ($senderAddr) { Get-Domain $senderAddr }
        $rpDomain     = if ($returnPath) { Get-Domain $returnPath }

        # Authentication-Results lines
        $arEdge    = $lines | Where-Object { $_ -match '^(?i)Authentication-Results:' }
        $arOrig1   = $lines | Where-Object { $_ -match '^(?i)Authentication-Results-Original:' }
        $arOrig2   = $lines | Where-Object { $_ -match '^(?i)X-Original-Authentication-Results:' }

        $edgeAuth  = if ($arEdge)  { Format-AuthResults -Lines $arEdge    -Label 'edge' }
        $originAuth= if ($arOrig1 -or $arOrig2) { Format-AuthResults -Lines ($arOrig1 + $arOrig2) -Label 'origin' }

        $receivedLines = $lines | Where-Object { $_ -match '^(?i)Received:' }
        $firstPublicIP = if ($receivedLines) { Get-FirstPublicIP -ReceivedLines $receivedLines }

        $mailFrom = $edgeAuth.SPF_MailFrom ?? $originAuth.SPF_MailFrom ?? $returnPath
        $mailFromDomain = if ($mailFrom) { Get-Domain $mailFrom }

        # Alignment
        $dkimDomains = @()

        if ($edgeAuth.DKIM_Domains)   { $dkimDomains += $edgeAuth.DKIM_Domains }
        if ($originAuth.DKIM_Domains) { $dkimDomains += $originAuth.DKIM_Domains }

        $dkimDomains = $dkimDomains | Where-Object { $_ } | Select-Object -Unique

        $dkimAligned = $false
        foreach ($d in $dkimDomains) {
            if ($d -eq $fromDomain -or $d -like "*.$fromDomain") {
                $dkimAligned = $true
                break
            }
        }

        $spfAligned = $false
        if ($fromDomain -and $mailFromDomain) {
            if ($mailFromDomain -eq $fromDomain -or $mailFromDomain -like "*.$fromDomain") {
                $spfAligned = $true
            }
        }

        # Best signal preference
        $spf   = $edgeAuth.SPF   ?? $originAuth.SPF
        $dkim  = $edgeAuth.DKIM  ?? $originAuth.DKIM
        $dmarc = $edgeAuth.DMARC ?? $originAuth.DMARC
        $arc   = $edgeAuth.ARC   ?? $originAuth.ARC

        # Verdict
        $reasons = New-Object System.Collections.Generic.List[string]

        if ($dmarc -eq 'pass') {
            $verdict = 'Low - Likely Legitimate'
            $confidence = 'High'
            $reasons.Add("DMARC passed and aligned.")
        }
        elseif ($dkim -eq 'pass' -and $dkimAligned) {
            $verdict = 'Low - Likely Legitimate'
            $confidence = 'High'
            $reasons.Add("DKIM passed and aligned.")
        }
        elseif ($spf -eq 'pass' -and $spfAligned) {
            $verdict = 'Low - Likely Legitimate'
            $confidence = 'High'
            $reasons.Add("SPF passed and aligned.")
        }
        elseif ($dkim -eq 'pass' -and -not $dkimAligned) {
            $verdict = 'Medium - Possibly Legitimate'
            $confidence = 'Medium'
            $reasons.Add("DKIM passed but appears unaligned.")
        }
        elseif ($arc -eq 'pass' -and $dmarc -ne 'pass') {
            $verdict = 'Medium - Possibly Legitimate'
            $confidence = 'Medium'
            $reasons.Add("ARC passed but DMARC did not.")
        }
        else {
            $verdict = 'High - Likely Malicious'
            $confidence = 'Variable'

            if ($dmarc -eq 'fail') { $reasons.Add("DMARC failed.") }
            if ($dkim -in @('fail','none',$null)) { $reasons.Add("DKIM did not validate.") }
            if ($spf -in @('fail','softfail','none',$null)) { $reasons.Add("SPF did not validate.") }
            if (-not $fromDomain) { $reasons.Add("From domain could not be parsed.") }
        }

        # Final object
        $obj = [pscustomobject]@{
            Verdict     = $verdict
            Confidence  = $confidence
            Reasons     = $reasons
            VisibleFrom = $fromAddr
            Sender      = $senderAddr
            ReturnPath  = $returnPath
            Domains     = [pscustomobject]@{
                From     = $fromDomain
                MailFrom = $mailFromDomain
                DKIM     = $dkimDomains
            }
            AuthSummary = [pscustomobject]@{
                Edge = $edgeAuth
                Origin = $originAuth
                Best = [pscustomobject]@{
                    SPF   = $spf
                    DKIM  = $dkim
                    DMARC = $dmarc
                    ARC   = $arc
                }
                Alignment = [pscustomobject]@{
                    DKIM_Aligned = $dkimAligned
                    SPF_Aligned  = $spfAligned
                }
                CompAuth = $edgeAuth.CompAuth ?? $originAuth.CompAuth
            }
            Path = [pscustomobject]@{
                FirstPublicIP = $firstPublicIP
                ReceivedHops  = $receivedLines
            }
            KeyHeaders = [pscustomobject]@{
                Subject   = ($kv.Subject   -replace '^(?i)Subject:\s*','')
                MessageId = ($kv.MessageID -replace '^(?i)Message-Id:\s*','')
            }
        }

        if ($Format -eq 'Object' -or $AsObject) { return $obj }
        if ($Format -eq 'Json') { return $obj | ConvertTo-Json -Depth 6 }

        if ($Format -eq 'Markdown') {
            $md = @()
            $md += "# Mail Header Authentication Analysis"
            $md += "**Verdict:** $($obj.Verdict)"
            $md += "**Confidence:** $($obj.Confidence)"
            $md += ""

            if ($obj.Reasons.Count) {
                $md += "### Reasons"
                foreach ($r in $obj.Reasons) { $md += "- $r" }
                $md += ""
            }

            $md += "### Sender"
            $md += "- From: ``$($obj.VisibleFrom)``"
            if ($obj.Sender)     { $md += "- Sender: ``$($obj.Sender)``" }
            if ($obj.ReturnPath) { $md += "- Return-Path: ``$($obj.ReturnPath)``" }
            $md += ""

            $md += "### Domains"
            $md += "- header.from: **$($obj.Domains.From)**"
            $md += "- smtp.mailfrom: **$($obj.Domains.MailFrom)**"
            $md += "- DKIM d=: **$([string]::Join(', ',$obj.Domains.DKIM))**"
            $md += ""

            $md += "### Authentication"
            $md += "- SPF: **$($obj.AuthSummary.Best.SPF)** (aligned: $($obj.AuthSummary.Alignment.SPF_Aligned))"
            $md += "- DKIM: **$($obj.AuthSummary.Best.DKIM)** (aligned: $($obj.AuthSummary.Alignment.DKIM_Aligned))"
            $md += "- DMARC: **$($obj.AuthSummary.Best.DMARC)**"
            if ($obj.AuthSummary.Best.ARC) { $md += "- ARC: **$($obj.AuthSummary.Best.ARC)**" }
            if ($obj.AuthSummary.CompAuth) { $md += "- CompAuth: **$($obj.AuthSummary.CompAuth)**" }
            $md += ""

            $md += "### Path"
            if ($obj.Path.FirstPublicIP) { $md += "- First public IP: **$($obj.Path.FirstPublicIP)**" }
            $md += ""
            $md += "### Key Headers"
            if ($obj.KeyHeaders.Subject)   { $md += "- Subject: $($obj.KeyHeaders.Subject)" }
            if ($obj.KeyHeaders.MessageId) { $md += "- Message-Id: $($obj.KeyHeaders.MessageId)" }

            return ($md -join "`n")
        }

        # SUMMARY OUTPUT
        Write-Log OK "Mail Header Authentication Analysis"
        Write-Log Warn "Verdict: $($obj.Verdict)"
        Write-Log Info "Confidence: $($obj.Confidence)"
        Write-Log OK  "Reasons:"
        foreach ($r in $obj.Reasons) {
            Write-Log Info " - $r"
        }

        return $obj | Out-Null
    }
    catch {
        Write-Log Error ("Error: " + $_.Exception.Message)
        return $null
    }
}