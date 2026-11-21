function Get-SqlCockpitTenant {
    <#
    .SYNOPSIS
    Lists the tenants you own or belong to.

    .DESCRIPTION
    Calls GET /tenants. Each tenant has a TenantId, your role in it and what that role lets you
    do. Pipe tenants to Get-SqlCockpitTeamMember, Get-SqlCockpitAgent or Get-SqlCockpitInstance.

    .EXAMPLE
    Get-SqlCockpitTenant

    Lists your tenants and your role in each.

    .EXAMPLE
    Get-SqlCockpitTenant | Where-Object IsOwner | Get-SqlCockpitTeamMember

    Lists the team of every tenant you own.

    .INPUTS
    None.

    .OUTPUTS
    SqlCockpit.Tenant

    .LINK
    Get-SqlCockpitTeamMember
    #>
    [CmdletBinding()]
    [OutputType('SqlCockpit.Tenant')]
    param()

    try {
        $data = Invoke-SqlCockpitRequest -Method GET -Path '/tenants'
        foreach ($tenant in $data.tenants) {
            ConvertTo-SqlCockpitObject -InputObject $tenant -TypeName 'SqlCockpit.Tenant' -IdName 'TenantId'
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
