function Get-TTMessageTrace {
    [CmdletBinding()]
    param(
        [string]$MessageId,
        [datetime]$StartDate,
        [datetime]$EndDate,
        [string]$ExportFolder
    )

    # --- Connect to EXO ---
    function Connect-EXOInternal {
        try {
            if (-not (Get-ConnectionInformation)) {
                Write-Log -Level Info -Message "Connecting to Exchange Online..."
                Connect-ExchangeOnline -ShowProgress:$false
            }
        }
        catch {
            Write-Log -Level Error -Message "Failed to connect to Exchange Online: $($_.Exception.Message)"
            throw
        }
    }

    # --- Prompt for missing inputs ---
    function Get-InputsInternal {
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

        Write-Log -Level Info -Message "Searching for Message-ID: $MessageId"
        Write-Log -Level Info -Message "Time window: $($StartDate.ToString('u')) to $($EndDate.ToString('u')) (UTC)"
    }

    # --- Main trace logic ---
    function Trace-MessageInternal {
        Write-Log -Level Info -Message "Running Get-MessageTraceV2..."
        $summary = Get-MessageTraceV2 -MessageId $MessageId -StartDate $StartDate -EndDate $EndDate -ErrorAction Stop

        if (-not $summary) {
            Write-Log -Level Warn -Message "No results found. Check the date window (V2 traces have retention limits)."
            return
        }

        # Summary view
        $summaryView = $summary | Select-Object `
            Received, SenderAddress, RecipientAddress, Subject, Status, MessageTraceId

        Write-Log -Level Ok -Message "Summary results:"
        $summaryView | Format-Table -AutoSize

        # Details
        Write-Log -Level Info -Message "Enumerating per-recipient details..."
        $detailsAll = @()

        foreach ($row in $summary) {
            $mtid = $row.MessageTraceId
            $rcpt = $row.RecipientAddress
            if (-not $mtid -or -not $rcpt) { continue }

            try {
                $details = Get-MessageTraceDetailV2 -MessageTraceId $mtid -RecipientAddress $rcpt -ErrorAction Stop

                $detailsView = $details | Select-Object `
                @{n = 'Recipient'; e = { $rcpt } },
                @{n = 'MessageTraceId'; e = { $mtid } },
                Date, Event, Detail

                $detailsAll += $detailsView
            }
            catch {
                Write-Log -Level Warn -Message "Failed to get details for $rcpt / MTID $mtid $($_.Exception.Message)"
            }
        }

        if ($detailsAll.Count -gt 0) {
            Write-Log -Level Ok -Message "Details:"
            $detailsAll | Format-Table -AutoSize
        }
        else {
            Write-Log -Level Warn -Message "No detail records returned."
        }

        # Export
        if ($ExportFolder) {
            try {
                if (-not (Test-Path $ExportFolder)) {
                    New-Item -Path $ExportFolder -ItemType Directory | Out-Null
                }

                $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
                $sumPath = Join-Path $ExportFolder "MessageTraceSummary_$ts.csv"
                $detPath = Join-Path $ExportFolder "MessageTraceDetails_$ts.csv"

                $summaryView | Export-Csv -Path $sumPath -NoTypeInformation -Encoding UTF8
                if ($detailsAll.Count -gt 0) {
                    $detailsAll | Export-Csv -Path $detPath -NoTypeInformation -Encoding UTF8
                }

                Write-Log -Level Ok -Message "Export complete:"
                Write-Log -Level Info -Message "  Summary: $sumPath"
                if (Test-Path $detPath) {
                    Write-Log -Level Info -Message "  Details: $detPath"
                }
            }
            catch {
                Write-Log -Level Error -Message "Export failed: $($_.Exception.Message)"
            }
        }
    }

    # --- Main execution ---
    try {
        Connect-EXOInternal
        Get-InputsInternal
        Trace-MessageInternal
    }
    catch {
        Write-Log -Level Error -Message "Unhandled error: $($_.Exception.Message)"
    }
    finally {
        $resp = Read-Host "Disconnect from Exchange Online? (Y/N)"
        if ($resp -match '^(y|yes)$') {
            Disconnect-ExchangeOnline -Confirm:$false
            Write-Log -Level Info -Message "Disconnected from Exchange Online."
        }
    }
}