# SqlCockpit.Portal: PowerShell commands for the SQL Cockpit portal API.

if (-not ('SqlCockpit.Portal.PortalException' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections;

namespace SqlCockpit.Portal
{
    /// <summary>An error from the SQL Cockpit portal API, or one the module raised before sending.</summary>
    public class PortalException : Exception
    {
        public PortalException(string message, string code, int statusCode, IDictionary fields, Nullable<int> retryAfter)
            : base(message)
        {
            Code = code;
            StatusCode = statusCode;
            Fields = fields;
            RetryAfter = retryAfter;
        }

        /// <summary>The portal's error.code, such as validation_failed, or the module's own code.</summary>
        public string Code { get; private set; }

        /// <summary>The HTTP status, or 0 when no response was received.</summary>
        public int StatusCode { get; private set; }

        /// <summary>Field name to messages, when the portal refused a value.</summary>
        public IDictionary Fields { get; private set; }

        /// <summary>Seconds to wait before trying again, from Retry-After.</summary>
        public Nullable<int> RetryAfter { get; private set; }
    }
}
'@
}

if ($PSVersionTable.PSEdition -ne 'Core') {
    Add-Type -AssemblyName System.Net.Http
}

$script:ModuleVersion = (Import-PowerShellDataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath 'SqlCockpit.Portal.psd1')).ModuleVersion
$script:UserAgent = 'SqlCockpit.Portal/{0} PowerShell/{1}' -f $script:ModuleVersion, $PSVersionTable.PSVersion
$script:DefaultPortalUrl = 'https://portal.sql-cockpit.com'
$script:ApiPrefix = '/api/portal/v1'
$script:MaxResponseBytes = 2MB
$script:MaxRetries = 2
$script:MaxRetryDelayMs = 30000
$script:TimeoutSec = 20
$script:Connection = $null
$script:HttpClient = $null

foreach ($folder in @('Private', 'Public')) {
    $folderPath = Join-Path -Path $PSScriptRoot -ChildPath $folder
    foreach ($file in Get-ChildItem -Path $folderPath -Filter '*.ps1' | Sort-Object -Property Name) {
        . $file.FullName
    }
}

$ExecutionContext.SessionState.Module.OnRemove = {
    if ($script:Connection) { $script:Connection.ApiKey.Dispose() }
    if ($script:HttpClient) { $script:HttpClient.Dispose() }
}

$publicFunctions = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' |
    ForEach-Object { $_.BaseName }
Export-ModuleMember -Function $publicFunctions
