<#>
.SYNOPSIS
    Pulls audit log records for mailbox deletions and filters them by subject
    patterns.

.DESCRIPTION
    This script connects to Exchange Online, retrieves unified audit log records
    for mailbox deletions (soft delete, hard delete, move to deleted items)
    within a specified date range and for a specified mailbox. It then extracts
    the subject and the user who performed the deletion from the audit data,
    filters the records based on provided subject patterns, and outputs the
    results in a formatted table.

.PARAMETER <yourUPN>
    The User Principal Name (UPN) of the account to connect to Exchange Online.

.PARAMETER <insertStartDate>    
    The start date for the audit log search (e.g., "2024-01-01").

.PARAMETER <insertEndDate>
    The end date for the audit log search (e.g., "2024-01-31").

.PARAMETER <insertMailboxSMTP>
    The mailbox to search for in the audit logs (e.g., "user@domain.com").

.PARAMETER <insertSubjectPattern1>, <insertSubjectPattern2>, <insertSubjectPattern3>
    The subject patterns to filter the audit log records (e.g., "Invoice",
    "Report", "Confidential").

.EXAMPLE
    .\Pull-SharedMailboxDeletions.ps1
    
.NOTES
    Starter script for pulling mailbox deletion records from the unified audit
    log. Adjust the parameters and subject patterns as needed for your specific
    use case. Make sure to have the ExchangeOnlineManagement module installed
    and the necessary permissions to access the audit logs. For more information
    on the Search-UnifiedAuditLog cmdlet and the structure of the audit data,
    refer to the Microsoft documentation:
    https://docs.microsoft.com/en-us/powershell/module/exchange/search-unifiedauditlog
    
    Author: Dan.Damit (https://github.com/Dan-Damit)
#>

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -UserPrincipalName "<yourUPN>"

$raw = Search-UnifiedAuditLog `
    -StartDate "<insertStartDate>" `
    -EndDate "<insertEndDate>" `
    -FreeText "<insertMailboxSMTP>" `
    -Operations SoftDelete, HardDelete, MoveToDeletedItems `
    -ResultSize 500

$subjectPatterns = @("insertSubjectPattern1", "insertSubjectPattern2", "insertSubjectPattern3")

$expanded = $raw | ForEach-Object {
    $a = $_.AuditData | ConvertFrom-Json

    # Pick the first subject that exists among common locations
    $subject =
    $a.Item.Subject,
    ($a.AffectedItems | Select-Object -First 1).Subject,
    $a.Subject,
    $a.Item.SubjectTitle |
    Where-Object { $_ } |
    Select-Object -First 1

    $deletedBy =
    $_.UserId,
    $a.UserId,
    ($a.Actor | Select-Object -First 1).UserId,
    ($a.Actor | Select-Object -First 1).ID |
    Where-Object { $_ } |
    Select-Object -First 1

    [pscustomobject]@{
        TimeUtc   = $_.CreationDate
        DeletedBy = $deletedBy
        Operation = $_.Operation     # usually singular on these records
        Subject   = $subject
        Mailbox   = $a.MailboxOwnerUPN
        ClientIP  = $a.ClientIP
        RecordId  = $_.Id
    }
}

$filtered = $expanded | Where-Object {
    $sub = $_.Subject
    $sub -and ($subjectPatterns | Where-Object { $sub -match [regex]::Escape($_) }).Count -gt 0
}

$filtered | Sort-Object TimeUtc -Descending |
Format-Table TimeUtc, DeletedBy, Operation, Subject -AutoSize