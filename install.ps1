<#
.SYNOPSIS
Installs the SqlCockpit.Portal PowerShell module from a GitHub release.

.DESCRIPTION
Gets a tagged release of SqlCockpit.Portal (with git when it is available, otherwise by
downloading the release zip), copies the module into your user module folder and checks the
manifest with Test-ModuleManifest.

Module folders:
  Windows, PowerShell 7      Documents\PowerShell\Modules
  Windows PowerShell 5.1     Documents\WindowsPowerShell\Modules
  macOS and Linux            ~/.local/share/powershell/Modules

On Windows it installs into both Documents folders, so the module works in pwsh and in Windows
PowerShell 5.1. Use -CurrentEditionOnly to install for the running edition only.

.PARAMETER Version
The release to install, such as 0.1.0. Defaults to the latest release.

.PARAMETER Method
Git (git clone of the tag), Download (the release zip) or Auto (git when it is on PATH).

.PARAMETER Destination
A modules folder to install into instead of the default ones.

.PARAMETER SourcePath
Install from a local copy of the SqlCockpit.Portal folder instead of GitHub.

.PARAMETER CurrentEditionOnly
On Windows, install only for the edition running this script.

.EXAMPLE
irm https://raw.githubusercontent.com/sql-cockpit/sql-cockpit-powershell/main/install.ps1 | iex

Installs the latest release.

.EXAMPLE
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/sql-cockpit/sql-cockpit-powershell/main/install.ps1))) -Version 0.1.0

Installs a given release.

.EXAMPLE
.\install.ps1 -SourcePath .\SqlCockpit.Portal

Installs from a clone of the repository.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'The installer reports progress to the person running it.')]
[CmdletBinding()]
param(
    [string] $Version,

    [ValidateSet('Auto', 'Git', 'Download')]
    [string] $Method = 'Auto',

    [string] $Destination,

    [string] $SourcePath,

    [switch] $CurrentEditionOnly
)

$ErrorActionPreference = 'Stop'
$repository = 'sql-cockpit/sql-cockpit-powershell'
$moduleName = 'SqlCockpit.Portal'

function Get-ModuleRoot {
    param([switch] $CurrentOnly)

    $onWindows = $PSVersionTable.PSEdition -eq 'Desktop' -or ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows)
    if (-not $onWindows) {
        $dataHome = $env:XDG_DATA_HOME
        if (-not $dataHome) { $dataHome = Join-Path -Path $HOME -ChildPath '.local/share' }
        return @(Join-Path -Path (Join-Path -Path $dataHome -ChildPath 'powershell') -ChildPath 'Modules')
    }

    $documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    if (-not $documents) { $documents = Join-Path -Path $HOME -ChildPath 'Documents' }
    $core = Join-Path -Path (Join-Path -Path $documents -ChildPath 'PowerShell') -ChildPath 'Modules'
    $desktop = Join-Path -Path (Join-Path -Path $documents -ChildPath 'WindowsPowerShell') -ChildPath 'Modules'
    if (-not $CurrentOnly) { return @($core, $desktop) }
    if ($PSVersionTable.PSEdition -eq 'Desktop') { return @($desktop) }
    @($core)
}

if ($PSVersionTable.PSEdition -ne 'Core') {
    $protocols = [Net.ServicePointManager]::SecurityProtocol
    if ([int] $protocols -ne 0 -and -not ($protocols -band [Net.SecurityProtocolType]::Tls12)) {
        [Net.ServicePointManager]::SecurityProtocol = $protocols -bor [Net.SecurityProtocolType]::Tls12
    }
}

$work = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ('sqlcockpit-portal-' + [guid]::NewGuid().ToString('n'))
$null = New-Item -ItemType Directory -Path $work
try {
    if ($SourcePath) {
        $source = (Resolve-Path -LiteralPath $SourcePath).Path
    }
    else {
        if (-not $Version) {
            Write-Host 'Looking up the latest release...'
            $release = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$repository/releases/latest" -Headers @{ 'User-Agent' = 'SqlCockpit.Portal-installer' }
            $Version = $release.tag_name
        }
        $Version = $Version.TrimStart('v')
        if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must look like 0.1.0 (got '$Version')." }
        $tag = "v$Version"

        if ($Method -eq 'Auto') {
            if (Get-Command -Name git -ErrorAction SilentlyContinue) { $Method = 'Git' } else { $Method = 'Download' }
        }

        if ($Method -eq 'Git') {
            Write-Host "Cloning $repository at $tag..."
            $clone = Join-Path -Path $work -ChildPath 'clone'
            & git -c advice.detachedHead=false clone --quiet --depth 1 --branch $tag "https://github.com/$repository.git" $clone
            if ($LASTEXITCODE -ne 0) { throw "git clone of $tag failed." }
            $source = Join-Path -Path $clone -ChildPath $moduleName
        }
        else {
            $zipUrl = "https://github.com/$repository/releases/download/$tag/$moduleName-$Version.zip"
            Write-Host "Downloading $zipUrl..."
            $zip = Join-Path -Path $work -ChildPath 'module.zip'
            Invoke-WebRequest -UseBasicParsing -Uri $zipUrl -OutFile $zip
            $expanded = Join-Path -Path $work -ChildPath 'expanded'
            Expand-Archive -LiteralPath $zip -DestinationPath $expanded
            $source = Join-Path -Path $expanded -ChildPath $moduleName
        }
    }

    $sourceManifest = Join-Path -Path $source -ChildPath "$moduleName.psd1"
    if (-not (Test-Path -LiteralPath $sourceManifest)) { throw "No $moduleName.psd1 in $source." }
    $manifest = Test-ModuleManifest -Path $sourceManifest
    $moduleVersion = $manifest.Version.ToString()
    if ($Version -and -not $SourcePath -and $moduleVersion -ne $Version) {
        throw "The $tag release holds module version $moduleVersion."
    }

    $roots = if ($Destination) { @($Destination) } else { Get-ModuleRoot -CurrentOnly:$CurrentEditionOnly }
    foreach ($root in $roots) {
        $target = Join-Path -Path (Join-Path -Path $root -ChildPath $moduleName) -ChildPath $moduleVersion
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        $null = New-Item -ItemType Directory -Path $target -Force
        Copy-Item -Path (Join-Path -Path $source -ChildPath '*') -Destination $target -Recurse -Force
        $installed = Test-ModuleManifest -Path (Join-Path -Path $target -ChildPath "$moduleName.psd1")
        if ($installed.Version.ToString() -ne $moduleVersion) { throw "Verification failed for $target." }
        Write-Host "Installed $moduleName $moduleVersion to $target"
    }
    Write-Host "Next: Import-Module $moduleName; Connect-SqlCockpit"
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
