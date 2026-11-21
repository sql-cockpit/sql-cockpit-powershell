function Connect-SqlCockpit {
    <#
    .SYNOPSIS
    Connects this PowerShell session to the SQL Cockpit portal with an API key.

    .DESCRIPTION
    Stores a portal API key for the rest of the session as a SecureString inside the module. Every
    other command in SqlCockpit.Portal uses it. Nothing is written to disk.

    When you leave out -ApiKey in an interactive session, you are prompted for the key and it is
    not echoed. In a non-interactive session you must pass -ApiKey.

    Unless you use -SkipCheck, the key is checked against the portal (GET /account) before it is
    stored, and the command returns who you are connected as.

    Without Connect-SqlCockpit, commands use SQL_COCKPIT_API_KEY and SQL_COCKPIT_PORTAL_URL,
    then the active profile of the SQL Cockpit CLI's config file (~/.sqlcockpit.conf).

    Create an API key in the portal under Settings > Developer access.

    .PARAMETER ApiKey
    A portal API key, as a SecureString. Use Read-Host -AsSecureString, a secret store, or leave
    it out to be prompted. A plain string is not accepted, so the key stays out of your history.

    .PARAMETER PortalUrl
    The portal's address. Defaults to SQL_COCKPIT_PORTAL_URL, then https://portal.sql-cockpit.com.
    Must use https://; http:// is allowed only for localhost, 127.0.0.1 and [::1].
    The API base URL (ending in /api/portal/v1) is accepted too.

    .PARAMETER SkipCheck
    Store the key without calling the portal.

    .EXAMPLE
    Connect-SqlCockpit

    Prompts for the API key, checks it and stores it for this session.

    .EXAMPLE
    $key = Read-Host -Prompt 'API key' -AsSecureString
    Connect-SqlCockpit -ApiKey $key

    Connects with a key you already hold as a SecureString.

    .EXAMPLE
    Connect-SqlCockpit -ApiKey (Get-Secret -Name SqlCockpitApiKey)

    Connects with a key kept in a SecretManagement vault.

    .EXAMPLE
    Connect-SqlCockpit -ApiKey $key -PortalUrl http://localhost:8000 -SkipCheck

    Points the module at a local portal without checking the key first.

    .INPUTS
    None.

    .OUTPUTS
    SqlCockpit.Connection

    .LINK
    Disconnect-SqlCockpit

    .LINK
    https://github.com/sql-cockpit/sql-cockpit-powershell
    #>
    [CmdletBinding()]
    [OutputType('SqlCockpit.Connection')]
    param(
        [Parameter(Position = 0)]
        [securestring] $ApiKey,

        [string] $PortalUrl,

        [switch] $SkipCheck
    )

    try {
        $url = $PortalUrl
        if (-not $url) { $url = $env:SQL_COCKPIT_PORTAL_URL }
        $url = ConvertTo-SqlCockpitPortalUrl -Url $url

        if (-not $ApiKey) {
            if (-not (Test-SqlCockpitInteractive)) {
                throw (Get-SqlCockpitErrorRecord -Code 'not_connected' `
                        -Message 'No API key. Pass -ApiKey as a SecureString; this session cannot prompt for one.')
            }
            $ApiKey = Read-Host -Prompt 'SQL Cockpit API key' -AsSecureString
        }
        if ($null -eq $ApiKey -or $ApiKey.Length -lt 20 -or $ApiKey.Length -gt 200) {
            throw (Get-SqlCockpitErrorRecord -Code 'invalid_key' -Message 'The API key does not look like a SQL Cockpit portal API key.')
        }

        $key = $ApiKey.Copy()
        $key.MakeReadOnly()
        $candidate = [pscustomobject]@{
            ApiKey    = $key
            PortalUrl = $url
            Source    = 'Connect-SqlCockpit'
            Transient = $false
        }

        $account = $null
        if (-not $SkipCheck) {
            try {
                $account = Invoke-SqlCockpitRequest -Method GET -Path '/account' -Connection $candidate
            }
            catch {
                $key.Dispose()
                throw
            }
        }

        $previous = $script:Connection
        $script:Connection = $candidate
        if ($previous) { $previous.ApiKey.Dispose() }
        Write-Verbose -Message "Connected to $url."

        $connection = [pscustomobject][ordered]@{
            PortalUrl  = $url
            Name       = $null
            Email      = $null
            ApiKeyName = $null
            Scopes     = $null
            Checked    = -not $SkipCheck
        }
        if ($account) {
            $connection.Name = $account.name
            $connection.Email = $account.email
            if ($account.connected_via) {
                $connection.ApiKeyName = $account.connected_via.name
                $connection.Scopes = [string[]] @($account.connected_via.scopes)
            }
            if (-not $connection.ApiKeyName) { $connection.ApiKeyName = $account.api_key_name }
        }
        $connection.PSObject.TypeNames.Insert(0, 'SqlCockpit.Connection')
        $connection
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
