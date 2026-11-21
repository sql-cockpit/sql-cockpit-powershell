function New-SqlCockpitSupportTicket {
    <#
    .SYNOPSIS
    Opens a support ticket with the SQL Cockpit Team.

    .DESCRIPTION
    Calls POST /support-tickets. A ticket that names an Agent is raised as high priority; the
    Agent must belong to the tenant. Opening tickets is rate limited per account, and this
    request is never retried.

    .PARAMETER Subject
    A short subject, 4 to 160 characters.

    .PARAMETER Message
    What happened, 10 to 5000 characters.

    .PARAMETER TenantId
    The tenant the ticket is about (a UUID). Binds from the TenantId property of piped objects.

    .PARAMETER AgentId
    The Agent the ticket is about (a UUID). Binds from the AgentId property of piped objects,
    such as the output of Get-SqlCockpitAgent.

    .EXAMPLE
    New-SqlCockpitSupportTicket -Subject 'Slow sync' -Message 'Sync to the reporting database takes an hour since Monday.'

    Opens a ticket.

    .EXAMPLE
    New-SqlCockpitSupportTicket -Subject 'Agent offline' -Message (Get-Content .\notes.txt -Raw) -TenantId $tenantId -AgentId $agentId

    Opens a high-priority ticket about one Agent, with the message read from a file.

    .EXAMPLE
    Get-SqlCockpitAgent -Status suspended | Select-Object -First 1 | New-SqlCockpitSupportTicket -Subject 'Agent suspended' -Message 'This Agent was suspended overnight.' -WhatIf

    Shows the ticket that would be opened for a suspended Agent, without sending it.

    .INPUTS
    Objects with TenantId and AgentId properties, such as SqlCockpit.Agent.

    .OUTPUTS
    SqlCockpit.SupportTicketDetail

    .LINK
    Get-SqlCockpitSupportTicket
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('SqlCockpit.SupportTicketDetail')]
    param(
        [Parameter(Mandatory)]
        [ValidateLength(4, 160)]
        [string] $Subject,

        [Parameter(Mandatory)]
        [ValidateLength(10, 5000)]
        [string] $Message,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $TenantId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $AgentId
    )

    process {
        try {
            $body = [ordered]@{ subject = $Subject; message = $Message }
            if ($TenantId) { $body.tenant_id = Assert-SqlCockpitUuid -Value $TenantId -Name 'TenantId' }
            if ($AgentId) { $body.agent_id = Assert-SqlCockpitUuid -Value $AgentId -Name 'AgentId' }
            if ($PSCmdlet.ShouldProcess('SQL Cockpit support', "Open ticket '$Subject'")) {
                $data = Invoke-SqlCockpitRequest -Method POST -Path '/support-tickets' -Body $body
                ConvertTo-SqlCockpitTicket -Ticket $data.ticket -Detail
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
