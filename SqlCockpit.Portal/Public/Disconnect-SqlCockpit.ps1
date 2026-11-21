function Disconnect-SqlCockpit {
    <#
    .SYNOPSIS
    Forgets the API key stored by Connect-SqlCockpit.

    .DESCRIPTION
    Disposes the SecureString that holds the key for this session. After this, commands fall back
    to SQL_COCKPIT_API_KEY and then to the SQL Cockpit CLI's config file, if either is set.
    To revoke the key itself, delete it in the portal.

    .EXAMPLE
    Disconnect-SqlCockpit

    Forgets the key for this session.

    .INPUTS
    None.

    .OUTPUTS
    None.

    .LINK
    Connect-SqlCockpit
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if ($script:Connection) {
        $script:Connection.ApiKey.Dispose()
        $script:Connection = $null
        Write-Verbose -Message 'Disconnected. The stored API key was discarded.'
    }
    else {
        Write-Verbose -Message 'Not connected; nothing to do.'
    }
}
