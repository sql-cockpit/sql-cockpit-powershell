function Remove-SqlCockpitTeamMember {
    <#
    .SYNOPSIS
    Removes a member from a tenant's team.

    .DESCRIPTION
    Calls DELETE /tenants/{tenantId}/members/{membershipId} with confirm: true. The person's SQL
    Cockpit account stays; only their membership of this tenant goes. Asks before it removes
    anyone (ConfirmImpact High); pass -Confirm:$false in scripts, or -WhatIf to see what would
    happen.

    .PARAMETER TenantId
    The tenant's ID (a UUID). Binds from the TenantId property of piped objects.

    .PARAMETER MembershipId
    The membership's ID (a UUID), from Get-SqlCockpitTeamMember. Binds from piped objects.

    .PARAMETER PassThru
    Return what the portal reports: the email removed and the tenant.

    .EXAMPLE
    Remove-SqlCockpitTeamMember -TenantId $tenantId -MembershipId $membershipId

    Removes one member, after asking you to confirm.

    .EXAMPLE
    Get-SqlCockpitTeamMember -TenantId $tenantId | Where-Object Email -like '*@contractor.example' | Remove-SqlCockpitTeamMember -WhatIf

    Shows which members would be removed, without removing anyone.

    .EXAMPLE
    Remove-SqlCockpitTeamMember -TenantId $tenantId -MembershipId $membershipId -Confirm:$false

    Removes a member from a script without a prompt.

    .INPUTS
    Objects with TenantId and MembershipId properties, such as SqlCockpit.TeamMember.

    .OUTPUTS
    None, or SqlCockpit.TeamMemberRemoval with -PassThru.

    .LINK
    Get-SqlCockpitTeamMember
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType('SqlCockpit.TeamMemberRemoval')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $TenantId,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [string] $MembershipId,

        [switch] $PassThru
    )

    process {
        try {
            $tenant = Assert-SqlCockpitUuid -Value $TenantId -Name 'TenantId'
            $membership = Assert-SqlCockpitUuid -Value $MembershipId -Name 'MembershipId'
            if ($PSCmdlet.ShouldProcess("membership $membership in tenant $tenant", 'Remove team member')) {
                $body = [ordered]@{ confirm = $true }
                $data = Invoke-SqlCockpitRequest -Method DELETE -Path "/tenants/$tenant/members/$membership" -Body $body
                Write-Verbose -Message "Removed $($data.email) from tenant $tenant."
                if ($PassThru) {
                    $extra = [ordered]@{ MembershipId = $membership; TenantId = $tenant }
                    ConvertTo-SqlCockpitObject -InputObject $data -TypeName 'SqlCockpit.TeamMemberRemoval' -Extra $extra
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
