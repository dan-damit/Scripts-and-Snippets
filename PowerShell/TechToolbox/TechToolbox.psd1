@{
    RootModule        = 'TechToolbox.psm1'
    ModuleVersion     = '1.0.0'
    Author            = 'Dan Damit'
    Description       = 'A technician-grade toolbox for automation, diagnostics, and enterprise workflows.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('*')  # Can list explicitly later if needed
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('automation', 'networking', 'diagnostics', 'toolbox')
            ProjectUri   = 'https://github.com/dan-damit/Scripts-and-Snippets/tree/main/PowerShell/TechToolbox'
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ReleaseNotes = 'Initial release of TechToolbox.'
        }
    }
}