function Assert-SqlCockpitUuid {
    <#
    .SYNOPSIS
    Returns the id in lower case, or throws an InvalidArgument error before anything is sent.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Value,

        [Parameter(Mandatory)]
        [string] $Name
    )

    if ($Value -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z') {
        $fields = [ordered]@{ $Name = [string[]]@('Must be a UUID.') }
        throw (Get-SqlCockpitErrorRecord -Message "$Name must be a UUID, like 3f2b1c4d-0000-4000-8000-000000000000." `
                -Code 'invalid_argument' -Fields $fields -TargetObject $Value)
    }
    $Value.ToLowerInvariant()
}

function Test-SqlCockpitInteractive {
    <#
    .SYNOPSIS
    True when the session can prompt the user.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not [Environment]::UserInteractive) { return $false }
    foreach ($argument in [Environment]::GetCommandLineArgs()) {
        if ($argument -like '-noni*' -or $argument -like '/noni*') { return $false }
    }
    $true
}
