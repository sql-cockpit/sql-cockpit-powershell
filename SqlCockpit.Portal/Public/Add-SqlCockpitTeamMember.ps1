function Add-SqlCockpitTeamMember {
    <#
    .SYNOPSIS
    Adds someone to a tenant's team.

    .DESCRIPTION
    Calls POST /tenants/{tenantId}/members. A person without a SQL Cockpit account gets an email
    to set a password; until they do, their Status is pending_password. Adding a member uses a
    seat from your plan.

    Name, Email and Role bind from piped objects too, so you can add people from a CSV file.

    .PARAMETER TenantId
    The tenant's ID (a UUID). Binds from the TenantId property of piped objects.

    .PARAMETER Name
    The person's name, 2 to 120 characters.

    .PARAMETER Email
    The person's email address.

    .PARAMETER Role
    The role to give them: admin, developer, operator or read-only.

    .EXAMPLE
    Add-SqlCockpitTeamMember -TenantId $tenantId -Name 'Ada Lovelace' -Email ada@example.com -Role developer

    Adds Ada as a developer.

    .EXAMPLE
    Import-Csv .\people.csv | Add-SqlCockpitTeamMember -TenantId $tenantId

    Adds everyone in a CSV file with Name, Email and Role columns.

    .EXAMPLE
    Add-SqlCockpitTeamMember -TenantId $tenantId -Name 'Ada Lovelace' -Email ada@example.com -Role admin -WhatIf

    Shows what would be sent without sending anything.

    .INPUTS
    Objects with TenantId, Name, Email and Role properties.

    .OUTPUTS
    SqlCockpit.TeamMember

    .LINK
    Get-SqlCockpitTeamMember
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('SqlCockpit.TeamMember')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $TenantId,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateLength(2, 120)]
        [string] $Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateLength(3, 254)]
        [string] $Email,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet('admin', 'developer', 'operator', 'read-only')]
        [string] $Role
    )

    process {
        try {
            $tenant = Assert-SqlCockpitUuid -Value $TenantId -Name 'TenantId'
            $roleName = $Role.ToLowerInvariant()
            if ($PSCmdlet.ShouldProcess("tenant $tenant", "Add $Email as $roleName")) {
                $body = [ordered]@{ name = $Name; email = $Email; role = $roleName }
                $data = Invoke-SqlCockpitRequest -Method POST -Path "/tenants/$tenant/members" -Body $body
                if ($data.message) { Write-Verbose -Message ([string] $data.message) }
                ConvertTo-SqlCockpitMember -Member $data.member -TenantId $tenant
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
