#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

# Unit tests. The HTTP layer (Send-SqlCockpitHttpRequest) is mocked; see Transport.Tests.ps1 for
# tests against a real local HTTP server.

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHelpers.ps1')
    Import-Module $script:ModuleManifest -Force

    $script:KeyText = 'sco_test_TOPSECRETVALUE_0123456789abcdef'
    $script:Base = 'https://portal.example.test/api/portal/v1'
    $script:Tenant = '3f2b1c4d-0000-4000-8000-00000000000a'
    $script:Member = '3f2b1c4d-0000-4000-8000-00000000000b'
    $script:Ticket = '3f2b1c4d-0000-4000-8000-00000000000c'
    $script:Agent = '3f2b1c4d-0000-4000-8000-00000000000d'
}

AfterAll {
    Remove-Module SqlCockpit.Portal -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name SqlCockpitTest -Scope Global -ErrorAction SilentlyContinue
}

Describe 'SqlCockpit.Portal' {
    BeforeEach {
        Reset-TestTransport
        $env:SQL_COCKPIT_API_KEY = $null
        $env:SQL_COCKPIT_PORTAL_URL = $null
        $env:SQL_COCKPIT_PROFILE = $null
        $global:SqlCockpitTest.ConfigPath = Join-Path -Path $TestDrive -ChildPath 'missing.conf'

        Mock -ModuleName SqlCockpit.Portal -CommandName Send-SqlCockpitHttpRequest -MockWith {
            $null = $global:SqlCockpitTest.Calls.Add([pscustomobject]@{
                    Method     = $PesterBoundParameters['Method']
                    Uri        = $PesterBoundParameters['Uri']
                    Body       = $PesterBoundParameters['Body']
                    HasBody    = $PesterBoundParameters.ContainsKey('Body')
                    ApiKey     = $PesterBoundParameters['ApiKey']
                    UserAgent  = $PesterBoundParameters['UserAgent']
                    MaxBytes   = $PesterBoundParameters['MaxBytes']
                    TimeoutSec = $PesterBoundParameters['TimeoutSec']
                })
            $responses = $global:SqlCockpitTest.Responses
            if ($responses.Count -gt 1) {
                $next = $responses[0]
                $responses.RemoveAt(0)
                return $next
            }
            $responses[0]
        }
        Mock -ModuleName SqlCockpit.Portal -CommandName Start-Sleep -MockWith { }
        Mock -ModuleName SqlCockpit.Portal -CommandName Get-SqlCockpitConfigPath -MockWith { $global:SqlCockpitTest.ConfigPath }

        Disconnect-SqlCockpit
        $null = Connect-SqlCockpit -ApiKey (New-TestSecureString $script:KeyText) -PortalUrl 'https://portal.example.test' -SkipCheck
    }

    AfterEach {
        Disconnect-SqlCockpit
        $env:SQL_COCKPIT_API_KEY = $null
        $env:SQL_COCKPIT_PORTAL_URL = $null
        $env:SQL_COCKPIT_PROFILE = $null
    }

    Context 'Requests' {
        It '<Name> sends <Method> <Path>' -TestCases @(
            @{ Name = 'Get-SqlCockpitAccount'; Method = 'GET'; Path = '/account'; Body = $null
                Command = { Get-SqlCockpitAccount } }
            @{ Name = 'Get-SqlCockpitUsage'; Method = 'GET'; Path = '/usage'; Body = $null
                Command = { Get-SqlCockpitUsage -WarningAction SilentlyContinue } }
            @{ Name = 'Get-SqlCockpitApiKey'; Method = 'GET'; Path = '/api-keys'; Body = $null
                Command = { Get-SqlCockpitApiKey } }
            @{ Name = 'Get-SqlCockpitTenant'; Method = 'GET'; Path = '/tenants'; Body = $null
                Command = { Get-SqlCockpitTenant } }
            @{ Name = 'Get-SqlCockpitTeamMember'; Method = 'GET'; Path = '/tenants/3f2b1c4d-0000-4000-8000-00000000000a/members'; Body = $null
                Command = { Get-SqlCockpitTeamMember -TenantId '3F2B1C4D-0000-4000-8000-00000000000A' } }
            @{ Name = 'Add-SqlCockpitTeamMember'; Method = 'POST'; Path = '/tenants/3f2b1c4d-0000-4000-8000-00000000000a/members'
                Body = @{ name = 'Ada Lovelace'; email = 'ada@example.com'; role = 'developer' }
                Command = { Add-SqlCockpitTeamMember -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -Name 'Ada Lovelace' -Email 'ada@example.com' -Role Developer } }
            @{ Name = 'Set-SqlCockpitTeamMemberRole'; Method = 'PATCH'; Path = '/tenants/3f2b1c4d-0000-4000-8000-00000000000a/members/3f2b1c4d-0000-4000-8000-00000000000b'
                Body = @{ role = 'admin'; confirm = $true }
                Command = { Set-SqlCockpitTeamMemberRole -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' -Role admin -Confirm:$false } }
            @{ Name = 'Remove-SqlCockpitTeamMember'; Method = 'DELETE'; Path = '/tenants/3f2b1c4d-0000-4000-8000-00000000000a/members/3f2b1c4d-0000-4000-8000-00000000000b'
                Body = @{ confirm = $true }
                Command = { Remove-SqlCockpitTeamMember -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' -Confirm:$false } }
            @{ Name = 'Send-SqlCockpitTeamMemberInvite'; Method = 'POST'; Path = '/tenants/3f2b1c4d-0000-4000-8000-00000000000a/members/3f2b1c4d-0000-4000-8000-00000000000b/resend'; Body = $null
                Command = { Send-SqlCockpitTeamMemberInvite -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' } }
            @{ Name = 'Get-SqlCockpitAgent'; Method = 'GET'; Path = '/agents'; Body = $null
                Command = { Get-SqlCockpitAgent } }
            @{ Name = 'Get-SqlCockpitAgent -TenantId -Status'; Method = 'GET'; Path = '/agents?tenant_id=3f2b1c4d-0000-4000-8000-00000000000a&status=active'; Body = $null
                Command = { Get-SqlCockpitAgent -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -Status Active } }
            @{ Name = 'Get-SqlCockpitInstance'; Method = 'GET'; Path = '/instances'; Body = $null
                Command = { Get-SqlCockpitInstance } }
            @{ Name = 'Get-SqlCockpitInstance -TenantId'; Method = 'GET'; Path = '/instances?tenant_id=3f2b1c4d-0000-4000-8000-00000000000a'; Body = $null
                Command = { Get-SqlCockpitInstance -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' } }
            @{ Name = 'Get-SqlCockpitSupportTicket'; Method = 'GET'; Path = '/support-tickets'; Body = $null
                Command = { Get-SqlCockpitSupportTicket } }
            @{ Name = 'Get-SqlCockpitSupportTicket -Status'; Method = 'GET'; Path = '/support-tickets?status=waiting_on_customer'; Body = $null
                Command = { Get-SqlCockpitSupportTicket -Status waiting_on_customer } }
            @{ Name = 'Get-SqlCockpitSupportTicket -TicketId'; Method = 'GET'; Path = '/support-tickets/3f2b1c4d-0000-4000-8000-00000000000c'; Body = $null
                Command = { Get-SqlCockpitSupportTicket -TicketId '3f2b1c4d-0000-4000-8000-00000000000c' } }
            @{ Name = 'New-SqlCockpitSupportTicket'; Method = 'POST'; Path = '/support-tickets'
                Body = @{ subject = 'Agent offline'; message = 'db01 stopped reporting.'; tenant_id = '3f2b1c4d-0000-4000-8000-00000000000a'; agent_id = '3f2b1c4d-0000-4000-8000-00000000000d' }
                Command = { New-SqlCockpitSupportTicket -Subject 'Agent offline' -Message 'db01 stopped reporting.' -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -AgentId '3F2B1C4D-0000-4000-8000-00000000000D' } }
        ) {
            param($Name, $Method, $Path, $Body, $Command)
            $null = & $Command

            $global:SqlCockpitTest.Calls.Count | Should -Be 1
            $call = Get-TestCall
            $call.Method | Should -BeExactly $Method
            $call.Uri | Should -BeExactly ($script:Base + $Path)
            $call.UserAgent | Should -Match '^SqlCockpit\.Portal/0\.1\.0 PowerShell/\d+\.\d+'
            ConvertFrom-TestSecureString $call.ApiKey | Should -BeExactly $script:KeyText
            $call.MaxBytes | Should -Be 2MB
            if ($null -eq $Body) {
                $call.HasBody | Should -BeFalse
            }
            else {
                $call.HasBody | Should -BeTrue
                $sent = $call.Body | ConvertFrom-Json
                @($sent.PSObject.Properties).Count | Should -Be $Body.Count
                foreach ($key in $Body.Keys) { $sent.$key | Should -Be $Body[$key] }
            }
        }

        It 'Sends confirm as a JSON boolean true' {
            Set-SqlCockpitTeamMemberRole -TenantId $script:Tenant -MembershipId $script:Member -Role 'read-only' -Confirm:$false
            (Get-TestCall).Body | Should -Match '"confirm":true'
            (Get-TestCall).Body | Should -Match '"role":"read-only"'
        }

        It 'Leaves out optional ticket fields that are not given' {
            $null = New-SqlCockpitSupportTicket -Subject 'Slow sync' -Message 'Sync takes an hour.'
            $sent = (Get-TestCall).Body | ConvertFrom-Json
            $sent.PSObject.Properties.Name | Should -Not -Contain 'tenant_id'
            $sent.PSObject.Properties.Name | Should -Not -Contain 'agent_id'
        }
    }

    Context 'Output objects' {
        It 'Get-SqlCockpitTenant returns SqlCockpit.Tenant objects with TenantId' {
            Reset-TestTransport @(New-TestResponse -Data @{ tenants = @(
                        @{ id = $script:Tenant; name = 'Contoso'; your_role = 'owner'; is_owner = $true; created_at = '2026-01-02T03:04:05Z' }) })
            $tenant = Get-SqlCockpitTenant
            $tenant.PSObject.TypeNames[0] | Should -Be 'SqlCockpit.Tenant'
            $tenant.TenantId | Should -Be $script:Tenant
            $tenant.YourRole | Should -Be 'owner'
            $tenant.IsOwner | Should -BeTrue
            $tenant.CreatedAt | Should -BeOfType [datetime]
            $tenant.CreatedAt.Kind | Should -Be 'Utc'
            $tenant.CreatedAt.Hour | Should -Be 3
        }

        It 'Emits each list item separately' {
            Reset-TestTransport @(New-TestResponse -Data @{ agents = @(
                        @{ id = $script:Agent; tenant_id = $script:Tenant; name = 'db01'; status = 'active' },
                        @{ id = '3f2b1c4d-0000-4000-8000-0000000000ee'; tenant_id = $script:Tenant; name = 'db02'; status = 'active' }) })
            $agents = @(Get-SqlCockpitAgent)
            $agents.Count | Should -Be 2
            $agents[0].PSObject.TypeNames[0] | Should -Be 'SqlCockpit.Agent'
            $agents[0].AgentId | Should -Be $script:Agent
            $agents[1].Name | Should -Be 'db02'
        }

        It 'Returns nothing for an empty list' {
            Reset-TestTransport @(New-TestResponse -Data @{ instances = @() })
            @(Get-SqlCockpitInstance).Count | Should -Be 0
        }

        It 'Team members carry TenantId and MembershipId' {
            Reset-TestTransport @(New-TestResponse -Data @{ tenant = @{ id = $script:Tenant; name = 'Contoso' }; owner = @{ name = 'Ada'; email = 'ada@example.com' }
                    members = @(@{ id = $script:Member; name = 'Grace'; email = 'grace@example.com'; role = 'developer'; status = 'active' })
                    you_can_manage = $true; assignable_roles = @('admin', 'developer'); seats = @{ used = 2; limit = 5 } })
            $member = Get-SqlCockpitTeamMember -TenantId $script:Tenant
            $member.PSObject.TypeNames[0] | Should -Be 'SqlCockpit.TeamMember'
            $member.TenantId | Should -Be $script:Tenant
            $member.MembershipId | Should -Be $script:Member
            $member.TenantName | Should -Be 'Contoso'
        }

        It 'Get-SqlCockpitTeamMember -AsTeam returns the whole team' {
            Reset-TestTransport @(New-TestResponse -Data @{ tenant = @{ id = $script:Tenant; name = 'Contoso' }; owner = @{ name = 'Ada'; email = 'ada@example.com' }
                    members = @(@{ id = $script:Member; name = 'Grace' }); you_can_manage = $true; assignable_roles = @('admin'); seats = @{ used = 2; limit = 5 } })
            $team = Get-SqlCockpitTeamMember -TenantId $script:Tenant -AsTeam
            $team.PSObject.TypeNames[0] | Should -Be 'SqlCockpit.Team'
            $team.Owner.Email | Should -Be 'ada@example.com'
            $team.Seats.Limit | Should -Be 5
            @($team.Members).Count | Should -Be 1
        }

        It 'Get-SqlCockpitSupportTicket -TicketId returns the full ticket' {
            Reset-TestTransport @(New-TestResponse -Data @{ ticket = @{ id = $script:Ticket; subject = 'Agent offline'; status = 'open'; message = 'db01 stopped.'
                        tenant = @{ id = $script:Tenant; name = 'Contoso' }; agent = @{ id = $script:Agent; name = 'db01' }
                        replies = @(@{ from = 'sql_cockpit_team'; body = 'Looking.'; created_at = '2026-11-20T10:00:00Z' }) } })
            $ticket = Get-SqlCockpitSupportTicket -TicketId $script:Ticket
            $ticket.PSObject.TypeNames[0] | Should -Be 'SqlCockpit.SupportTicketDetail'
            $ticket.PSObject.TypeNames | Should -Contain 'SqlCockpit.SupportTicket'
            $ticket.TicketId | Should -Be $script:Ticket
            $ticket.TenantId | Should -Be $script:Tenant
            $ticket.AgentId | Should -Be $script:Agent
            @($ticket.Replies).Count | Should -Be 1
            $ticket.Replies[0].From | Should -Be 'sql_cockpit_team'
            $ticket.Replies[0].CreatedAt | Should -BeOfType [datetime]
        }

        It 'Get-SqlCockpitUsage emits one object per allowance' {
            Reset-TestTransport @(New-TestResponse -Data @{ plan = 'Team'; period = @{ start = '2026-11-01T00:00:00Z'; end = '2026-12-01T00:00:00Z' }
                    allowances = @(@{ key = 'agents'; label = 'Agents'; used = 3; limit = 10; remaining = 7; at_limit = $false },
                        @{ key = 'seats'; label = 'Seats'; used = 5; limit = 5; remaining = 0; at_limit = $true }) })
            $usage = @(Get-SqlCockpitUsage)
            $usage.Count | Should -Be 2
            $usage[0].PSObject.TypeNames[0] | Should -Be 'SqlCockpit.UsageAllowance'
            $usage[0].Plan | Should -Be 'Team'
            $usage[1].AtLimit | Should -BeTrue
            $usage[0].PeriodStart | Should -BeOfType [datetime]
        }

        It 'Get-SqlCockpitUsage warns when there are no allowances' {
            Reset-TestTransport @(New-TestResponse -Data @{ team_member_only = $true; message = 'Usage belongs to the billing account.'; allowances = @() })
            $result = Get-SqlCockpitUsage -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            "$warnings" | Should -Match 'billing account'
        }

        It 'Get-SqlCockpitApiKey returns keys with ApiKeyId and no value' {
            Reset-TestTransport @(New-TestResponse -Data @{ keys = @(@{ id = 7; name = 'laptop'; status = 'active'; ends_with = 'cdef' }) })
            $key = Get-SqlCockpitApiKey
            $key.PSObject.TypeNames[0] | Should -Be 'SqlCockpit.ApiKey'
            $key.ApiKeyId | Should -Be 7
            $key.EndsWith | Should -Be 'cdef'
        }

        It 'Set-, Remove- and Send- return nothing unless -PassThru' {
            Reset-TestTransport @(New-TestResponse -Data @{ member = @{ id = $script:Member; role = 'admin' }; removed = $true; sent = $true; email = 'grace@example.com' })
            Set-SqlCockpitTeamMemberRole -TenantId $script:Tenant -MembershipId $script:Member -Role admin -Confirm:$false | Should -BeNullOrEmpty
            Remove-SqlCockpitTeamMember -TenantId $script:Tenant -MembershipId $script:Member -Confirm:$false | Should -BeNullOrEmpty
            Send-SqlCockpitTeamMemberInvite -TenantId $script:Tenant -MembershipId $script:Member | Should -BeNullOrEmpty

            (Set-SqlCockpitTeamMemberRole -TenantId $script:Tenant -MembershipId $script:Member -Role admin -Confirm:$false -PassThru).Role | Should -Be 'admin'
            (Remove-SqlCockpitTeamMember -TenantId $script:Tenant -MembershipId $script:Member -Confirm:$false -PassThru).PSObject.TypeNames[0] | Should -Be 'SqlCockpit.TeamMemberRemoval'
            (Send-SqlCockpitTeamMemberInvite -TenantId $script:Tenant -MembershipId $script:Member -PassThru).Email | Should -Be 'grace@example.com'
        }
    }

    Context 'ShouldProcess' {
        It '<Name> -WhatIf sends nothing' -TestCases @(
            @{ Name = 'Add-SqlCockpitTeamMember'; Command = { Add-SqlCockpitTeamMember -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -Name 'Ada Lovelace' -Email 'ada@example.com' -Role admin -WhatIf } }
            @{ Name = 'Set-SqlCockpitTeamMemberRole'; Command = { Set-SqlCockpitTeamMemberRole -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' -Role admin -WhatIf } }
            @{ Name = 'Remove-SqlCockpitTeamMember'; Command = { Remove-SqlCockpitTeamMember -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' -WhatIf } }
            @{ Name = 'Send-SqlCockpitTeamMemberInvite'; Command = { Send-SqlCockpitTeamMemberInvite -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' -WhatIf } }
            @{ Name = 'New-SqlCockpitSupportTicket'; Command = { New-SqlCockpitSupportTicket -Subject 'Agent offline' -Message 'db01 stopped reporting.' -WhatIf } }
        ) {
            param($Name, $Command)
            $null = & $Command
            $global:SqlCockpitTest.Calls.Count | Should -Be 0
        }

        It '<Name> has ConfirmImpact <Impact>' -TestCases @(
            @{ Name = 'Set-SqlCockpitTeamMemberRole'; Impact = 'High' }
            @{ Name = 'Remove-SqlCockpitTeamMember'; Impact = 'High' }
            @{ Name = 'Add-SqlCockpitTeamMember'; Impact = 'Medium' }
            @{ Name = 'New-SqlCockpitSupportTicket'; Impact = 'Medium' }
            @{ Name = 'Send-SqlCockpitTeamMemberInvite'; Impact = 'Low' }
        ) {
            param($Name, $Impact)
            $binding = (Get-Command $Name).ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $binding.SupportsShouldProcess | Should -BeTrue
            $binding.ConfirmImpact | Should -Be $Impact
        }

        It 'Remove-SqlCockpitTeamMember -WhatIf through the pipeline sends only the GET' {
            Reset-TestTransport @(New-TestResponse -Data @{ tenant = @{ id = $script:Tenant; name = 'Contoso' }
                    members = @(@{ id = $script:Member; name = 'A' }, @{ id = '3f2b1c4d-0000-4000-8000-0000000000ff'; name = 'B' }) })
            Get-SqlCockpitTeamMember -TenantId $script:Tenant | Remove-SqlCockpitTeamMember -WhatIf
            $global:SqlCockpitTest.Calls.Count | Should -Be 1
            (Get-TestCall).Method | Should -Be 'GET'
        }
    }

    Context 'Pipeline binding' {
        It 'Get-SqlCockpitTenant | Get-SqlCockpitTeamMember lists each tenant''s team' {
            Reset-TestTransport @(
                (New-TestResponse -Data @{ tenants = @(@{ id = $script:Tenant; name = 'A' }, @{ id = '3f2b1c4d-0000-4000-8000-0000000000aa'; name = 'B' }) }),
                (New-TestResponse -Data @{ members = @(@{ id = $script:Member; name = 'Grace' }) }))
            $members = @(Get-SqlCockpitTenant | Get-SqlCockpitTeamMember)
            $members.Count | Should -Be 2
            $global:SqlCockpitTest.Calls[1].Uri | Should -Be "$($script:Base)/tenants/$($script:Tenant)/members"
            $global:SqlCockpitTest.Calls[2].Uri | Should -Be "$($script:Base)/tenants/3f2b1c4d-0000-4000-8000-0000000000aa/members"
            $members[1].TenantId | Should -Be '3f2b1c4d-0000-4000-8000-0000000000aa'
        }

        It 'Get-SqlCockpitTenant | Get-SqlCockpitAgent filters by each tenant' {
            Reset-TestTransport @(
                (New-TestResponse -Data @{ tenants = @(@{ id = $script:Tenant; name = 'A' }) }),
                (New-TestResponse -Data @{ agents = @() }))
            Get-SqlCockpitTenant | Get-SqlCockpitAgent -Status suspended
            (Get-TestCall).Uri | Should -Be "$($script:Base)/agents?tenant_id=$($script:Tenant)&status=suspended"
        }

        It 'Get-SqlCockpitTenant | Get-SqlCockpitInstance filters by each tenant' {
            Reset-TestTransport @(
                (New-TestResponse -Data @{ tenants = @(@{ id = $script:Tenant; name = 'A' }) }),
                (New-TestResponse -Data @{ instances = @() }))
            Get-SqlCockpitTenant | Get-SqlCockpitInstance
            (Get-TestCall).Uri | Should -Be "$($script:Base)/instances?tenant_id=$($script:Tenant)"
        }

        It 'Team members pipe into Set-SqlCockpitTeamMemberRole' {
            Reset-TestTransport @(
                (New-TestResponse -Data @{ members = @(@{ id = $script:Member; name = 'Grace'; role = 'developer' }) }),
                (New-TestResponse -Data @{ member = @{ id = $script:Member; role = 'admin' } }))
            Get-SqlCockpitTeamMember -TenantId $script:Tenant | Set-SqlCockpitTeamMemberRole -Role admin -Confirm:$false
            (Get-TestCall).Method | Should -Be 'PATCH'
            (Get-TestCall).Uri | Should -Be "$($script:Base)/tenants/$($script:Tenant)/members/$($script:Member)"
        }

        It 'Team members pipe into Send-SqlCockpitTeamMemberInvite' {
            Reset-TestTransport @(
                (New-TestResponse -Data @{ members = @(@{ id = $script:Member; name = 'Grace'; status = 'pending_password' }) }),
                (New-TestResponse -Data @{ sent = $true; email = 'grace@example.com' }))
            Get-SqlCockpitTeamMember -TenantId $script:Tenant | Send-SqlCockpitTeamMemberInvite
            (Get-TestCall).Uri | Should -Be "$($script:Base)/tenants/$($script:Tenant)/members/$($script:Member)/resend"
        }

        It 'Objects with TenantId, Name, Email and Role pipe into Add-SqlCockpitTeamMember' {
            Reset-TestTransport @(New-TestResponse -Status 201 -Data @{ member = @{ id = $script:Member; name = 'Ada' } })
            $rows = @(
                [pscustomobject]@{ Name = 'Ada Lovelace'; Email = 'ada@example.com'; Role = 'admin' }
                [pscustomobject]@{ Name = 'Grace Hopper'; Email = 'grace@example.com'; Role = 'operator' }
            )
            $added = @($rows | Add-SqlCockpitTeamMember -TenantId $script:Tenant)
            $added.Count | Should -Be 2
            ($global:SqlCockpitTest.Calls[1].Body | ConvertFrom-Json).role | Should -Be 'operator'
        }

        It 'Ticket summaries pipe into Get-SqlCockpitSupportTicket by TicketId' {
            Reset-TestTransport @(
                (New-TestResponse -Data @{ tickets = @(@{ id = $script:Ticket; subject = 'A' }) }),
                (New-TestResponse -Data @{ ticket = @{ id = $script:Ticket; subject = 'A'; message = 'Long text' } }))
            $ticket = Get-SqlCockpitSupportTicket | Get-SqlCockpitSupportTicket
            (Get-TestCall).Uri | Should -Be "$($script:Base)/support-tickets/$($script:Ticket)"
            $ticket.Message | Should -Be 'Long text'
        }

        It 'Agents pipe into New-SqlCockpitSupportTicket with TenantId and AgentId' {
            Reset-TestTransport @(
                (New-TestResponse -Data @{ agents = @(@{ id = $script:Agent; tenant_id = $script:Tenant; name = 'db01' }) }),
                (New-TestResponse -Status 201 -Data @{ ticket = @{ id = $script:Ticket; subject = 'Agent offline' } }))
            $null = Get-SqlCockpitAgent | New-SqlCockpitSupportTicket -Subject 'Agent offline' -Message 'db01 stopped reporting.'
            $sent = (Get-TestCall).Body | ConvertFrom-Json
            $sent.tenant_id | Should -Be $script:Tenant
            $sent.agent_id | Should -Be $script:Agent
        }
    }

    Context 'Id validation' {
        It '<Name> refuses a malformed id before sending anything' -TestCases @(
            @{ Name = 'Get-SqlCockpitTeamMember'; Command = { Get-SqlCockpitTeamMember -TenantId 'not-a-uuid' } }
            @{ Name = 'Add-SqlCockpitTeamMember'; Command = { Add-SqlCockpitTeamMember -TenantId '../account' -Name 'Ada Lovelace' -Email 'ada@example.com' -Role admin } }
            @{ Name = 'Set-SqlCockpitTeamMemberRole'; Command = { Set-SqlCockpitTeamMemberRole -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '1' -Role admin -Confirm:$false } }
            @{ Name = 'Remove-SqlCockpitTeamMember'; Command = { Remove-SqlCockpitTeamMember -TenantId 'x' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' -Confirm:$false } }
            @{ Name = 'Send-SqlCockpitTeamMemberInvite'; Command = { Send-SqlCockpitTeamMemberInvite -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId "3f2b1c4d-0000-4000-8000-00000000000b`n" } }
            @{ Name = 'Get-SqlCockpitAgent'; Command = { Get-SqlCockpitAgent -TenantId 'abc' } }
            @{ Name = 'Get-SqlCockpitInstance'; Command = { Get-SqlCockpitInstance -TenantId 'abc' } }
            @{ Name = 'Get-SqlCockpitSupportTicket'; Command = { Get-SqlCockpitSupportTicket -TicketId '3f2b1c4d00004000800000000000000c' } }
            @{ Name = 'New-SqlCockpitSupportTicket'; Command = { New-SqlCockpitSupportTicket -Subject 'Subject' -Message 'A long enough message.' -AgentId 'abc' } }
        ) {
            param($Name, $Command)
            $record = $null
            try { & $Command } catch { $record = $_ }
            $record | Should -Not -BeNullOrEmpty
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.invalid_argument*'
            $record.CategoryInfo.Category | Should -Be 'InvalidArgument'
            $global:SqlCockpitTest.Calls.Count | Should -Be 0
        }

        It 'Rejects a role outside the ValidateSet' {
            { Set-SqlCockpitTeamMemberRole -TenantId $script:Tenant -MembershipId $script:Member -Role owner -Confirm:$false } | Should -Throw
            $global:SqlCockpitTest.Calls.Count | Should -Be 0
        }

        It 'Rejects a status outside the ValidateSet' {
            { Get-SqlCockpitAgent -Status online } | Should -Throw
            { Get-SqlCockpitSupportTicket -Status done } | Should -Throw
            $global:SqlCockpitTest.Calls.Count | Should -Be 0
        }
    }

    Context 'Error mapping' {
        It 'HTTP <Status> <Code> becomes <Category>' -TestCases @(
            @{ Status = 401; Code = 'unauthenticated'; Category = 'AuthenticationError' }
            @{ Status = 403; Code = 'insufficient_scope'; Category = 'PermissionDenied' }
            @{ Status = 403; Code = 'forbidden'; Category = 'PermissionDenied' }
            @{ Status = 403; Code = 'plan_limit'; Category = 'LimitsExceeded' }
            @{ Status = 404; Code = 'not_found'; Category = 'ObjectNotFound' }
            @{ Status = 400; Code = 'bad_request'; Category = 'InvalidArgument' }
            @{ Status = 422; Code = 'validation_failed'; Category = 'InvalidArgument' }
            @{ Status = 429; Code = 'rate_limited'; Category = 'LimitsExceeded' }
            @{ Status = 500; Code = 'server_error'; Category = 'ResourceUnavailable' }
        ) {
            param($Status, $Code, $Category)
            Reset-TestTransport @(New-TestResponse -Status $Status -ErrorCode $Code -ErrorMessage 'Refused.')
            $record = $null
            try { Get-SqlCockpitAccount } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -Be "SqlCockpit.$Code,Get-SqlCockpitAccount"
            $record.CategoryInfo.Category | Should -Be $Category
            $record.Exception.Code | Should -Be $Code
            $record.Exception.StatusCode | Should -Be $Status
            $record.Exception.Message | Should -Match 'Refused\.'
        }

        It 'Falls back to a code from the status when the body is not JSON' {
            Reset-TestTransport @(New-TestResponse -Status 404 -Content '<html>Not here</html>')
            $record = $null
            try { Get-SqlCockpitTenant } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.not_found,*'
            $record.Exception.Message | Should -Be 'The portal request failed (HTTP 404).'
        }

        It 'Includes field messages' {
            Reset-TestTransport @(New-TestResponse -Status 422 -ErrorCode 'validation_failed' -ErrorMessage 'The given data was invalid.' `
                    -Fields @{ email = @('The email has already been taken.') })
            $record = $null
            try { Add-SqlCockpitTeamMember -TenantId $script:Tenant -Name 'Ada Lovelace' -Email 'ada@example.com' -Role admin } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.validation_failed,*'
            $record.Exception.Message | Should -Match 'email: The email has already been taken\.'
            $record.Exception.Fields['email'] | Should -Contain 'The email has already been taken.'
        }

        It 'A 2xx answer that is not a SQL Cockpit envelope is invalid_response' {
            Reset-TestTransport @(New-TestResponse -Status 200 -Content 'hello')
            $record = $null
            try { Get-SqlCockpitAccount } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.invalid_response,*'
            $record.CategoryInfo.Category | Should -Be 'InvalidResult'
        }

        It 'Connection failures surface as ConnectionError' {
            Mock -ModuleName SqlCockpit.Portal -CommandName Send-SqlCockpitHttpRequest -MockWith {
                throw (& (Get-Module SqlCockpit.Portal) { Get-SqlCockpitErrorRecord -Code 'connection_error' -Message 'Could not reach the SQL Cockpit portal.' })
            }
            $record = $null
            try { Get-SqlCockpitAccount } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.connection_error,*'
            $record.CategoryInfo.Category | Should -Be 'ConnectionError'
        }

        It 'Errors are terminating' {
            Reset-TestTransport @(New-TestResponse -Status 404 -ErrorCode 'not_found' -ErrorMessage 'Nope.')
            { Get-SqlCockpitAccount -ErrorAction SilentlyContinue } | Should -Throw
        }
    }

    Context 'Retries' {
        It 'Retries a GET on 429 at most twice, honouring Retry-After capped at 30 seconds' {
            Reset-TestTransport @(New-TestResponse -Status 429 -Headers @{ 'retry-after' = '120' } -ErrorCode 'rate_limited' -ErrorMessage 'Slow down.')
            $record = $null
            try { Get-SqlCockpitTenant } catch { $record = $_ }
            $global:SqlCockpitTest.Calls.Count | Should -Be 3
            Should -Invoke -ModuleName SqlCockpit.Portal -CommandName Start-Sleep -Times 2 -Exactly -ParameterFilter { $Milliseconds -eq 30000 }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.rate_limited,*'
            $record.Exception.RetryAfter | Should -Be 120
            $record.Exception.Message | Should -Match 'Try again in 120 seconds'
        }

        It 'Uses a short Retry-After as given' {
            Reset-TestTransport @(
                (New-TestResponse -Status 429 -Headers @{ 'retry-after' = '2' } -ErrorCode 'rate_limited' -ErrorMessage 'Slow down.'),
                (New-TestResponse -Data @{ tenants = @() }))
            Get-SqlCockpitTenant
            $global:SqlCockpitTest.Calls.Count | Should -Be 2
            Should -Invoke -ModuleName SqlCockpit.Portal -CommandName Start-Sleep -Times 1 -Exactly -ParameterFilter { $Milliseconds -eq 2000 }
        }

        It 'Retries a GET on 5xx and returns the data once it succeeds' {
            Reset-TestTransport @(
                (New-TestResponse -Status 503 -ErrorCode 'server_error' -ErrorMessage 'Down.'),
                (New-TestResponse -Status 502 -Content 'Bad gateway'),
                (New-TestResponse -Data @{ tenants = @(@{ id = $script:Tenant; name = 'Contoso' }) }))
            $tenant = Get-SqlCockpitTenant
            $tenant.Name | Should -Be 'Contoso'
            $global:SqlCockpitTest.Calls.Count | Should -Be 3
            Should -Invoke -ModuleName SqlCockpit.Portal -CommandName Start-Sleep -Times 2 -Exactly -ParameterFilter { $Milliseconds -le 30000 }
        }

        It 'Does not retry a GET on 4xx other than 429' {
            Reset-TestTransport @(New-TestResponse -Status 404 -ErrorCode 'not_found' -ErrorMessage 'Nope.')
            { Get-SqlCockpitTenant } | Should -Throw
            $global:SqlCockpitTest.Calls.Count | Should -Be 1
        }

        It '<Name> is never retried' -TestCases @(
            @{ Name = 'POST'; Command = { New-SqlCockpitSupportTicket -Subject 'Agent offline' -Message 'db01 stopped reporting.' } }
            @{ Name = 'PATCH'; Command = { Set-SqlCockpitTeamMemberRole -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' -Role admin -Confirm:$false } }
            @{ Name = 'DELETE'; Command = { Remove-SqlCockpitTeamMember -TenantId '3f2b1c4d-0000-4000-8000-00000000000a' -MembershipId '3f2b1c4d-0000-4000-8000-00000000000b' -Confirm:$false } }
        ) {
            param($Name, $Command)
            Reset-TestTransport @(New-TestResponse -Status 503 -ErrorCode 'server_error' -ErrorMessage 'Down.')
            { & $Command } | Should -Throw
            $global:SqlCockpitTest.Calls.Count | Should -Be 1
            Should -Invoke -ModuleName SqlCockpit.Portal -CommandName Start-Sleep -Times 0 -Exactly
        }

        It 'A rate-limited POST is not retried' {
            Reset-TestTransport @(New-TestResponse -Status 429 -Headers @{ 'retry-after' = '1' } -ErrorCode 'rate_limited' -ErrorMessage 'Too many tickets.')
            { New-SqlCockpitSupportTicket -Subject 'Agent offline' -Message 'db01 stopped reporting.' } | Should -Throw
            $global:SqlCockpitTest.Calls.Count | Should -Be 1
        }
    }

    Context 'Redirects and response size' {
        It 'Refuses a <Status> redirect without following it' -TestCases @(
            @{ Status = 301 }, @{ Status = 302 }, @{ Status = 307 }, @{ Status = 308 }
        ) {
            param($Status)
            Reset-TestTransport @(New-TestResponse -Status $Status -Headers @{ location = 'https://evil.example/' } -Content '')
            $record = $null
            try { Get-SqlCockpitAccount } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.unexpected_redirect,*'
            $global:SqlCockpitTest.Calls.Count | Should -Be 1
        }

        It 'Refuses a response the transport flagged as over 2 MiB' {
            Reset-TestTransport @(New-TestResponse -Status 200 -Content '' -TooLarge)
            $record = $null
            try { Get-SqlCockpitAccount } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.response_too_large,*'
            $record.CategoryInfo.Category | Should -Be 'LimitsExceeded'
        }

        It 'Refuses a body over 2 MiB even if the transport returned it' {
            $big = '{"ok":true,"data":{"name":"' + ('a' * (2MB)) + '"}}'
            Reset-TestTransport @(New-TestResponse -Status 200 -Content $big)
            $record = $null
            try { Get-SqlCockpitAccount } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.response_too_large,*'
        }

        It 'Asks the transport for at most 2 MiB' {
            $null = Get-SqlCockpitAccount
            (Get-TestCall).MaxBytes | Should -Be 2097152
        }
    }

    Context 'Connecting and configuration' {
        BeforeEach {
            Disconnect-SqlCockpit
            Reset-TestTransport
        }

        It 'Fails with not_connected when nothing is configured' {
            $record = $null
            try { Get-SqlCockpitTenant } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.not_connected,*'
            $record.CategoryInfo.Category | Should -Be 'AuthenticationError'
            $global:SqlCockpitTest.Calls.Count | Should -Be 0
        }

        It 'Uses the config file''s default profile' {
            Set-Content -LiteralPath $global:SqlCockpitTest.ConfigPath -Value @(
                '# comment', '[profile default]', 'api_key = sco_file_default_key_0123456789', 'portal_url = https://file.example.test')
            $null = Get-SqlCockpitAccount
            ConvertFrom-TestSecureString (Get-TestCall).ApiKey | Should -Be 'sco_file_default_key_0123456789'
            (Get-TestCall).Uri | Should -Be 'https://file.example.test/api/portal/v1/account'
        }

        It 'Uses the profile named in [default]' {
            Set-Content -LiteralPath $global:SqlCockpitTest.ConfigPath -Value @(
                '[default]', 'profile = work', '', '[profile default]', 'api_key = sco_file_default_key_0123456789',
                '[profile work]', 'api_key = sco_file_work_key_0123456789abc', 'portal_url = https://work.example.test/api/portal/v1')
            $null = Get-SqlCockpitAccount
            ConvertFrom-TestSecureString (Get-TestCall).ApiKey | Should -Be 'sco_file_work_key_0123456789abc'
            (Get-TestCall).Uri | Should -Be 'https://work.example.test/api/portal/v1/account'
        }

        It 'SQL_COCKPIT_PROFILE picks the profile' {
            Set-Content -LiteralPath $global:SqlCockpitTest.ConfigPath -Value @(
                '[default]', 'profile = work', '[profile work]', 'api_key = sco_file_work_key_0123456789abc',
                '[profile staging]', 'api_key = sco_file_staging_key_0123456789', 'portal_url = https://staging.example.test')
            $env:SQL_COCKPIT_PROFILE = 'staging'
            $null = Get-SqlCockpitAccount
            ConvertFrom-TestSecureString (Get-TestCall).ApiKey | Should -Be 'sco_file_staging_key_0123456789'
            (Get-TestCall).Uri | Should -Be 'https://staging.example.test/api/portal/v1/account'
        }

        It 'Refuses a malformed profile name' {
            $env:SQL_COCKPIT_PROFILE = '../etc'
            $record = $null
            try { Get-SqlCockpitAccount } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.invalid_config,*'
        }

        It 'Environment variables override the config file' {
            Set-Content -LiteralPath $global:SqlCockpitTest.ConfigPath -Value @(
                '[profile default]', 'api_key = sco_file_default_key_0123456789', 'portal_url = https://file.example.test')
            $env:SQL_COCKPIT_API_KEY = 'sco_env_key_0123456789abcdef'
            $env:SQL_COCKPIT_PORTAL_URL = 'https://env.example.test'
            $null = Get-SqlCockpitAccount
            ConvertFrom-TestSecureString (Get-TestCall).ApiKey | Should -Be 'sco_env_key_0123456789abcdef'
            (Get-TestCall).Uri | Should -Be 'https://env.example.test/api/portal/v1/account'
        }

        It 'The environment key works with the file''s portal URL' {
            Set-Content -LiteralPath $global:SqlCockpitTest.ConfigPath -Value @('[profile default]', 'portal_url = https://file.example.test')
            $env:SQL_COCKPIT_API_KEY = 'sco_env_key_0123456789abcdef'
            $null = Get-SqlCockpitAccount
            (Get-TestCall).Uri | Should -Be 'https://file.example.test/api/portal/v1/account'
        }

        It 'Defaults to the production portal' {
            $env:SQL_COCKPIT_API_KEY = 'sco_env_key_0123456789abcdef'
            $null = Get-SqlCockpitAccount
            (Get-TestCall).Uri | Should -Be 'https://portal.sql-cockpit.com/api/portal/v1/account'
        }

        It 'Connect-SqlCockpit overrides the environment and the file' {
            Set-Content -LiteralPath $global:SqlCockpitTest.ConfigPath -Value @('[profile default]', 'api_key = sco_file_default_key_0123456789')
            $env:SQL_COCKPIT_API_KEY = 'sco_env_key_0123456789abcdef'
            $null = Connect-SqlCockpit -ApiKey (New-TestSecureString 'sco_connect_key_0123456789ab') -PortalUrl 'https://connect.example.test' -SkipCheck
            $null = Get-SqlCockpitAccount
            ConvertFrom-TestSecureString (Get-TestCall).ApiKey | Should -Be 'sco_connect_key_0123456789ab'
            (Get-TestCall).Uri | Should -Be 'https://connect.example.test/api/portal/v1/account'
        }

        It 'Disconnect-SqlCockpit falls back to the environment' {
            $env:SQL_COCKPIT_API_KEY = 'sco_env_key_0123456789abcdef'
            $null = Connect-SqlCockpit -ApiKey (New-TestSecureString 'sco_connect_key_0123456789ab') -SkipCheck
            Disconnect-SqlCockpit
            $null = Get-SqlCockpitAccount
            ConvertFrom-TestSecureString (Get-TestCall).ApiKey | Should -Be 'sco_env_key_0123456789abcdef'
        }

        It 'Connect-SqlCockpit uses SQL_COCKPIT_PORTAL_URL when -PortalUrl is left out' {
            $env:SQL_COCKPIT_PORTAL_URL = 'https://env.example.test'
            $null = Connect-SqlCockpit -ApiKey (New-TestSecureString 'sco_connect_key_0123456789ab') -SkipCheck
            $null = Get-SqlCockpitAccount
            (Get-TestCall).Uri | Should -Be 'https://env.example.test/api/portal/v1/account'
        }

        It 'Connect-SqlCockpit checks the key with GET /account and reports who you are' {
            Reset-TestTransport @(New-TestResponse -Data @{ name = 'Ada'; email = 'ada@example.com'; connected_via = @{ type = 'api_key'; name = 'laptop'; scopes = @('portal:read') } })
            $connection = Connect-SqlCockpit -ApiKey (New-TestSecureString 'sco_connect_key_0123456789ab') -PortalUrl 'https://connect.example.test'
            (Get-TestCall).Uri | Should -Be 'https://connect.example.test/api/portal/v1/account'
            $connection.PSObject.TypeNames[0] | Should -Be 'SqlCockpit.Connection'
            $connection.Email | Should -Be 'ada@example.com'
            $connection.ApiKeyName | Should -Be 'laptop'
            $connection.PSObject.Properties.Name | Should -Not -Contain 'ApiKey'
        }

        It 'Connect-SqlCockpit keeps the previous connection when the check fails' {
            $null = Connect-SqlCockpit -ApiKey (New-TestSecureString 'sco_first_key_0123456789abcd') -PortalUrl 'https://first.example.test' -SkipCheck
            Reset-TestTransport @(New-TestResponse -Status 401 -ErrorCode 'unauthenticated' -ErrorMessage 'The API key is invalid.')
            $record = $null
            try { Connect-SqlCockpit -ApiKey (New-TestSecureString 'sco_wrong_key_0123456789abcd') -PortalUrl 'https://second.example.test' } catch { $record = $_ }
            $record.CategoryInfo.Category | Should -Be 'AuthenticationError'
            Reset-TestTransport
            $null = Get-SqlCockpitAccount
            ConvertFrom-TestSecureString (Get-TestCall).ApiKey | Should -Be 'sco_first_key_0123456789abcd'
        }

        It 'Connect-SqlCockpit prompts for the key when interactive' {
            Mock -ModuleName SqlCockpit.Portal -CommandName Test-SqlCockpitInteractive -MockWith { $true }
            Mock -ModuleName SqlCockpit.Portal -CommandName Read-Host -MockWith { New-TestSecureString 'sco_prompted_key_0123456789a' }
            $null = Connect-SqlCockpit -SkipCheck
            Should -Invoke -ModuleName SqlCockpit.Portal -CommandName Read-Host -Times 1 -Exactly -ParameterFilter { $AsSecureString }
            $null = Get-SqlCockpitAccount
            ConvertFrom-TestSecureString (Get-TestCall).ApiKey | Should -Be 'sco_prompted_key_0123456789a'
        }

        It 'Connect-SqlCockpit without a key fails when it cannot prompt' {
            Mock -ModuleName SqlCockpit.Portal -CommandName Test-SqlCockpitInteractive -MockWith { $false }
            Mock -ModuleName SqlCockpit.Portal -CommandName Read-Host -MockWith { throw 'should not prompt' }
            $record = $null
            try { Connect-SqlCockpit } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.not_connected,*'
        }

        It 'Connect-SqlCockpit refuses a key of the wrong length' {
            $record = $null
            try { Connect-SqlCockpit -ApiKey (New-TestSecureString 'short') -SkipCheck } catch { $record = $_ }
            $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.invalid_key,*'
        }

        It 'Portal URL <Url> is <Result>' -TestCases @(
            @{ Url = 'http://portal.sql-cockpit.com'; Result = 'refused' }
            @{ Url = 'ftp://portal.sql-cockpit.com'; Result = 'refused' }
            @{ Url = 'https://user:pass@portal.sql-cockpit.com'; Result = 'refused' }
            @{ Url = 'https://portal.sql-cockpit.com/?x=1'; Result = 'refused' }
            @{ Url = 'https://portal.sql-cockpit.com/#top'; Result = 'refused' }
            @{ Url = 'portal.sql-cockpit.com'; Result = 'refused' }
            @{ Url = 'https://portal.sql-cockpit.com/'; Result = 'https://portal.sql-cockpit.com' }
            @{ Url = 'https://portal.sql-cockpit.com/api/portal/v1'; Result = 'https://portal.sql-cockpit.com' }
            @{ Url = 'http://localhost:8000'; Result = 'http://localhost:8000' }
            @{ Url = 'http://127.0.0.1:8000/'; Result = 'http://127.0.0.1:8000' }
            @{ Url = 'http://[::1]:8000'; Result = 'http://[::1]:8000' }
        ) {
            param($Url, $Result)
            $record = $null
            try { $null = Connect-SqlCockpit -ApiKey (New-TestSecureString 'sco_connect_key_0123456789ab') -PortalUrl $Url -SkipCheck } catch { $record = $_ }
            if ($Result -eq 'refused') {
                $record.FullyQualifiedErrorId | Should -BeLike 'SqlCockpit.invalid_config,*'
            }
            else {
                $record | Should -BeNullOrEmpty
                $null = Get-SqlCockpitAccount
                (Get-TestCall).Uri | Should -Be "$Result/api/portal/v1/account"
            }
        }
    }

    Context 'The API key stays secret' {
        It 'No command takes the key as a plain string' {
            foreach ($command in (Get-Command -Module SqlCockpit.Portal)) {
                foreach ($parameter in $command.Parameters.Values) {
                    if ($parameter.Name -match 'Key|Token|Secret|Password') {
                        $parameter.ParameterType | Should -Be ([securestring]) -Because "$($command.Name) -$($parameter.Name)"
                    }
                }
            }
        }

        It 'Never shows the key in output, verbose, debug, warnings, errors or $Error' {
            $Error.Clear()
            Reset-TestTransport @(
                (New-TestResponse -Data @{ name = 'Ada'; email = 'ada@example.com' }),
                (New-TestResponse -Data @{ tenants = @(@{ id = $script:Tenant; name = 'Contoso' }) }),
                (New-TestResponse -Status 429 -Headers @{ 'retry-after' = '1' } -ErrorCode 'rate_limited' -ErrorMessage 'Slow down.'),
                (New-TestResponse -Status 422 -ErrorCode 'validation_failed' -ErrorMessage 'Bad.' -Fields @{ email = @('Taken.') }),
                (New-TestResponse -Status 401 -ErrorCode 'unauthenticated' -ErrorMessage 'Invalid key.'))

            $streams = & {
                Connect-SqlCockpit -ApiKey (New-TestSecureString $script:KeyText) -PortalUrl 'https://portal.example.test' -Verbose -Debug
                Get-SqlCockpitTenant -Verbose -Debug
                try { Get-SqlCockpitAccount -Verbose -Debug } catch { $_ }
                try { Add-SqlCockpitTeamMember -TenantId $script:Tenant -Name 'Ada Lovelace' -Email 'ada@example.com' -Role admin -Verbose } catch { $_ }
                try { Get-SqlCockpitUsage -Verbose } catch { $_ }
                try { Get-SqlCockpitTeamMember -TenantId 'bad' -Verbose } catch { $_ }
            } *>&1

            $streams | Should -Not -BeNullOrEmpty
            $text = ($streams | Out-String -Width 4096) +
                ($streams | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.ToString() } } | Out-String) +
                ($Error | Out-String -Width 4096) +
                ($Error | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.ToString(); $_.TargetObject | Out-String } } | Out-String)
            $streams | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | Should -Not -BeNullOrEmpty
            @($streams | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should -BeGreaterOrEqual 3
            $text | Should -Not -Match ([regex]::Escape($script:KeyText))
            $text | Should -Not -Match 'TOPSECRETVALUE'
        }

        It 'Keeps the key out of the module''s visible variables' {
            $null = Connect-SqlCockpit -ApiKey (New-TestSecureString $script:KeyText) -SkipCheck
            $dump = & (Get-Module SqlCockpit.Portal) { Get-Variable -Scope Script | Format-List * | Out-String -Width 4096 }
            $dump | Should -Not -Match 'TOPSECRETVALUE'
            $connection = & (Get-Module SqlCockpit.Portal) { $script:Connection }
            $connection.ApiKey | Should -BeOfType [securestring]
        }
    }
}
