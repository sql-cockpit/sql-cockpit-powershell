#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

# Tests the real HTTP transport against a local HttpListener on 127.0.0.1.

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestServer.ps1')
    Import-Module $script:ModuleManifest -Force

    $script:KeyText = 'sco_transport_SECRETKEY_0123456789abcdef'
    $script:Server = Start-TestServer
    $script:Prefix = '/api/portal/v1'
    $null = Connect-SqlCockpit -ApiKey (New-TestSecureString $script:KeyText) -PortalUrl $script:Server.Url -SkipCheck
}

AfterAll {
    Disconnect-SqlCockpit
    if ($script:Server) { Stop-TestServer -Server $script:Server }
    Remove-Module SqlCockpit.Portal -Force -ErrorAction SilentlyContinue
}

Describe 'HTTP transport' {
    BeforeEach {
        $script:Server.Requests.Clear()
        $script:Server.Routes.Clear()
    }

    It 'Sends the bearer key, Accept and User-Agent headers' {
        $script:Server.Routes["GET $($script:Prefix)/tenants"] = @{ Status = 200; Body = '{"ok":true,"data":{"tenants":[{"id":"3f2b1c4d-0000-4000-8000-00000000000a","name":"Contoso"}]}}' }
        $tenant = Get-SqlCockpitTenant
        $tenant.Name | Should -Be 'Contoso'
        $script:Server.Requests.Count | Should -Be 1
        $request = $script:Server.Requests[0]
        $request.Method | Should -Be 'GET'
        $request.Authorization | Should -BeExactly "Bearer $($script:KeyText)"
        $request.Accept | Should -Be 'application/json'
        $request.UserAgent | Should -Match '^SqlCockpit\.Portal/0\.1\.0 PowerShell/\d'
    }

    It 'Sends a JSON body with Content-Type application/json' {
        $script:Server.Routes["DELETE $($script:Prefix)/tenants/3f2b1c4d-0000-4000-8000-00000000000a/members/3f2b1c4d-0000-4000-8000-00000000000b"] = @{
            Status = 200; Body = '{"ok":true,"data":{"removed":true,"email":"a@example.com"}}'
        }
        Remove-SqlCockpitTeamMember -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' -Confirm:$false
        $request = $script:Server.Requests[0]
        $request.Method | Should -Be 'DELETE'
        $request.ContentType | Should -Match '^application/json'
        ($request.Body | ConvertFrom-Json).confirm | Should -BeTrue
    }

    It 'Sends the query string' {
        $script:Server.Routes["GET $($script:Prefix)/agents"] = @{ Status = 200; Body = '{"ok":true,"data":{"agents":[]}}' }
        Get-SqlCockpitAgent -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -Status active
        $script:Server.Requests[0].Query | Should -Be '?tenant_id=3f2b1c4d-0000-4000-8000-00000000000a&status=active'
    }

    It 'Does not follow a redirect' {
        $script:Server.Routes["GET $($script:Prefix)/account"] = @{ Status = 302; Headers = @{ Location = "$($script:Server.Url)/elsewhere" } }
        $script:Server.Routes['GET /elsewhere'] = @{ Status = 200; Body = '{"ok":true,"data":{}}' }
        $record = $null
        try { Get-SqlCockpitAccount } catch { $record = $_ }
        $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.unexpected_redirect,*'
        $script:Server.Requests.Count | Should -Be 1
    }

    It 'Stops reading a response over 2 MiB (<Name>)' -TestCases @(
        @{ Name = 'Content-Length'; Chunked = $false }
        @{ Name = 'chunked'; Chunked = $true }
    ) {
        param($Name, $Chunked)
        $script:Server.Routes["GET $($script:Prefix)/account"] = @{ Status = 200; BodyBytes = 3MB; Chunked = $Chunked }
        $record = $null
        try { Get-SqlCockpitAccount } catch { $record = $_ }
        $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.response_too_large,*'
    }

    It 'Reads a response just under 2 MiB' {
        $padding = 'a' * (2MB - 100)
        $script:Server.Routes["GET $($script:Prefix)/account"] = @{ Status = 200; Body = '{"ok":true,"data":{"name":"' + $padding + '"}}' }
        (Get-SqlCockpitAccount).Name.Length | Should -Be $padding.Length
    }

    It 'Redacts the key if the portal echoes it back' {
        $script:Server.Routes["GET $($script:Prefix)/account"] = @{
            Status = 422; EchoAuth = $true
            Body = '{"ok":false,"error":{"code":"validation_failed","message":"Refused {{auth}}","fields":{"key":["{{auth}} is wrong"]}}}'
        }
        $record = $null
        try { Get-SqlCockpitAccount } catch { $record = $_ }
        $record.Exception.Message | Should -Match '\[redacted\]'
        ($record | Out-String) + $record.Exception.ToString() | Should -Not -Match ([regex]::Escape($script:KeyText))
        ($Error | Out-String) | Should -Not -Match ([regex]::Escape($script:KeyText))
    }

    It 'Retries a GET after Retry-After' {
        $script:Server.Routes["GET $($script:Prefix)/usage"] = @{
            Status = 429; Headers = @{ 'Retry-After' = '0' }; Body = '{"ok":false,"error":{"code":"rate_limited","message":"Slow down."}}'
        }
        $record = $null
        try { Get-SqlCockpitUsage } catch { $record = $_ }
        $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.rate_limited,*'
        $script:Server.Requests.Count | Should -Be 3
    }

    It 'Reports a connection error without the key' {
        $probe = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback), 0
        $probe.Start()
        $port = $probe.LocalEndpoint.Port
        $probe.Stop()
        $null = Connect-SqlCockpit -ApiKey (New-TestSecureString $script:KeyText) -PortalUrl "http://127.0.0.1:$port" -SkipCheck
        try {
            $record = $null
            try { Get-SqlCockpitAccount } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.connection_error,*'
            $record.CategoryInfo.Category | Should -Be 'ConnectionError'
            ($record | Out-String) + $record.Exception.ToString() | Should -Not -Match ([regex]::Escape($script:KeyText))
        }
        finally {
            $null = Connect-SqlCockpit -ApiKey (New-TestSecureString $script:KeyText) -PortalUrl $script:Server.Url -SkipCheck
        }
    }
}
