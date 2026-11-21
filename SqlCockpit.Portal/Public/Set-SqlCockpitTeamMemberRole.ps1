function Set-SqlCockpitTeamMemberRole {
    <#
    .SYNOPSIS
    Changes a team member's role.

    .DESCRIPTION
    Calls PATCH /tenants/{tenantId}/members/{membershipId} with confirm: true. The owner's role
    cannot change. Asks before it changes anything (ConfirmImpact High); pass -Confirm:$false in
    scripts, or -WhatIf to see what would happen.

    .PARAMETER TenantId
    The tenant's ID (a UUID). Binds from the TenantId property of piped objects.

    .PARAMETER MembershipId
    The membership's ID (a UUID), from Get-SqlCockpitTeamMember. Binds from piped objects.

    .PARAMETER Role
    The new role: admin, developer, operator or read-only.

    .PARAMETER PassThru
    Return the updated member.

    .EXAMPLE
    Set-SqlCockpitTeamMemberRole -TenantId $tenantId -MembershipId $membershipId -Role admin

    Makes a member an admin, after asking you to confirm.

    .EXAMPLE
    Get-SqlCockpitTeamMember -TenantId $tenantId | Where-Object Email -eq 'ada@example.com' | Set-SqlCockpitTeamMemberRole -Role operator -Confirm:$false -PassThru

    Changes Ada's role without a prompt and shows the result.

    .EXAMPLE
    Get-SqlCockpitTeamMember -TenantId $tenantId | Where-Object Role -eq 'admin' | Set-SqlCockpitTeamMemberRole -Role developer -WhatIf

    Shows which admins would become developers, without changing anything.

    .INPUTS
    Objects with TenantId and MembershipId properties, such as SqlCockpit.TeamMember.

    .OUTPUTS
    None, or SqlCockpit.TeamMember with -PassThru.

    .LINK
    Get-SqlCockpitTeamMember
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('SqlCockpit.TeamMember')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $TenantId,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [string] $MembershipId,

        [Parameter(Mandatory)]
        [ValidateSet('admin', 'developer', 'operator', 'read-only')]
        [string] $Role,

        [switch] $PassThru
    )

    process {
        try {
            $tenant = Assert-SqlCockpitUuid -Value $TenantId -Name 'TenantId'
            $membership = Assert-SqlCockpitUuid -Value $MembershipId -Name 'MembershipId'
            $roleName = $Role.ToLowerInvariant()
            if ($PSCmdlet.ShouldProcess("membership $membership in tenant $tenant", "Change role to $roleName")) {
                $body = [ordered]@{ role = $roleName; confirm = $true }
                $data = Invoke-SqlCockpitRequest -Method PATCH -Path "/tenants/$tenant/members/$membership" -Body $body
                if ($data.message) { Write-Verbose -Message ([string] $data.message) }
                if ($PassThru) { ConvertTo-SqlCockpitMember -Member $data.member -TenantId $tenant }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
