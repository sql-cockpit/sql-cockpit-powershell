function Get-SqlCockpitSupportTicket {
    <#
    .SYNOPSIS
    Lists your support tickets, or gets one ticket with its replies.

    .DESCRIPTION
    Without -TicketId, calls GET /support-tickets and lists your tickets, newest first.
    With -TicketId, calls GET /support-tickets/{ticketId} and returns the ticket with its
    message, the SQL Cockpit Team's response and every reply.

    .PARAMETER TicketId
    The ticket's ID (a UUID). Binds from the TicketId property of piped objects, so you can pipe
    the list into this command to get each ticket in full.

    .PARAMETER Status
    Only tickets in this status: open, pending, sent, waiting_on_customer, resolved or closed.

    .EXAMPLE
    Get-SqlCockpitSupportTicket

    Lists your tickets.

    .EXAMPLE
    Get-SqlCockpitSupportTicket -Status waiting_on_customer

    Lists the tickets waiting on you.

    .EXAMPLE
    Get-SqlCockpitSupportTicket -TicketId $ticketId | Select-Object -ExpandProperty Replies

    Shows the replies on one ticket.

    .EXAMPLE
    Get-SqlCockpitSupportTicket -Status waiting_on_customer | Get-SqlCockpitSupportTicket

    Gets every ticket waiting on you in full.

    .INPUTS
    Objects with a TicketId property, such as SqlCockpit.SupportTicket.

    .OUTPUTS
    SqlCockpit.SupportTicket, or SqlCockpit.SupportTicketDetail with -TicketId.

    .LINK
    New-SqlCockpitSupportTicket
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType('SqlCockpit.SupportTicket', 'SqlCockpit.SupportTicketDetail')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [string] $TicketId,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('open', 'pending', 'sent', 'waiting_on_customer', 'resolved', 'closed')]
        [string] $Status
    )

    process {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $ticket = Assert-SqlCockpitUuid -Value $TicketId -Name 'TicketId'
                $data = Invoke-SqlCockpitRequest -Method GET -Path "/support-tickets/$ticket"
                ConvertTo-SqlCockpitTicket -Ticket $data.ticket -Detail
            }
            else {
                $query = [ordered]@{}
                if ($Status) { $query.status = $Status.ToLowerInvariant() }
                $data = Invoke-SqlCockpitRequest -Method GET -Path '/support-tickets' -Query $query
                foreach ($item in $data.tickets) {
                    ConvertTo-SqlCockpitTicket -Ticket $item
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
