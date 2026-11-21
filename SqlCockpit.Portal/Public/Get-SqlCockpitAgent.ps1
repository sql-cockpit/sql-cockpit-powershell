function Get-SqlCockpitAgent {
    <#
    .SYNOPSIS
    Lists the SQL Cockpit Agents paired with your tenants.

    .DESCRIPTION
    Calls GET /agents, optionally filtered by tenant and status. Each Agent comes with its
    connection and the latest command it ran.

    .PARAMETER TenantId
    Only the Agents of this tenant (a UUID). Binds from the TenantId property of piped objects,
    such as the output of Get-SqlCockpitTenant.

    .PARAMETER Status
    Only Agents in this status: pending, active, revoked or suspended.

    .EXAMPLE
    Get-SqlCockpitAgent

    Lists every Agent you can reach.

    .EXAMPLE
    Get-SqlCockpitAgent -TenantId $tenantId -Status active

    Lists the active Agents of one tenant.

    .EXAMPLE
    Get-SqlCockpitTenant | Get-SqlCockpitAgent -Status suspended

    Lists suspended Agents tenant by tenant.

    .INPUTS
    Objects with a TenantId property, such as SqlCockpit.Tenant.

    .OUTPUTS
    SqlCockpit.Agent

    .LINK
    Get-SqlCockpitInstance
    #>
    [CmdletBinding()]
    [OutputType('SqlCockpit.Agent')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [string] $TenantId,

        [ValidateSet('pending', 'active', 'revoked', 'suspended')]
        [string] $Status
    )

    process {
        try {
            $query = [ordered]@{}
            if ($TenantId) { $query.tenant_id = Assert-SqlCockpitUuid -Value $TenantId -Name 'TenantId' }
            if ($Status) { $query.status = $Status.ToLowerInvariant() }
            $data = Invoke-SqlCockpitRequest -Method GET -Path '/agents' -Query $query
            foreach ($agent in $data.agents) {
                ConvertTo-SqlCockpitObject -InputObject $agent -TypeName 'SqlCockpit.Agent' -IdName 'AgentId'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
