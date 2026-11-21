function ConvertTo-SqlCockpitPortalUrl {
    <#
    .SYNOPSIS
    Checks and normalises a portal URL: https only (http for localhost, 127.0.0.1 and [::1]),
    no credentials, query or fragment. Accepts the portal origin or the full API base URL.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) { $Url = $script:DefaultPortalUrl }
    $uri = $null
    if (-not [uri]::TryCreate($Url.Trim(), [UriKind]::Absolute, [ref] $uri)) {
        throw (Get-SqlCockpitErrorRecord -Message 'The portal URL is not a valid URL.' -Code 'invalid_config')
    }
    if ($uri.UserInfo -or $uri.Query -or $uri.Fragment) {
        throw (Get-SqlCockpitErrorRecord -Message 'The portal URL must not contain credentials, a query string or a fragment.' -Code 'invalid_config')
    }
    $loopback = @('localhost', '127.0.0.1', '[::1]') -contains $uri.Host.ToLowerInvariant()
    $isHttps = $uri.Scheme -eq 'https'
    $isLoopbackHttp = $uri.Scheme -eq 'http' -and $loopback
    if (-not ($isHttps -or $isLoopbackHttp)) {
        throw (Get-SqlCockpitErrorRecord -Message 'The portal URL must use https:// (http:// is only allowed for localhost).' -Code 'invalid_config')
    }

    $text = $uri.GetLeftPart([UriPartial]::Path).TrimEnd('/')
    if ($text.ToLowerInvariant().EndsWith($script:ApiPrefix)) {
        $text = $text.Substring(0, $text.Length - $script:ApiPrefix.Length).TrimEnd('/')
    }
    $text
}

function Get-SqlCockpitConfigPath {
    <#
    .SYNOPSIS
    The SQL Cockpit CLI's config file: ~/.sqlcockpit.conf (%USERPROFILE%\.sqlcockpit.conf on Windows).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $homeDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if ([string]::IsNullOrEmpty($homeDirectory)) { $homeDirectory = $HOME }
    Join-Path -Path $homeDirectory -ChildPath '.sqlcockpit.conf'
}

function Read-SqlCockpitConfigFile {
    <#
    .SYNOPSIS
    Reads the CLI's INI config file. Read-only: the module never writes it.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $config = @{ Default = @{}; Profiles = @{} }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $config }

    $section = $null
    foreach ($raw in [System.IO.File]::ReadAllLines($Path)) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
        if ($line -match '^\[\s*(.+?)\s*\]$') {
            $name = $Matches[1]
            if ($name -ceq 'default') {
                $section = $config.Default
            }
            elseif ($name -match '^profile\s+(.+)$') {
                $profileName = $Matches[1].Trim()
                if (-not $config.Profiles.ContainsKey($profileName)) { $config.Profiles[$profileName] = @{} }
                $section = $config.Profiles[$profileName]
            }
            else {
                $section = $null
            }
            continue
        }
        $equals = $line.IndexOf('=')
        if ($equals -lt 1 -or $null -eq $section) { continue }
        $key = $line.Substring(0, $equals).Trim()
        $value = $line.Substring($equals + 1).Trim()
        if ($key) { $section[$key] = $value }
    }
    $config
}

function ConvertTo-SqlCockpitSecureString {
    <#
    .SYNOPSIS
    Wraps a key read from the environment or the config file in a read-only SecureString.
    #>
    [CmdletBinding()]
    [OutputType([securestring])]
    param(
        [Parameter(Mandatory)]
        [string] $Value
    )

    $secure = New-Object -TypeName System.Security.SecureString
    foreach ($character in $Value.ToCharArray()) { $secure.AppendChar($character) }
    $secure.MakeReadOnly()
    $secure
}

function Resolve-SqlCockpitConnection {
    <#
    .SYNOPSIS
    Works out the API key and portal URL for a request.
    Connect-SqlCockpit wins; otherwise SQL_COCKPIT_API_KEY / SQL_COCKPIT_PORTAL_URL, then the
    active profile of ~/.sqlcockpit.conf (its [default] profile, or SQL_COCKPIT_PROFILE).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if ($script:Connection) { return $script:Connection }

    $config = Read-SqlCockpitConfigFile -Path (Get-SqlCockpitConfigPath)

    $profileName = 'default'
    if ($config.Default['profile']) { $profileName = $config.Default['profile'] }
    if ($env:SQL_COCKPIT_PROFILE) { $profileName = $env:SQL_COCKPIT_PROFILE }
    if ($profileName -notmatch '^[A-Za-z0-9_.-]{1,64}\z') {
        throw (Get-SqlCockpitErrorRecord -Message 'A profile name may use letters, digits, dot, dash and underscore (1 to 64 characters).' -Code 'invalid_config')
    }
    $section = $config.Profiles[$profileName]
    if ($null -eq $section) { $section = @{} }

    $key = $null
    $source = $null
    if ($section['api_key']) {
        $key = $section['api_key']
        $source = "config file (profile $profileName)"
    }
    if ($env:SQL_COCKPIT_API_KEY) {
        $key = $env:SQL_COCKPIT_API_KEY
        $source = 'SQL_COCKPIT_API_KEY'
    }

    $portalUrl = $script:DefaultPortalUrl
    if ($section['portal_url']) { $portalUrl = $section['portal_url'] }
    if ($env:SQL_COCKPIT_PORTAL_URL) { $portalUrl = $env:SQL_COCKPIT_PORTAL_URL }
    $portalUrl = ConvertTo-SqlCockpitPortalUrl -Url $portalUrl

    if ([string]::IsNullOrWhiteSpace($key)) {
        throw (Get-SqlCockpitErrorRecord -Code 'not_connected' `
                -Message 'Not connected. Run Connect-SqlCockpit, set SQL_COCKPIT_API_KEY, or log in with the sqlcockpit CLI. Create a key in the portal under Settings > Developer access.')
    }

    [pscustomobject]@{
        ApiKey    = ConvertTo-SqlCockpitSecureString -Value $key.Trim()
        PortalUrl = $portalUrl
        Source    = $source
        Transient = $true
    }
}
