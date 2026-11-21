function ConvertTo-SqlCockpitPropertyName {
    <#
    .SYNOPSIS
    snake_case to PascalCase: tenant_id -> TenantId.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $parts = foreach ($part in ($Name -split '[_\-]')) {
        if ($part.Length -gt 0) { $part.Substring(0, 1).ToUpperInvariant() + $part.Substring(1) }
    }
    $parts -join ''
}

function ConvertTo-SqlCockpitValue {
    <#
    .SYNOPSIS
    Converts a value from the API's JSON: objects get PascalCase properties, *_at fields become UTC DateTime.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value,

        [string] $Key = ''
    )

    if ($null -eq $Value) { return $null }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $properties = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $properties[(ConvertTo-SqlCockpitPropertyName -Name $property.Name)] = ConvertTo-SqlCockpitValue -Value $property.Value -Key $property.Name
        }
        return [pscustomobject] $properties
    }

    if ($Value -is [System.Array]) {
        $items = foreach ($item in $Value) { ConvertTo-SqlCockpitValue -Value $item -Key $Key }
        return , [object[]] @($items)
    }

    $isDateKey = $Key -match '_at\z' -or $Key -eq 'start' -or $Key -eq 'end'
    if ($isDateKey -and $Value -is [datetime]) { return $Value.ToUniversalTime() }
    if ($isDateKey -and $Value -is [string]) {
        $parsed = [DateTimeOffset]::MinValue
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        if ([DateTimeOffset]::TryParse($Value, $culture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref] $parsed)) {
            return $parsed.UtcDateTime
        }
    }
    $Value
}

function ConvertTo-SqlCockpitObject {
    <#
    .SYNOPSIS
    Converts one API object into a typed PowerShell object.
    .PARAMETER IdName
    What the object's id property is called, for example TenantId, so ids bind from the pipeline.
    .PARAMETER Extra
    Properties to add first, such as the TenantId of a team member.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string[]] $TypeName,

        [string] $IdName,

        [System.Collections.IDictionary] $Extra
    )

    $properties = [ordered]@{}
    if ($IdName -and $null -ne $InputObject.PSObject.Properties['id']) {
        $properties[$IdName] = $InputObject.id
    }
    if ($Extra) {
        foreach ($name in $Extra.Keys) { $properties[$name] = $Extra[$name] }
    }
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($IdName -and $property.Name -eq 'id') { continue }
        $name = ConvertTo-SqlCockpitPropertyName -Name $property.Name
        if ($properties.Contains($name)) { continue }
        $properties[$name] = ConvertTo-SqlCockpitValue -Value $property.Value -Key $property.Name
    }

    $result = [pscustomobject] $properties
    for ($index = $TypeName.Count - 1; $index -ge 0; $index--) {
        $result.PSObject.TypeNames.Insert(0, $TypeName[$index])
    }
    $result
}

function ConvertTo-SqlCockpitMember {
    <#
    .SYNOPSIS
    A team member with its TenantId, so it can be piped to Set-, Remove- and Send-SqlCockpitTeamMember*.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Member,

        [Parameter(Mandatory)]
        [string] $TenantId,

        [string] $TenantName
    )

    $extra = [ordered]@{ TenantId = $TenantId }
    if ($TenantName) { $extra.TenantName = $TenantName }
    ConvertTo-SqlCockpitObject -InputObject $Member -TypeName 'SqlCockpit.TeamMember' -IdName 'MembershipId' -Extra $extra
}

function ConvertTo-SqlCockpitTicket {
    <#
    .SYNOPSIS
    A support ticket, summary or full, with its tenant (and Agent) flattened.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Ticket,

        [switch] $Detail
    )

    $extra = [ordered]@{}
    $tenant = $Ticket.tenant
    $extra.TenantId = $null
    $extra.TenantName = $null
    if ($tenant) {
        $extra.TenantId = $tenant.id
        $extra.TenantName = $tenant.name
    }
    $typeNames = @('SqlCockpit.SupportTicket')
    if ($Detail) {
        $typeNames = @('SqlCockpit.SupportTicketDetail', 'SqlCockpit.SupportTicket')
        $agent = $Ticket.agent
        $extra.AgentId = $null
        $extra.AgentName = $null
        if ($agent) {
            $extra.AgentId = $agent.id
            $extra.AgentName = $agent.name
        }
    }
    ConvertTo-SqlCockpitObject -InputObject $Ticket -TypeName $typeNames -IdName 'TicketId' -Extra $extra
}
