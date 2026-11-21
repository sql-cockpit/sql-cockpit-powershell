function Get-SqlCockpitAccount {
    <#
    .SYNOPSIS
    Gets your SQL Cockpit account: name, email, plan, subscription and the key in use.

    .DESCRIPTION
    Calls GET /account. The ConnectedVia property shows which credential made the call and its
    scopes. A portal API key holds portal:read, team:write and support:write.

    .EXAMPLE
    Get-SqlCockpitAccount

    Shows your account, plan and subscription.

    .EXAMPLE
    (Get-SqlCockpitAccount).Plan.Name

    Prints the name of your plan.

    .INPUTS
    None.

    .OUTPUTS
    SqlCockpit.Account

    .LINK
    Get-SqlCockpitUsage
    #>
    [CmdletBinding()]
    [OutputType('SqlCockpit.Account')]
    param()

    try {
        $data = Invoke-SqlCockpitRequest -Method GET -Path '/account'
        ConvertTo-SqlCockpitObject -InputObject $data -TypeName 'SqlCockpit.Account'
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
