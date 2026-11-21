# Shared helpers for the Pester tests.

$script:ModuleManifest = Join-Path -Path (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'SqlCockpit.Portal') -ChildPath 'SqlCockpit.Portal.psd1'

function New-TestSecureString {
    param([Parameter(Mandatory)] [string] $Text)
    $secure = New-Object System.Security.SecureString
    foreach ($character in $Text.ToCharArray()) { $secure.AppendChar($character) }
    $secure.MakeReadOnly()
    $secure
}

function ConvertFrom-TestSecureString {
    param([Parameter(Mandatory)] [securestring] $Secure)
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function New-TestResponse {
    param(
        [int] $Status = 200,
        [object] $Data = @{},
        [hashtable] $Headers = @{},
        [string] $Content,
        [switch] $TooLarge,
        [string] $ErrorCode,
        [string] $ErrorMessage,
        [hashtable] $Fields
    )
    if (-not $PSBoundParameters.ContainsKey('Content')) {
        if ($ErrorCode) {
            $errorBody = @{ code = $ErrorCode; message = $ErrorMessage }
            if ($Fields) { $errorBody.fields = $Fields }
            $Content = @{ ok = $false; error = $errorBody } | ConvertTo-Json -Depth 10 -Compress
        }
        else {
            $Content = @{ ok = $true; data = $Data } | ConvertTo-Json -Depth 10 -Compress
        }
    }
    [pscustomobject]@{ StatusCode = $Status; Headers = $Headers; Content = $Content; ContentTooLarge = [bool] $TooLarge }
}

# The mocked transport records each call in $global:SqlCockpitTest.Calls and answers from
# $global:SqlCockpitTest.Responses (the last response repeats).
function Reset-TestTransport {
    param([object[]] $Responses = @((New-TestResponse)))
    $configPath = $null
    if ($global:SqlCockpitTest) { $configPath = $global:SqlCockpitTest.ConfigPath }
    $global:SqlCockpitTest = @{
        ConfigPath = $configPath
        Calls     = New-Object System.Collections.ArrayList
        Responses = New-Object System.Collections.ArrayList
    }
    foreach ($response in $Responses) { $null = $global:SqlCockpitTest.Responses.Add($response) }
}

function Get-TestCall {
    param([int] $Index = -1)
    $calls = $global:SqlCockpitTest.Calls
    if ($Index -lt 0) { return $calls[$calls.Count + $Index] }
    $calls[$Index]
}
