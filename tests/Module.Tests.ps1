#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

BeforeDiscovery {
    $moduleRoot = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'SqlCockpit.Portal'
    $script:CommandNames = @(Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath 'Public') -Filter '*.ps1' | ForEach-Object { $_.BaseName })
}

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')
    $script:ModuleRoot = Split-Path -Path $script:ModuleManifest -Parent
    Import-Module $script:ModuleManifest -Force
    $script:Data = Import-PowerShellDataFile -Path $script:ModuleManifest
}

AfterAll {
    Remove-Module SqlCockpit.Portal -Force -ErrorAction SilentlyContinue
}

Describe 'Module manifest' {
    It 'Passes Test-ModuleManifest' {
        $manifest = Test-ModuleManifest -Path $script:ModuleManifest -ErrorAction Stop
        $manifest.Name | Should -Be 'SqlCockpit.Portal'
        $manifest.Version | Should -Be '0.1.0'
    }

    It 'Supports Windows PowerShell 5.1 and PowerShell 7' {
        $script:Data.PowerShellVersion | Should -Be '5.1'
        $script:Data.CompatiblePSEditions | Should -Contain 'Core'
        $script:Data.CompatiblePSEditions | Should -Contain 'Desktop'
    }

    It 'Exports an explicit list of functions and nothing else' {
        $script:Data.FunctionsToExport | Should -Not -Contain '*'
        $script:Data.CmdletsToExport.Count | Should -Be 0
        $script:Data.VariablesToExport.Count | Should -Be 0
        $script:Data.AliasesToExport.Count | Should -Be 0
        $public = Get-ChildItem -Path (Join-Path -Path $script:ModuleRoot -ChildPath 'Public') -Filter '*.ps1' | ForEach-Object { $_.BaseName }
        @($script:Data.FunctionsToExport | Sort-Object) | Should -Be @($public | Sort-Object)
        @((Get-Command -Module SqlCockpit.Portal).Name | Sort-Object) | Should -Be @($public | Sort-Object)
    }

    It 'Uses only approved verbs' {
        $approved = (Get-Verb).Verb
        foreach ($command in Get-Command -Module SqlCockpit.Portal) {
            $approved | Should -Contain $command.Verb
            $command.Noun | Should -BeLike 'SqlCockpit*'
        }
    }

    It 'Does not collide with Invoke-SqlCockpit' {
        (Get-Command -Module SqlCockpit.Portal).Name | Should -Not -Contain 'Invoke-SqlCockpit'
    }

    It 'Has a table or list view for every output type' {
        $formats = [xml] (Get-Content -Raw -Path (Join-Path -Path $script:ModuleRoot -ChildPath 'SqlCockpit.Portal.Format.ps1xml'))
        $viewTypes = @($formats.Configuration.ViewDefinitions.View | ForEach-Object { $_.ViewSelectedBy.TypeName })
        foreach ($command in Get-Command -Module SqlCockpit.Portal) {
            foreach ($type in $command.OutputType) {
                if ($type.Name -like 'SqlCockpit.*') { $viewTypes | Should -Contain $type.Name }
            }
        }
    }
}

Describe 'Help for <_>' -ForEach $script:CommandNames {
    BeforeAll {
        $script:Help = Get-Help -Name $_ -Full
        $script:Command = Get-Command -Name $_
    }

    It 'Has a synopsis and a description' {
        $script:Help.Synopsis | Should -Not -BeNullOrEmpty
        $script:Help.Synopsis.Trim() | Should -Not -BeLike "$($script:Command.Name) *"
        ($script:Help.Description | Out-String).Trim() | Should -Not -BeNullOrEmpty
    }

    It 'Has at least one example' {
        @($script:Help.Examples.Example).Count | Should -BeGreaterThan 0
        foreach ($example in $script:Help.Examples.Example) {
            ($example.Code | Out-String).Trim() | Should -Not -BeNullOrEmpty
        }
    }

    It 'Describes every parameter' {
        $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        foreach ($name in $script:Command.Parameters.Keys) {
            if ($common -contains $name) { continue }
            $parameterHelp = $script:Help.Parameters.Parameter | Where-Object Name -eq $name
            ($parameterHelp.Description | Out-String).Trim() | Should -Not -BeNullOrEmpty -Because "-$name needs a description"
        }
    }
}
