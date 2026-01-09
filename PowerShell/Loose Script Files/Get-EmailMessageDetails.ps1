<#
    Trace a message in Exchange Online by RFC822 Message-ID and date range.
    Author: Dan.Damit (https://github.com/Dan-Damit)   
    Date: 2026-01-08
    Version: 1.0
    
    Details:
    Prompts for Message-ID (from the email header) and start/end date.
    Retrieves summary results with Get-MessageTraceV2, including MessageTraceId.
    Enumerates per-recipient details with Get-MessageTraceDetailV2.
    Displays custom outputs and can export to CSV.    
    Requires: Exchange Online PowerShell (EXO V3.9.0 as of 2026-01-08) and appropriate permissions.

    References:
    - New Message Trace GA and V2 cmdlets: https://techcommunity.microsoft.com/blog/exchange/announcing-general-availability-ga-of-the-new-message-trace-in-exchange-online/4420243
    - Message trace in the EAC: https://learn.microsoft.com/en-us/exchange/monitoring/trace-an-email-message/message-trace-modern-eac
#>

[CmdletBinding()]
param(
    # pre-supply the Message-ID (RFC822) so it can run non-interactively.
    [string]$MessageId,
    # pre-supply StartDate/EndDate. If omitted, there will be a prompt.
    [datetime]$StartDate,
    [datetime]$EndDate,
    [string]$ExportFolder
)

function Connect-EXO {
    try {
        # If not connected, Connect-ExchangeOnline will prompt (modern EXO module).
        if (-not (Get-ConnectionInformation)) {
            Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
            Connect-ExchangeOnline -ShowProgress:$false
        }
    }
    catch {
        throw "Failed to connect to Exchange Online. $_"
    }
}

function Get-Inputs {
    if (-not $MessageId) {
        $MessageId = Read-Host "Enter RFC822 Message-ID (from message header)"
    }
    if (-not $StartDate) {
        $StartDate = Read-Host "Enter Start Date (e.g., 01/07/2026 08:00)" | Get-Date
    }
    if (-not $EndDate) {
        $EndDate = Read-Host "Enter End Date   (e.g., 01/09/2026 17:00)" | Get-Date
    }
    if (-not $ExportFolder) {
        $ExportFolder = Read-Host "Optional export folder path (or press Enter to skip export)"
        if ([string]::IsNullOrWhiteSpace($ExportFolder)) { $ExportFolder = $null }
    }

    Write-Host "`nSearching for Message-ID:" -NoNewline
    Write-Host " $MessageId" -ForegroundColor Yellow
    Write-Host "Time window: $($StartDate.ToString('u')) to $($EndDate.ToString('u')) (UTC)" -ForegroundColor Yellow
}

function Trace-Message {
    Write-Host "`nRunning Get-MessageTraceV2..." -ForegroundColor Cyan
    $summary = Get-MessageTraceV2 -MessageId $MessageId -StartDate $StartDate -EndDate $EndDate -ErrorAction Stop

    if (-not $summary) {
        Write-Warning "No results found. Check the date window (remember: V2 traces have retention limits)."
        return
    }

    # Show a clean summary including MessageTraceId
    $summaryView = $summary | Select-Object `
        Received, SenderAddress, RecipientAddress, Subject, Status, MessageTraceId

    Write-Host "`nSummary results:" -ForegroundColor Green
    $summaryView | Format-Table -AutoSize

    # Drill into per-recipient details
    Write-Host "`nEnumerating per-recipient details..." -ForegroundColor Cyan
    $detailsAll = @()
    foreach ($row in $summary) {
        $mtid = $row.MessageTraceId
        $rcpt = $row.RecipientAddress
        if (-not $mtid -or -not $rcpt) { continue }

        try {
            $details = Get-MessageTraceDetailV2 -MessageTraceId $mtid -RecipientAddress $rcpt -ErrorAction Stop
            # Normalize output for report
            $detailsView = $details | Select-Object `
            @{n = 'Recipient'; e = { $rcpt } },
            @{n = 'MessageTraceId'; e = { $mtid } },
            Date, Event, Detail
            $detailsAll += $detailsView
        }
        catch {
            Write-Warning "Failed to get details for recipient $rcpt / MTID $mtid. $_"
        }
    }

    if ($detailsAll.Count -gt 0) {
        Write-Host "`nDetails:" -ForegroundColor Green
        $detailsAll | Format-Table -AutoSize
    }
    else {
        Write-Warning "No detail records returned."
    }

    # Optional export
    if ($ExportFolder) {
        try {
            if (-not (Test-Path -Path $ExportFolder)) {
                New-Item -Path $ExportFolder -ItemType Directory | Out-Null
            }

            $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
            $sumPath = Join-Path $ExportFolder "MessageTraceSummary_$ts.csv"
            $detPath = Join-Path $ExportFolder "MessageTraceDetails_$ts.csv"

            $summaryView | Export-Csv -Path $sumPath -NoTypeInformation -Encoding UTF8
            if ($detailsAll.Count -gt 0) {
                $detailsAll | Export-Csv -Path $detPath -NoTypeInformation -Encoding UTF8
            }

            Write-Host "`nExport complete:" -ForegroundColor Cyan
            Write-Host "  Summary: $sumPath" -ForegroundColor Yellow
            if (Test-Path $detPath) {
                Write-Host "  Details: $detPath" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Warning "Export failed: $_"
        }
    }
}

# Main
try {
    Connect-EXO
    Get-Inputs
    Trace-Message
}
catch {
    Write-Error $_
}
finally {
    # Optional disconnect prompt:
    $resp = Read-Host "`nDisconnect from Exchange Online? (Y/N)"
    if ($resp -match '^(y|yes)$') {
        Disconnect-ExchangeOnline -Confirm:$false
        Write-Host "Disconnected." -ForegroundColor Gray
    }
}