<#
.SYNOPSIS
A first call to the SQL Cockpit portal API with the SqlCockpit.Portal module.

.DESCRIPTION
Connects (unless SQL_COCKPIT_API_KEY or the sqlcockpit CLI's config file already provides a
key), then shows your account, your tenants and the active Agents of each tenant.

.PARAMETER PortalUrl
The portal's address. Defaults to https://portal.sql-cockpit.com.

.EXAMPLE
./examples/first-call.ps1
#>
[CmdletBinding()]
param(
    [string] $PortalUrl
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name SqlCockpit.Portal)) {
    # Running from a clone of the repository.
    Import-Module (Join-Path -Path (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'SqlCockpit.Portal') -ChildPath 'SqlCockpit.Portal.psd1')
}
else {
    Import-Module SqlCockpit.Portal
}

$configFile = Join-Path -Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)) -ChildPath '.sqlcockpit.conf'
if ($PortalUrl -or (-not $env:SQL_COCKPIT_API_KEY -and -not (Test-Path -LiteralPath $configFile))) {
    $connectParameters = @{}
    if ($PortalUrl) { $connectParameters.PortalUrl = $PortalUrl }
    Connect-SqlCockpit @connectParameters | Format-Table
}

Get-SqlCockpitAccount | Format-List
Get-SqlCockpitTenant | Format-Table
Get-SqlCockpitTenant | Get-SqlCockpitAgent -Status active | Format-Table
