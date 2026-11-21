function Get-SqlCockpitErrorCategory {
    <#
    .SYNOPSIS
    Maps an error code and HTTP status to an ErrorCategory.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorCategory])]
    param(
        [Parameter(Mandatory)]
        [string] $Code,

        [int] $StatusCode = 0
    )

    switch ($Code) {
        'unauthenticated' { return [System.Management.Automation.ErrorCategory]::AuthenticationError }
        'not_connected' { return [System.Management.Automation.ErrorCategory]::AuthenticationError }
        'invalid_key' { return [System.Management.Automation.ErrorCategory]::AuthenticationError }
        'insufficient_scope' { return [System.Management.Automation.ErrorCategory]::PermissionDenied }
        'forbidden' { return [System.Management.Automation.ErrorCategory]::PermissionDenied }
        'plan_limit' { return [System.Management.Automation.ErrorCategory]::LimitsExceeded }
        'rate_limited' { return [System.Management.Automation.ErrorCategory]::LimitsExceeded }
        'payload_too_large' { return [System.Management.Automation.ErrorCategory]::LimitsExceeded }
        'response_too_large' { return [System.Management.Automation.ErrorCategory]::LimitsExceeded }
        'not_found' { return [System.Management.Automation.ErrorCategory]::ObjectNotFound }
        'validation_failed' { return [System.Management.Automation.ErrorCategory]::InvalidArgument }
        'bad_request' { return [System.Management.Automation.ErrorCategory]::InvalidArgument }
        'invalid_argument' { return [System.Management.Automation.ErrorCategory]::InvalidArgument }
        'invalid_config' { return [System.Management.Automation.ErrorCategory]::InvalidArgument }
        'method_not_allowed' { return [System.Management.Automation.ErrorCategory]::InvalidOperation }
        'connection_error' { return [System.Management.Automation.ErrorCategory]::ConnectionError }
        'timeout' { return [System.Management.Automation.ErrorCategory]::ConnectionError }
        'server_error' { return [System.Management.Automation.ErrorCategory]::ResourceUnavailable }
        'unexpected_redirect' { return [System.Management.Automation.ErrorCategory]::InvalidResult }
        'invalid_response' { return [System.Management.Automation.ErrorCategory]::InvalidResult }
    }

    if ($StatusCode -eq 401) { return [System.Management.Automation.ErrorCategory]::AuthenticationError }
    if ($StatusCode -eq 403) { return [System.Management.Automation.ErrorCategory]::PermissionDenied }
    if ($StatusCode -eq 404) { return [System.Management.Automation.ErrorCategory]::ObjectNotFound }
    if ($StatusCode -eq 400 -or $StatusCode -eq 422) { return [System.Management.Automation.ErrorCategory]::InvalidArgument }
    if ($StatusCode -eq 429) { return [System.Management.Automation.ErrorCategory]::LimitsExceeded }
    if ($StatusCode -ge 500) { return [System.Management.Automation.ErrorCategory]::ResourceUnavailable }
    [System.Management.Automation.ErrorCategory]::NotSpecified
}

function Get-SqlCockpitErrorRecord {
    <#
    .SYNOPSIS
    Builds the ErrorRecord the module throws. The ErrorId is SqlCockpit.<code>.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [string] $Message,

        [Parameter(Mandatory)]
        [string] $Code,

        [int] $StatusCode = 0,

        [System.Collections.IDictionary] $Fields,

        [Nullable[int]] $RetryAfter,

        [object] $TargetObject
    )

    $category = Get-SqlCockpitErrorCategory -Code $Code -StatusCode $StatusCode
    $exception = [SqlCockpit.Portal.PortalException]::new($Message, $Code, $StatusCode, $Fields, $RetryAfter)
    [System.Management.Automation.ErrorRecord]::new($exception, "SqlCockpit.$Code", $category, $TargetObject)
}
