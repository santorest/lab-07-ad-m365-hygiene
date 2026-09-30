@{
    RootModule           = 'HygieneToolkit.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '5d2f0c6e-7b41-4a8e-9c3d-2e6f1a9b4c70'
    Author               = 'Santiago Restrepo Sánchez'
    Copyright            = '(c) 2026 Santiago Restrepo Sánchez. MIT License.'
    Description          = 'Read-only Active Directory and Microsoft 365 hygiene checks over a snapshot, with an HTML report.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Get-HygieneAdSnapshot', 'Get-HygieneGraphSnapshot', 'New-HygieneSnapshot', 'Save-HygieneSnapshot',
        'Import-HygieneSnapshot', 'Invoke-HygieneAudit', 'ConvertTo-HygieneHtml', 'Export-HygieneFinding',
        'Get-HygieneCheck'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags       = @('ActiveDirectory', 'Microsoft365', 'EntraID', 'Security', 'Audit')
            LicenseUri = 'https://github.com/santorest/lab-07-ad-m365-hygiene/blob/main/LICENSE'
        }
    }
}
