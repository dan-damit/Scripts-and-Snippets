
@{
    RootModule        = 'PurviewTools.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b5e5c5f2-7a3f-4b4b-9e9e-1f6b2d4a5d11'
    Author            = 'Dan Damit'
    CompanyName       = '[redacted] - add yours here'
    Description       = 'Purview Compliance Search helpers: clone, waiters, guided purge, listings.'
    PowerShellVersion = '7.5.3'
    RequiredModules   = @('ExchangeOnlineManagement')

    FunctionsToExport = @(
        'Import-ExchangeOnlineModule',
        'Connect-SearchSession',
        'Show-RecentComplianceSearches',
        'Get-ComplianceCaseByName',
        'Show-CaseComplianceSearches',
        'New-MailboxOnlyClone',
        'Wait-ForSearchCompletion',
        'Wait-ForPurgeCompletion',
        'Submit-Purge',
        'Invoke-GuidedPurge',
        'Get-SearchDetails',
        'Test-HasNonMailboxWorkloads',
        'Get-MailboxSourcesFromSearch'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{ PSData = @{ Tags = @('Purview','Compliance','ExchangeOnline'); } }
}
