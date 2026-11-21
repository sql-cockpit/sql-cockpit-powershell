function Send-SqlCockpitTeamMemberInvite {
    <#
    .SYNOPSIS
    Sends the set-password email again to a member who has not set a password yet.

    .DESCRIPTION
    Calls POST /tenants/{tenantId}/members/{membershipId}/resend. Works for members whose Status
    is pending_password.

    .PARAMETER TenantId
    The tenant's ID (a UUID). Binds from the TenantId property of piped objects.

    .PARAMETER MembershipId
    The membership's ID (a UUID), from Get-SqlCockpitTeamMember. Binds from piped objects.

    .PARAMETER PassThru
    Return what the portal reports: the email the message went to.

    .EXAMPLE
    Send-SqlCockpitTeamMemberInvite -TenantId $tenantId -MembershipId $membershipId

    Resends the email to one member.

    .EXAMPLE
    Get-SqlCockpitTeamMember -TenantId $tenantId | Where-Object Status -eq 'pending_password' | Send-SqlCockpitTeamMemberInvite -PassThru

    Resends the email to everyone still pending and lists who it went to.

    .INPUTS
    Objects with TenantId and MembershipId properties, such as SqlCockpit.TeamMember.

    .OUTPUTS
    None, or SqlCockpit.TeamMemberInvite with -PassThru.

    .LINK
    Add-SqlCockpitTeamMember
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType('SqlCockpit.TeamMemberInvite')]
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
            if ($PSCmdlet.ShouldProcess("membership $membership in tenant $tenant", 'Resend set-password email')) {
                $data = Invoke-SqlCockpitRequest -Method POST -Path "/tenants/$tenant/members/$membership/resend"
                Write-Verbose -Message "Sent the set-password email to $($data.email)."
                if ($PassThru) {
                    $extra = [ordered]@{ MembershipId = $membership; TenantId = $tenant }
                    ConvertTo-SqlCockpitObject -InputObject $data -TypeName 'SqlCockpit.TeamMemberInvite' -Extra $extra
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
