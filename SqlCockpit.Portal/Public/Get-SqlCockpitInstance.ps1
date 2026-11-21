function Get-SqlCockpitInstance {
    <#
    .SYNOPSIS
    Lists the hosted and self-hosted SQL Cockpit Server instances of your tenants.

    .DESCRIPTION
    Calls GET /instances, optionally for one tenant. Each instance shows the configuration
    revision it should run (Revision) and the one it has applied (AppliedRevision).

    .PARAMETER TenantId
    Only the instances of this tenant (a UUID). Binds from the TenantId property of piped
    objects, such as the output of Get-SqlCockpitTenant.

    .EXAMPLE
    Get-SqlCockpitInstance

    Lists every instance you can reach.

    .EXAMPLE
    Get-SqlCockpitTenant | Get-SqlCockpitInstance | Where-Object { $_.AppliedRevision -ne $_.Revision }

    Finds instances that have not applied their latest configuration.

    .INPUTS
    Objects with a TenantId property, such as SqlCockpit.Tenant.

    .OUTPUTS
    SqlCockpit.Instance

    .LINK
    Get-SqlCockpitAgent
    #>
    [CmdletBinding()]
    [OutputType('SqlCockpit.Instance')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [string] $TenantId
    )

    process {
        try {
            $query = [ordered]@{}
            if ($TenantId) { $query.tenant_id = Assert-SqlCockpitUuid -Value $TenantId -Name 'TenantId' }
            $data = Invoke-SqlCockpitRequest -Method GET -Path '/instances' -Query $query
            foreach ($instance in $data.instances) {
                ConvertTo-SqlCockpitObject -InputObject $instance -TypeName 'SqlCockpit.Instance' -IdName 'InstanceId'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
