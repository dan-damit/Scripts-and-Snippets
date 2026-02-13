<#
.SYNOPSIS
Mail Header Analyzer – WPF + Core (single-file)
.DESCRIPTION
This script provides a GUI for analyzing email headers with a focus on
authentication results (SPF, DKIM, DMARC, ARC) and related indicators. It can
also be used in CLI mode to output results in various formats (summary,
markdown, JSON, or object).
.PARAMETER Path
The path to the email header text file to analyze. If not provided, the GUI will
be shown.
.PARAMETER Format
The output format for CLI mode. Valid options are 'Summary', 'Markdown', 'Json',
or 'Object'.
.EXAMPLE
Run from a console:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\AnalyzeEmailHeader.Gui.ps1"

This will analyze the specified email header file and output the results in
markdown format to the console.
.NOTES
Author: Dan.Damit (https://github.com/Dan-Damit)
#>

param(
    [string]$Path,
    [ValidateSet('Summary', 'Markdown', 'Object', 'Json')]
    [string]$Format = 'Markdown'
)

# ---- Ensure STA (WPF requirement) ----
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    # Relaunch self in STA and pass through args
    if ($PSVersionTable.PSEdition -and $PSVersionTable.PSEdition -eq 'Core') {
        $psExe = 'pwsh.exe'
    }
    else {
        # Windows PowerShell 5.1 (PSEdition='Desktop') or unknown → default to powershell.exe
        $psExe = 'powershell.exe'
    }
    
    # Re-launch ourselves in STA and pass through args as needed
    $argList = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($PSBoundParameters.ContainsKey('Path')) { $argList += @('-Path', "`"$Path`"") }
    if ($PSBoundParameters.ContainsKey('Format')) { $argList += @('-Format', "$Format") }

    Start-Process -FilePath $psExe -ArgumentList $argList | Out-Null
    return
}

# =====================
# ======= CORE ========
# =====================

function Write-Log {
    param([string]$Level, [string]$Message)
    switch ($Level.ToLower()) {
        'info' { $c = 'Gray' } 'warn' { $c = 'Yellow' } 'error' { $c = 'Red' } 'ok' { $c = 'Green' } default { $c = 'White' }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $c
}

function Get-HeaderBlock {
    param([Parameter(Mandatory)][string]$HeadersText)
    # Unfold continuation lines (leading space/tab)
    $unfolded = [regex]::Replace($HeadersText, "(`r?`n)[ `t]+", ' ')
    $unfolded = $unfolded -replace "`r?`n", "`n"
    $lines = $unfolded -split "`n"
    [pscustomobject]@{ Text = $unfolded; Lines = $lines }
}

function Get-FirstPublicIP {
    param([Parameter(Mandatory)][string[]]$ReceivedLines)
    $private = @('^10\.', '^127\.', '^169\.254\.', '^172\.(1[6-9]|2[0-9]|3[0-1])\.', '^192\.168\.',
        '^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\.')
    $isPriv = { param($ip) foreach ($p in $private) { if ($ip -match $p) { return $true } } $false }
    $ipv4 = [regex]'(?<!\d)(?:\d{1,3}\.){3}\d{1,3}(?!\d)'
    for ($i = $ReceivedLines.Count - 1; $i -ge 0; $i--) {
        $matches = $ipv4.Matches($ReceivedLines[$i])
        foreach ($m in $matches) {
            $ip = $m.Value
            if ((($ip -split '\.') | ForEach-Object { [int]$_ } | Where-Object { $_ -gt 255 })) {
                continue
            }
            if (-not (& $isPriv $ip)) { return $ip }
        }
    }
    $null
}

function Get-Domain {
    param([Parameter(Mandatory)][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $clean = $Value -replace '[<>"]', '' -replace '^\s+|\s+$', ''
    $m = [regex]::Match($clean, '[^@\s]+@(?<dom>[A-Za-z0-9.-]+\.[A-Za-z]{2,})')
    if ($m.Success -and $m.Groups['dom'].Success) { return $m.Groups['dom'].Value.ToLowerInvariant() }
    $m = [regex]::Match($clean, '(?<dom>[A-Za-z0-9.-]+\.[A-Za-z]{2,})')
    if ($m.Success -and $m.Groups['dom'].Success) { return $m.Groups['dom'].Value.ToLowerInvariant() }
    $null
}

function Format-AuthResults {
    param([Parameter(Mandatory)][object]$Lines, [string]$Label = 'edge')
    $safe = @()
    if ($null -ne $Lines) {
        $safe = if ($Lines -is [array]) { $Lines } else { @($Lines) }
    }
    $safe = $safe | Where-Object { $_ } | ForEach-Object { [string]$_ }

    $result = [ordered]@{
        Label = $Label; SPF = $null; SPF_MailFrom = $null; DKIM = $null; DKIM_Domains = @();
        DMARC = $null; DMARC_From = $null; CompAuth = $null; ARC = $null; Raw = @()
    }

    $re = @{
        spf    = [regex]'\bspf=(?<val>[a-z]+)\b'
        spf_mf = [regex]'smtp\.mailfrom=(?<val>[^;\s]+)'
        dkim   = [regex]'\bdkim=(?<val>[a-z]+)\b'
        dkim_d = [regex]'header\.d=(?<val>[^;\s]+)'
        dmarc  = [regex]'\bdmarc=(?<val>[a-z]+)\b'
        dmarcF = [regex]'header\.from=(?<val>[^;\s]+)'
        comp   = [regex]'\bcompauth=(?<val>[a-z]+)\b'
        arc    = [regex]'\barc=(?<val>[a-z]+)\b'
    }

    foreach ($line in $safe) {
        $result.Raw += $line
        if ($line -match $re.spf) { $result.SPF = $Matches.val }
        if ($line -match $re.spf_mf) { if ($Matches.val) { $result.SPF_MailFrom = $Matches.val } }
        if ($line -match $re.dkim) { $result.DKIM = $Matches.val }
        if ($line -match $re.dkim_d) { if ($Matches.val) { $result.DKIM_Domains += $Matches.val.ToLowerInvariant() } }
        if ($line -match $re.dmarc) { $result.DMARC = $Matches.val }
        if ($line -match $re.dmarcF) { if ($Matches.val) { $result.DMARC_From = $Matches.val.ToLowerInvariant() } }
        if ($line -match $re.comp) { $result.CompAuth = $Matches.val }
        if ($line -match $re.arc) { $result.ARC = $Matches.val }
    }

    $result.DKIM_Domains = $result.DKIM_Domains | Where-Object { $_ } | Select-Object -Unique
    [pscustomobject]$result
}

function Test-MailHeaderAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Summary', 'Markdown', 'Object', 'Json')][string]$Format = 'Summary',
        [switch]$AsObject
    )

    $ErrorActionPreference = 'Stop'
    if (-not (Test-Path -LiteralPath $Path)) { Write-Log Error "File not found: $Path"; return $null }
    Write-Log Info "Reading header file: $Path"

    $HeadersText = Get-Content -LiteralPath $Path -Raw
    $block = Get-HeaderBlock -HeadersText $HeadersText
    $lines = $block.Lines

    $kv = @{
        From       = ($lines | Where-Object { $_ -match '^(?i)From:' }        | Select-Object -First 1)
        Sender     = ($lines | Where-Object { $_ -match '^(?i)Sender:' }      | Select-Object -First 1)
        ReturnPath = ($lines | Where-Object { $_ -match '^(?i)Return-Path:' } | Select-Object -First 1)
        Subject    = ($lines | Where-Object { $_ -match '^(?i)Subject:' }     | Select-Object -First 1)
        MessageID  = ($lines | Where-Object { $_ -match '^(?i)Message-Id:' }  | Select-Object -First 1)
    }

    $fromAddr = $kv.From -replace '^(?i)From:\s*', ''
    $senderAddr = $kv.Sender -replace '^(?i)Sender:\s*', ''
    $returnPath = $kv.ReturnPath -replace '^(?i)Return-Path:\s*', ''

    $fromDomain = if ($fromAddr) { Get-Domain $fromAddr }
    $mailFrom = $returnPath
    $mailFromDomain = if ($mailFrom) { Get-Domain $mailFrom }

    $arEdge = @($lines | Where-Object { $_ -match '^(?i)Authentication-Results:' }            | Where-Object { $_ })
    $arOrig1 = @($lines | Where-Object { $_ -match '^(?i)Authentication-Results-Original:' }   | Where-Object { $_ })
    $arOrig2 = @($lines | Where-Object { $_ -match '^(?i)X-Original-Authentication-Results:' } | Where-Object { $_ })

    $edgeAuth = if ($arEdge.Count -gt 0) { Format-AuthResults -Lines $arEdge -Label 'edge' } else { $null }
    $originAuth = if (($arOrig1.Count + $arOrig2.Count) -gt 0) { Format-AuthResults -Lines ($arOrig1 + $arOrig2) -Label 'origin' } else { $null }

    $spf = if ($edgeAuth -and $edgeAuth.SPF) { $edgeAuth.SPF }   elseif ($originAuth) { $originAuth.SPF }   else { $null }
    $dkim = if ($edgeAuth -and $edgeAuth.DKIM) { $edgeAuth.DKIM }  elseif ($originAuth) { $originAuth.DKIM }  else { $null }
    $dmarc = if ($edgeAuth -and $edgeAuth.DMARC) { $edgeAuth.DMARC } elseif ($originAuth) { $originAuth.DMARC } else { $null }
    $arc = if ($edgeAuth -and $edgeAuth.ARC) { $edgeAuth.ARC }   elseif ($originAuth) { $originAuth.ARC }   else { $null }

    $dkimDomains = @()
    if ($edgeAuth -and $edgeAuth.DKIM_Domains) { $dkimDomains += $edgeAuth.DKIM_Domains }
    if ($originAuth -and $originAuth.DKIM_Domains) { $dkimDomains += $originAuth.DKIM_Domains }
    $dkimDomains = $dkimDomains | Where-Object { $_ } | Select-Object -Unique

    $dkimAligned = $false
    foreach ($d in $dkimDomains) {
        if ($fromDomain -and ($d -eq $fromDomain -or $d -like "*.$fromDomain")) { $dkimAligned = $true; break }
    }
    $spfAligned = $false
    if ($fromDomain -and $mailFromDomain) {
        if ($mailFromDomain -eq $fromDomain -or $mailFromDomain -like "*.$fromDomain") { $spfAligned = $true }
    }

    $receivedLines = @($lines | Where-Object { $_ -match '^(?i)Received:' })
    $firstPublicIP = if ($receivedLines) { Get-FirstPublicIP -ReceivedLines $receivedLines }

    $reasons = New-Object System.Collections.Generic.List[string]
    if ($dmarc -eq 'pass') { $verdict = 'Low - Likely Legitimate'; $confidence = 'High'; $reasons.Add('DMARC passed and aligned.') }
    elseif ($dkim -eq 'pass' -and $dkimAligned) { $verdict = 'Low - Likely Legitimate'; $confidence = 'High'; $reasons.Add('DKIM passed and aligned.') }
    elseif ($spf -eq 'pass' -and $spfAligned) { $verdict = 'Low - Likely Legitimate'; $confidence = 'High'; $reasons.Add('SPF passed and aligned.') }
    elseif ($dkim -eq 'pass' -and -not $dkimAligned) { $verdict = 'Medium - Possibly Legitimate'; $confidence = 'Medium'; $reasons.Add('DKIM passed but appears unaligned.') }
    elseif ($arc -eq 'pass' -and $dmarc -ne 'pass') { $verdict = 'Medium - Possibly Legitimate'; $confidence = 'Medium'; $reasons.Add('ARC passed but DMARC did not.') }
    else {
        $verdict = 'High - Likely Malicious'; $confidence = 'Variable'
        if ($dmarc -eq 'fail') { $reasons.Add('DMARC failed.') }
        if ($dkim -in @('fail', 'none', $null)) { $reasons.Add('DKIM did not validate.') }
        if ($spf -in @('fail', 'softfail', 'none', $null)) { $reasons.Add('SPF did not validate.') }
        if (-not $fromDomain) { $reasons.Add('From domain could not be parsed.') }
    }

    $obj = [pscustomobject]@{
        Verdict = $verdict; Confidence = $confidence; Reasons = $reasons
        VisibleFrom = $fromAddr; Sender = $senderAddr; ReturnPath = $returnPath
        Domains = [pscustomobject]@{ From = $fromDomain; MailFrom = $mailFromDomain; DKIM = $dkimDomains }
        AuthSummary = [pscustomobject]@{
            Edge = $edgeAuth; Origin = $originAuth
            Best = [pscustomobject]@{ SPF = $spf; DKIM = $dkim; DMARC = $dmarc; ARC = $arc }
            Alignment = [pscustomobject]@{ DKIM_Aligned = $dkimAligned; SPF_Aligned = $spfAligned }
            CompAuth = if ($edgeAuth -and $edgeAuth.CompAuth) { $edgeAuth.CompAuth } elseif ($originAuth) { $originAuth.CompAuth } else { $null }
        }
        Path = [pscustomobject]@{ FirstPublicIP = $firstPublicIP; ReceivedHops = $receivedLines }
        KeyHeaders = [pscustomobject]@{
            Subject   = ($kv.Subject -replace '^(?i)Subject:\s*', '')
            MessageId = ($kv.MessageID -replace '^(?i)Message-Id:\s*', '')
        }
    }

    if ($Format -eq 'Object' -or $AsObject) { return $obj }
    if ($Format -eq 'Json') { return $obj | ConvertTo-Json -Depth 6 }
    if ($Format -eq 'Markdown') {
        $md = @()
        $md += "# Mail Header Authentication Analysis"
        $md += "**Verdict:** $($obj.Verdict)"
        $md += "**Confidence:** $($obj.Confidence)"; $md += ""
        if ($obj.Reasons.Count) { $md += "### Reasons"; foreach ($r in $obj.Reasons) { $md += "- $r" }; $md += "" }
        $md += "### Sender"
        $md += "- From: ``$($obj.VisibleFrom)``"
        if ($obj.Sender) { $md += "- Sender: ``$($obj.Sender)``" }
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
        if ($obj.KeyHeaders.Subject) { $md += "- Subject: $($obj.KeyHeaders.Subject)" }
        if ($obj.KeyHeaders.MessageId) { $md += "- Message-Id: $($obj.KeyHeaders.MessageId)" }
        return ($md -join "`n")
    }

    # Summary
    Write-Log OK   "Mail Header Authentication Analysis"
    Write-Log Warn "Verdict: $($obj.Verdict)"
    Write-Log Info "Confidence: $($obj.Confidence)"
    Write-Log OK   "Reasons:"; foreach ($r in $obj.Reasons) { Write-Log Info " - $r" }
    $obj
}

# If called with -Path, run CLI and exit (no GUI)
if ($PSBoundParameters.ContainsKey('Path')) {
    Test-MailHeaderAuth -Path $Path -Format $Format | Out-Host
    return
}

# =====================
# ======= GUI =========
# =====================

# Load WPF assemblies (works in WinPS 5.1; in PS7 requires WindowsDesktop runtime)
Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml | Out-Null

# XAML
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Mail Header Analyzer" Height="600" Width="900" WindowStartupLocation="CenterScreen">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>

    <TextBox x:Name="PathBox" Grid.Row="0" Grid.Column="0" Height="30" Margin="0,0,8,8" />
    <Button x:Name="BrowseButton" Grid.Row="0" Grid.Column="1" Content="Browse..." Width="110" Height="30" Margin="0,0,0,8" />

    <StackPanel Grid.Row="1" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="0,0,0,8">
      <TextBlock Text="Output format:" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <ComboBox x:Name="FormatCombo" Width="160" Height="25">
        <ComboBoxItem Content="Summary" IsSelected="True"/>
        <ComboBoxItem Content="Markdown"/>
        <ComboBoxItem Content="Json"/>
        <ComboBoxItem Content="Object"/>
      </ComboBox>
      <Button x:Name="AnalyzeButton" Content="Analyze" Width="110" Height="25" Margin="12,0,0,0"/>
      <TextBlock x:Name="StatusText" Foreground="Gray" Margin="16,4,0,0" VerticalAlignment="Center"/>
    </StackPanel>

    <Grid Grid.Row="2" Grid.ColumnSpan="2">
      <TextBox x:Name="OutputBox"
               FontFamily="Consolas"
               FontSize="12"
               AcceptsReturn="True"
               AcceptsTab="True"
               TextWrapping="NoWrap"
               VerticalScrollBarVisibility="Auto"
               HorizontalScrollBarVisibility="Auto"/>
    </Grid>

    <StackPanel Grid.Row="3" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,0">
      <Button x:Name="CopyButton" Content="Copy" Width="100" Height="30" Margin="0,0,8,0"/>
      <Button x:Name="SaveButton" Content="Save..." Width="100" Height="30"/>
    </StackPanel>
  </Grid>
</Window>
"@

# Parse XAML
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$PathBox = $window.FindName('PathBox')
$BrowseButton = $window.FindName('BrowseButton')
$FormatCombo = $window.FindName('FormatCombo')
$AnalyzeButton = $window.FindName('AnalyzeButton')
$StatusText = $window.FindName('StatusText')
$OutputBox = $window.FindName('OutputBox')
$CopyButton = $window.FindName('CopyButton')
$SaveButton = $window.FindName('SaveButton')

function Get-SelectedFormat { $FormatCombo.SelectedItem.Content.ToString() }

function Format-AnalyzerObjectText {
    param([Parameter(Mandatory)][psobject]$Obj)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("Mail Header Authentication Analysis")
    [void]$sb.AppendLine("-----------------------------------")
    [void]$sb.AppendLine("Verdict:    $($Obj.Verdict)")
    [void]$sb.AppendLine("Confidence: $($Obj.Confidence)")
    if ($Obj.Reasons -and $Obj.Reasons.Count) { [void]$sb.AppendLine("Reasons:"); foreach ($r in $Obj.Reasons) { [void]$sb.AppendLine(" - $r") } }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Sender")
    [void]$sb.AppendLine(" From:        $($Obj.VisibleFrom)")
    if ($Obj.Sender) { [void]$sb.AppendLine(" Sender:      $($Obj.Sender)") }
    if ($Obj.ReturnPath) { [void]$sb.AppendLine(" Return-Path: $($Obj.ReturnPath)") }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Domains")
    [void]$sb.AppendLine(" header.from:   $($Obj.Domains.From)")
    [void]$sb.AppendLine(" smtp.mailfrom: $($Obj.Domains.MailFrom)")
    if ($Obj.Domains.DKIM) { [void]$sb.AppendLine(" dkim d=:       $([string]::Join(', ',$Obj.Domains.DKIM))") }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Authentication")
    [void]$sb.AppendLine(" SPF:   $($Obj.AuthSummary.Best.SPF)   (aligned: $($Obj.AuthSummary.Alignment.SPF_Aligned))")
    [void]$sb.AppendLine(" DKIM:  $($Obj.AuthSummary.Best.DKIM)  (aligned: $($Obj.AuthSummary.Alignment.DKIM_Aligned))")
    [void]$sb.AppendLine(" DMARC: $($Obj.AuthSummary.Best.DMARC)")
    if ($Obj.AuthSummary.Best.ARC) { [void]$sb.AppendLine(" ARC:   $($Obj.AuthSummary.Best.ARC)") }
    if ($Obj.AuthSummary.CompAuth) { [void]$sb.AppendLine(" CompAuth: $($Obj.AuthSummary.CompAuth)") }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Path")
    if ($Obj.Path.FirstPublicIP) { [void]$sb.AppendLine(" First public IP: $($Obj.Path.FirstPublicIP)") }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Key Headers")
    if ($Obj.KeyHeaders.Subject) { [void]$sb.AppendLine(" Subject:   $($Obj.KeyHeaders.Subject)") }
    if ($Obj.KeyHeaders.MessageId) { [void]$sb.AppendLine(" Message-Id: $($Obj.KeyHeaders.MessageId)") }
    $sb.ToString()
}

# Events
$BrowseButton.Add_Click({
        $ofd = New-Object Microsoft.Win32.OpenFileDialog
        $ofd.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        if ($ofd.ShowDialog()) {
            $PathBox.Text = $ofd.FileName
            $OutputBox.Text = ""
            $StatusText.Text = ""
        }
    })

$AnalyzeButton.Add_Click({
        try {
            $file = $PathBox.Text
            if (-not (Test-Path -LiteralPath $file)) { $StatusText.Text = "File not found."; return }
            $AnalyzeButton.IsEnabled = $false
            $StatusText.Text = "Analyzing..."
            $fmt = Get-SelectedFormat

            switch ($fmt) {
                'Markdown' { $OutputBox.Text = [string](Test-MailHeaderAuth -Path $file -Format Markdown) }
                'Json' { $OutputBox.Text = [string](Test-MailHeaderAuth -Path $file -Format Json) }
                'Object' { $OutputBox.Text = (Format-AnalyzerObjectText (Test-MailHeaderAuth -Path $file -Format Object)) }
                default { $OutputBox.Text = (Format-AnalyzerObjectText (Test-MailHeaderAuth -Path $file -Format Object)) }
            }
            $StatusText.Text = "Done."
        }
        catch {
            $StatusText.Text = "Error: $($_.Exception.Message)"
        }
        finally {
            $AnalyzeButton.IsEnabled = $true
        }
    })

$CopyButton.Add_Click({
        if ($OutputBox.Text) { [Windows.Clipboard]::SetText($OutputBox.Text); $StatusText.Text = "Copied to clipboard." }
    })

$SaveButton.Add_Click({
        if (-not $OutputBox.Text) { return }
        $sfd = New-Object Microsoft.Win32.SaveFileDialog
        $sfd.Filter = "Text file (*.txt)|*.txt|Markdown (*.md)|*.md|JSON (*.json)|*.json|All files (*.*)|*.*"
        $sfd.FileName = "MailHeaderAnalysis"
        if ($sfd.ShowDialog()) {
            [IO.File]::WriteAllText($sfd.FileName, $OutputBox.Text)
            $StatusText.Text = "Saved: $($sfd.FileName)"
        }
    })

# Show GUI
$window.ShowDialog() | Out-Null

# SIG # Begin signature block
# MIIfAgYJKoZIhvcNAQcCoIIe8zCCHu8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDJgslMllo+7p08
# pNmxRRpB+PQDOkwL3phW2pksfV2dlKCCGEowggUMMIIC9KADAgECAhAR+U4xG7FH
# qkyqS9NIt7l5MA0GCSqGSIb3DQEBCwUAMB4xHDAaBgNVBAMME1ZBRFRFSyBDb2Rl
# IFNpZ25pbmcwHhcNMjUxMjE5MTk1NDIxWhcNMjYxMjE5MjAwNDIxWjAeMRwwGgYD
# VQQDDBNWQURURUsgQ29kZSBTaWduaW5nMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEA3pzzZIUEY92GDldMWuzvbLeivHOuMupgpwbezoG5v90KeuN03S5d
# nM/eom/PcIz08+fGZF04ueuCS6b48q1qFnylwg/C/TkcVRo0WFcKoFGT8yGxdfXi
# caHtapZfbSRh73r7qR7w0CioVveNBVgfMsTgE0WKcuwxemvIe/ptmkfzwAiw/IAC
# Ib0E0BjiX4PySbwWy/QKy/qMXYY19xpRItVTKNBtXzADUtzPzUcFqJU83vM2gZFs
# Or0MhPvM7xEVkOWZFBAWAubbMCJ3rmwyVv9keVDJChhCeLSz2XR11VGDOEA2OO90
# Y30WfY9aOI2sCfQcKMeJ9ypkHl0xORdhUwZ3Wz48d3yJDXGkduPm2vl05RvnA4T6
# 29HVZTmMdvP2475/8nLxCte9IB7TobAOGl6P1NuwplAMKM8qyZh62Br23vcx1fXZ
# TJlKCxBFx1nTa6VlIJk+UbM4ZPm954peB/fIqEacm8LkZ0cPwmLE5ckW7hfK4Trs
# o+RaudU1sKeA+FvpOWgsPccVRWcEYyGkwbyTB3xrIBXA+YckbANZ0XL7fv7x29hn
# gXbZipGu3DnTISiFB43V4MhNDKZYfbWdxze0SwLe8KzIaKnwlwRgvXDMwXgk99Mi
# EbYa3DvA/5ZWikLW9PxBFD7Vdr8ZiG/tRC9I2Y6fnb+PVoZKc/2xsW0CAwEAAaNG
# MEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQW
# BBRfYLVE8caSc990rnrIHUjoB7X/KjANBgkqhkiG9w0BAQsFAAOCAgEAiGB2Wmk3
# QBtd1LcynmxHzmu+X4Y5DIpMMNC2ahsqZtPUVcGqmb5IFbVuAdQphL6PSrDjaAR8
# 1S8uTfUnMa119LmIb7di7TlH2F5K3530h5x8JMj5EErl0xmZyJtSg7BTiBA/UrMz
# 6WCf8wWIG2/4NbV6aAyFwIojfAcKoO8ng44Dal/oLGzLO3FDE5AWhcda/FbqVjSJ
# 1zMfiW8odd4LgbmoyEI024KkwOkkPyJQ2Ugn6HMqlFLazAmBBpyS7wxdaAGrl18n
# 6bS7QuAwCd9hitdMMitG8YyWL6tKeRSbuTP5E+ASbu0Ga8/fxRO5ZSQhO6/5ro1j
# PGe1/Kr49Uyuf9VSCZdNIZAyjjeVAoxmV0IfxQLKz6VOG0kGDYkFGskvllIpQbQg
# WLuPLJxoskJsoJllk7MjZJwrpr08+3FQnLkRuisjDOc3l4VxFUsUe4fnJhMUONXT
# Sk7vdspgxirNbLmXU4yYWdsizz3nMUR0zebUW29A+HYme16hzrMPOeyoQjy4I5XX
# 3wXAFdworfPEr/ozDFrdXKgbLwZopymKbBwv6wtT7+1zVhJXr+jGVQ1TWr6R+8ea
# tIOFnY7HqGaxe5XB7HzOwJKdj+bpHAfXft1vUoiKr16VajLigcYCG8MdwC3sngO3
# JDyv2V+YMfsYBmItMGBwvizlQ6557NbK95EwggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwgga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqG
# SIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRy
# dXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYg
# MjAyNSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphB
# cr48RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6p
# vF4uGjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHe
# HYNnQxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEd
# gkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjU
# jsZvkgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bR
# VFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeS
# LsJygoLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIV
# NSaz7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL
# 6s36czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2Zd
# SoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFU
# eEY0qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/
# BAgwBgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0j
# BBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0
# cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8E
# PDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEw
# DQYJKoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/
# T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQ
# E7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9r
# EVKChHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y
# 1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gx
# dEkMx1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3t
# y9qIijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcy
# tL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEB
# YTptMSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud
# /v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiS
# uEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZP
# ubdcMIIG7TCCBNWgAwIBAgIQCoDvGEuN8QWC0cR2p5V0aDANBgkqhkiG9w0BAQsF
# ADBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNV
# BAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hB
# MjU2IDIwMjUgQ0ExMB4XDTI1MDYwNDAwMDAwMFoXDTM2MDkwMzIzNTk1OVowYzEL
# MAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJE
# aWdpQ2VydCBTSEEyNTYgUlNBNDA5NiBUaW1lc3RhbXAgUmVzcG9uZGVyIDIwMjUg
# MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANBGrC0Sxp7Q6q5gVrMr
# V7pvUf+GcAoB38o3zBlCMGMyqJnfFNZx+wvA69HFTBdwbHwBSOeLpvPnZ8ZN+vo8
# dE2/pPvOx/Vj8TchTySA2R4QKpVD7dvNZh6wW2R6kSu9RJt/4QhguSssp3qome7M
# rxVyfQO9sMx6ZAWjFDYOzDi8SOhPUWlLnh00Cll8pjrUcCV3K3E0zz09ldQ//nBZ
# ZREr4h/GI6Dxb2UoyrN0ijtUDVHRXdmncOOMA3CoB/iUSROUINDT98oksouTMYFO
# nHoRh6+86Ltc5zjPKHW5KqCvpSduSwhwUmotuQhcg9tw2YD3w6ySSSu+3qU8DD+n
# igNJFmt6LAHvH3KSuNLoZLc1Hf2JNMVL4Q1OpbybpMe46YceNA0LfNsnqcnpJeIt
# K/DhKbPxTTuGoX7wJNdoRORVbPR1VVnDuSeHVZlc4seAO+6d2sC26/PQPdP51ho1
# zBp+xUIZkpSFA8vWdoUoHLWnqWU3dCCyFG1roSrgHjSHlq8xymLnjCbSLZ49kPmk
# 8iyyizNDIXj//cOgrY7rlRyTlaCCfw7aSUROwnu7zER6EaJ+AliL7ojTdS5PWPsW
# eupWs7NpChUk555K096V1hE0yZIXe+giAwW00aHzrDchIc2bQhpp0IoKRR7YufAk
# prxMiXAJQ1XCmnCfgPf8+3mnAgMBAAGjggGVMIIBkTAMBgNVHRMBAf8EAjAAMB0G
# A1UdDgQWBBTkO/zyMe39/dfzkXFjGVBDz2GM6DAfBgNVHSMEGDAWgBTvb1NK6eQG
# fHrK4pBW9i/USezLTjAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYB
# BQUHAwgwgZUGCCsGAQUFBwEBBIGIMIGFMCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wXQYIKwYBBQUHMAKGUWh0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEy
# NTYyMDI1Q0ExLmNydDBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hB
# MjU2MjAyNUNBMS5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcB
# MA0GCSqGSIb3DQEBCwUAA4ICAQBlKq3xHCcEua5gQezRCESeY0ByIfjk9iJP2zWL
# pQq1b4URGnwWBdEZD9gBq9fNaNmFj6Eh8/YmRDfxT7C0k8FUFqNh+tshgb4O6Lgj
# g8K8elC4+oWCqnU/ML9lFfim8/9yJmZSe2F8AQ/UdKFOtj7YMTmqPO9mzskgiC3Q
# YIUP2S3HQvHG1FDu+WUqW4daIqToXFE/JQ/EABgfZXLWU0ziTN6R3ygQBHMUBaB5
# bdrPbF6MRYs03h4obEMnxYOX8VBRKe1uNnzQVTeLni2nHkX/QqvXnNb+YkDFkxUG
# tMTaiLR9wjxUxu2hECZpqyU1d0IbX6Wq8/gVutDojBIFeRlqAcuEVT0cKsb+zJNE
# suEB7O7/cuvTQasnM9AWcIQfVjnzrvwiCZ85EE8LUkqRhoS3Y50OHgaY7T/lwd6U
# Arb+BOVAkg2oOvol/DJgddJ35XTxfUlQ+8Hggt8l2Yv7roancJIFcbojBcxlRcGG
# 0LIhp6GvReQGgMgYxQbV1S3CrWqZzBt1R9xJgKf47CdxVRd/ndUlQ05oxYy2zRWV
# FjF7mcr4C34Mj3ocCVccAvlKV9jEnstrniLvUxxVZE/rptb7IRE2lskKPIJgbaP5
# t2nGj/ULLi49xTcBZU8atufk+EMF/cWuiC7POGT75qaL6vdCvHlshtjdNXOCIUjs
# arfNZzGCBg4wggYKAgEBMDIwHjEcMBoGA1UEAwwTVkFEVEVLIENvZGUgU2lnbmlu
# ZwIQEflOMRuxR6pMqkvTSLe5eTANBglghkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3
# AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDb+S98Xz+E
# OpcEcF+rYF+aQ2hMXddEce7+HR0fIZ4psDANBgkqhkiG9w0BAQEFAASCAgC8m61K
# YY1KV9ru3sbZCCKqxFPlcw0PkE56dLDaXeLfjd+sI+HE+UdgS00HR9u7tZfSolvv
# zCe3ObpMoBxFnTnMaH1w2LP0MQWGcrV90IPyqG9QN3h0AQ+REPgkQrI4IB5hXStn
# aLmay5nBb1O/c0QyLPDkpCLR0qRw3SC6eWAZCE7JGxzqrMvSBSCHSG/X6NEj8h3C
# f/NDBWZvT0x68ncC6kI+r7eM8F4bwi0lCkjVRB1bDWsRURzG8BMitWL67+8Ehxqe
# FyBUgxYrwhXBrcmbeoXQXh9vYwfh1L4m1zdEZc/o+Mrfuxj03aNDUPHlbnDxP7zp
# rKo7FqQw6DPL0AVr8EQRCBA5IaE1GUQ+zTs8b3LKCCp7XzkCYUe4sExU8WHXNb+S
# K+5CsW3QzE2xm6TIItJGPdzzJHZugXU/mIu+hNFAOCRXG3ZSBoqRP62NE44N27p+
# uKhE3IJxECSdIhFmV6ppVU8VH6DxpnpiMR3hxtcZUBuUZEZWaK+xMjCBvuO73uL9
# QbcVRsUuXvU4MB1Z4OJ7BMMQKQ4Oh3yrg3CXDEjXiDe17YpwH4IJmdDSnE006ZtV
# 2jAtCWFQnxPcXO2t5rcuO+VWyhDZBMNxPEPVGC/NS10vESpeFkWd1KQiKvTUgSy0
# I6PFsKRbXPdDTc9tmf+dXyaQRzBu+bUAHbzoEaGCAyYwggMiBgkqhkiG9w0BCQYx
# ggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcg
# UlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZI
# AWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJ
# BTEPFw0yNjAyMTMyMDI2NDVaMC8GCSqGSIb3DQEJBDEiBCBIY2VgykPbyPlFmWyL
# R5ojQYI1LDUnHaG/xmKHGQDL2DANBgkqhkiG9w0BAQEFAASCAgBhummApTVNLKds
# eQ/XxSEk9NnZp5FrHlwTpLBdCtdHT2Yyv6hVANkoCuwmsoWG2dDsJ5Flnu7HtQTa
# iYd2GNwUd5CYjyLpeMrE4WcI/Aq4Ufi90gBQOl/GsK0KSeRwtw8VlcmUUwaQT9QQ
# qtAag9P8R6IalVYhPG+Bpq1DE7mfkfcDDQrha5+tPVgbWinBt44e6i1rJbo6D5ex
# FVk486eRzSgwjtiJrK1Vka5M+fSgfpzr26ghMW4cqhR7Zgo/xTuOqjtVqFBX9kNc
# 359W+RrWfSH7y8y6ugRkv+mn5fwOmzj374wZqUFI72TzVFGf7NxOiVc7eSyP8Wba
# EMJyfeAfHpQPo8urUn+ziQ20cvUFuvbaB94h0xUF+zFxAQrLl5/dRb3bCauK06IH
# lrjMuQSYA5TMiqH51raKwPQFyeTedAMLfe+qLOBg6wBymrPDsBkjAf5U9tL2qAJA
# kZmmb0qZTm7CD0xACvMMCliQvMdsmEFw1AAa4XCM6QKWTMbu7AB9WDfA+irbnQ6g
# 6JgZt7i2xPAE9c/ppAIffa+KWQ90ECrnDLRfSob3F6L7LUYly2Fyht5NxnE7voez
# dSm56vb4iEqDDO8UNlmq6Q5TJGN15O1P7e3mCDacT3TxT6sP57+bPBZeWzA+FhDv
# Ed1jAcL8+2nrz4j4tgWKYOUFtHVjaw==
# SIG # End signature block
