function Get-SqlCockpitTeamMember {
    <#
    .SYNOPSIS
    Lists the members of a tenant's team.

    .DESCRIPTION
    Calls GET /tenants/{tenantId}/members and returns one object per member, each with its
    MembershipId and TenantId, ready to pipe to Set-SqlCockpitTeamMemberRole,
    Remove-SqlCockpitTeamMember or Send-SqlCockpitTeamMemberInvite.

    The tenant owner is not a membership and is not listed; use -AsTeam to get the whole team
    (owner, members, the roles you may assign and the seats your plan includes) as one object.

    .PARAMETER TenantId
    The tenant's ID (a UUID). Binds from the TenantId property of piped objects, such as the
    output of Get-SqlCockpitTenant.

    .PARAMETER AsTeam
    Return one SqlCockpit.Team object instead of one object per member.

    .EXAMPLE
    Get-SqlCockpitTeamMember -TenantId 3f2b1c4d-0000-4000-8000-000000000000

    Lists the members of one tenant.

    .EXAMPLE
    Get-SqlCockpitTenant | Get-SqlCockpitTeamMember

    Lists the members of every tenant you can reach.

    .EXAMPLE
    Get-SqlCockpitTeamMember -TenantId $tenantId | Where-Object Status -eq 'pending_password' | Send-SqlCockpitTeamMemberInvite

    Resends the set-password email to everyone who has not set one yet.

    .EXAMPLE
    (Get-SqlCockpitTeamMember -TenantId $tenantId -AsTeam).Seats

    Shows how many seats are used and how many your plan includes.

    .INPUTS
    Objects with a TenantId property, such as SqlCockpit.Tenant.

    .OUTPUTS
    SqlCockpit.TeamMember, or SqlCockpit.Team with -AsTeam.

    .LINK
    Add-SqlCockpitTeamMember
    #>
    [CmdletBinding()]
    [OutputType('SqlCockpit.TeamMember', 'SqlCockpit.Team')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $TenantId,

        [switch] $AsTeam
    )

    process {
        try {
            $tenant = Assert-SqlCockpitUuid -Value $TenantId -Name 'TenantId'
            $data = Invoke-SqlCockpitRequest -Method GET -Path "/tenants/$tenant/members"
            $tenantName = $null
            if ($data.tenant) { $tenantName = $data.tenant.name }

            $members = foreach ($member in $data.members) {
                ConvertTo-SqlCockpitMember -Member $member -TenantId $tenant -TenantName $tenantName
            }

            if ($AsTeam) {
                $team = [pscustomobject][ordered]@{
                    TenantId        = $tenant
                    TenantName      = $tenantName
                    Owner           = ConvertTo-SqlCockpitValue -Value $data.owner
                    Members         = [object[]] @($members)
                    YouCanManage    = $data.you_can_manage
                    AssignableRoles = $data.assignable_roles
                    RoleSummaries   = ConvertTo-SqlCockpitValue -Value $data.role_summaries
                    Seats           = ConvertTo-SqlCockpitValue -Value $data.seats
                }
                $team.PSObject.TypeNames.Insert(0, 'SqlCockpit.Team')
                $team
            }
            else {
                $members
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
