function Get-SqlCockpitApiKey {
    <#
    .SYNOPSIS
    Lists your portal API keys, newest first.

    .DESCRIPTION
    Calls GET /api-keys. Each key comes with its status and last four characters (EndsWith),
    never its value.

    Creating and revoking keys needs the keys:write scope, which an API key never holds, so this
    module cannot do either. Manage keys in the portal under Settings > Developer access.

    .EXAMPLE
    Get-SqlCockpitApiKey

    Lists your keys.

    .EXAMPLE
    Get-SqlCockpitApiKey | Where-Object { $_.Status -eq 'active' -and $_.ExpiresAt -lt (Get-Date).AddDays(3) }

    Finds active keys that expire within three days.

    .INPUTS
    None.

    .OUTPUTS
    SqlCockpit.ApiKey

    .LINK
    Get-SqlCockpitAccount
    #>
    [CmdletBinding()]
    [OutputType('SqlCockpit.ApiKey')]
    param()

    try {
        $data = Invoke-SqlCockpitRequest -Method GET -Path '/api-keys'
        foreach ($key in $data.keys) {
            ConvertTo-SqlCockpitObject -InputObject $key -TypeName 'SqlCockpit.ApiKey' -IdName 'ApiKeyId'
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
