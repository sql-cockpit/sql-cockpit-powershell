function Get-SqlCockpitUsage {
    <#
    .SYNOPSIS
    Gets what your plan includes this billing period and how much of it is used.

    .DESCRIPTION
    Calls GET /usage and returns one object per allowance (Agents, seats, API keys and so on),
    each with the plan name and billing period. A team member who is not a billing account gets
    no allowances; the portal's explanation is written as a warning.

    .EXAMPLE
    Get-SqlCockpitUsage

    Lists each allowance with used, limit and remaining.

    .EXAMPLE
    Get-SqlCockpitUsage | Where-Object AtLimit

    Shows only the allowances you have used up.

    .INPUTS
    None.

    .OUTPUTS
    SqlCockpit.UsageAllowance

    .LINK
    Get-SqlCockpitAccount
    #>
    [CmdletBinding()]
    [OutputType('SqlCockpit.UsageAllowance')]
    param()

    try {
        $data = Invoke-SqlCockpitRequest -Method GET -Path '/usage'
        $periodStart = $null
        $periodEnd = $null
        if ($data.period) {
            $periodStart = ConvertTo-SqlCockpitValue -Value $data.period.start -Key 'start'
            $periodEnd = ConvertTo-SqlCockpitValue -Value $data.period.end -Key 'end'
        }

        $count = 0
        foreach ($allowance in $data.allowances) {
            $count++
            $extra = [ordered]@{ Plan = $data.plan; PeriodStart = $periodStart; PeriodEnd = $periodEnd }
            ConvertTo-SqlCockpitObject -InputObject $allowance -TypeName 'SqlCockpit.UsageAllowance' -Extra $extra
        }
        if ($count -eq 0) {
            $note = 'Your plan has no allowances to show.'
            if ($data.message) { $note = [string] $data.message }
            Write-Warning -Message $note
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
