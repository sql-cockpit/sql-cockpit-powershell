@{
    RootModule           = 'SqlCockpit.Portal.psm1'
    ModuleVersion        = '0.1.0'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID                 = '76c8efd2-e64d-4c6c-aad5-1ec83afe8ecd'
    Author               = 'SQL Cockpit'
    CompanyName          = 'SQL Cockpit'
    Copyright            = '(c) SQL Cockpit. MIT License.'
    Description          = 'The official PowerShell module for the SQL Cockpit portal API: your account, plan usage, API keys, tenants, team members, Agents, instances and support tickets.'
    PowerShellVersion    = '5.1'
    FormatsToProcess     = @('SqlCockpit.Portal.Format.ps1xml')
    FunctionsToExport    = @(
        'Connect-SqlCockpit'
        'Disconnect-SqlCockpit'
        'Get-SqlCockpitAccount'
        'Get-SqlCockpitUsage'
        'Get-SqlCockpitApiKey'
        'Get-SqlCockpitTenant'
        'Get-SqlCockpitTeamMember'
        'Add-SqlCockpitTeamMember'
        'Set-SqlCockpitTeamMemberRole'
        'Remove-SqlCockpitTeamMember'
        'Send-SqlCockpitTeamMemberInvite'
        'Get-SqlCockpitAgent'
        'Get-SqlCockpitInstance'
        'Get-SqlCockpitSupportTicket'
        'New-SqlCockpitSupportTicket'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('SqlCockpit', 'SQL', 'Portal', 'API', 'PSEdition_Core', 'PSEdition_Desktop', 'Windows', 'Linux', 'MacOS')
            LicenseUri   = 'https://github.com/sql-cockpit/sql-cockpit-powershell/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/sql-cockpit/sql-cockpit-powershell'
            ReleaseNotes = 'https://github.com/sql-cockpit/sql-cockpit-powershell/blob/main/CHANGELOG.md'
        }
    }
}
