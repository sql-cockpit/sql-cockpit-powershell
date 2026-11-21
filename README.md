# SqlCockpit.Portal

The official PowerShell module for the SQL Cockpit portal API. Use it to check your plan, manage who is on each tenant's team, list Agents and instances, and open support tickets, all from PowerShell.

It talks to `https://portal.sql-cockpit.com/api/portal/v1` with a portal API key. It runs on Windows PowerShell 5.1 and PowerShell 7 on Windows, macOS and Linux, and has no dependencies.

This module is for your portal account. It is separate from `Invoke-SqlCockpit.ps1`, which drives the SQL Cockpit Engine; the two do not share command names.

## Install

With the install script (PowerShell 7 or Windows PowerShell 5.1):

```powershell
irm https://raw.githubusercontent.com/sql-cockpit/sql-cockpit-powershell/main/install.ps1 | iex
```

To pick a release:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/sql-cockpit/sql-cockpit-powershell/main/install.ps1))) -Version 0.1.0
```

The script fetches the tagged release (with `git` if you have it, otherwise the release zip), copies it to your user module folder and checks the manifest with `Test-ModuleManifest`:

| Platform | Folder |
| --- | --- |
| Windows | `Documents\PowerShell\Modules` and `Documents\WindowsPowerShell\Modules` (both, unless you pass `-CurrentEditionOnly`) |
| macOS, Linux | `~/.local/share/powershell/Modules` |

Or by hand, from a clone:

```powershell
git clone --branch v0.1.0 https://github.com/sql-cockpit/sql-cockpit-powershell.git
Import-Module ./sql-cockpit-powershell/SqlCockpit.Portal/SqlCockpit.Portal.psd1
```

To have it load by name, copy the `SqlCockpit.Portal` folder into one of the folders in `$env:PSModulePath`, or run `./install.ps1 -SourcePath ./SqlCockpit.Portal` from the clone.

The module is not on the PowerShell Gallery.

## Connect

Create an API key in the portal under **Settings > Developer access**, then:

```powershell
Import-Module SqlCockpit.Portal
Connect-SqlCockpit
```

You paste the key at a prompt that does not echo it. The module checks it with `GET /account` and keeps it for the session as a `SecureString`. Nothing is written to disk. In a script, pass a `SecureString`:

```powershell
Connect-SqlCockpit -ApiKey (Get-Secret -Name SqlCockpitApiKey)
```

There is no way to pass the key as a plain string, so it stays out of your history. `Disconnect-SqlCockpit` forgets it. To revoke the key itself, delete it in the portal.

## Commands

| Command | HTTP operation |
| --- | --- |
| `Connect-SqlCockpit [-ApiKey <SecureString>] [-PortalUrl <string>] [-SkipCheck]` | `GET /account` (unless `-SkipCheck`) |
| `Disconnect-SqlCockpit` | none |
| `Get-SqlCockpitAccount` | `GET /account` |
| `Get-SqlCockpitUsage` | `GET /usage` |
| `Get-SqlCockpitApiKey` | `GET /api-keys` |
| `Get-SqlCockpitTenant` | `GET /tenants` |
| `Get-SqlCockpitTeamMember -TenantId [-AsTeam]` | `GET /tenants/{tenantId}/members` |
| `Add-SqlCockpitTeamMember -TenantId -Name -Email -Role` | `POST /tenants/{tenantId}/members` |
| `Set-SqlCockpitTeamMemberRole -TenantId -MembershipId -Role [-PassThru]` | `PATCH /tenants/{tenantId}/members/{membershipId}` with `confirm: true` |
| `Remove-SqlCockpitTeamMember -TenantId -MembershipId [-PassThru]` | `DELETE /tenants/{tenantId}/members/{membershipId}` with `confirm: true` |
| `Send-SqlCockpitTeamMemberInvite -TenantId -MembershipId [-PassThru]` | `POST /tenants/{tenantId}/members/{membershipId}/resend` |
| `Get-SqlCockpitAgent [-TenantId] [-Status]` | `GET /agents?tenant_id=&status=` |
| `Get-SqlCockpitInstance [-TenantId]` | `GET /instances?tenant_id=` |
| `Get-SqlCockpitSupportTicket [-Status]` | `GET /support-tickets?status=` |
| `Get-SqlCockpitSupportTicket -TicketId` | `GET /support-tickets/{ticketId}` |
| `New-SqlCockpitSupportTicket -Subject -Message [-TenantId] [-AgentId]` | `POST /support-tickets` |

Roles: `admin`, `developer`, `operator`, `read-only`. Agent statuses: `pending`, `active`, `revoked`, `suspended`. Ticket statuses: `open`, `pending`, `sent`, `waiting_on_customer`, `resolved`, `closed`.

`Get-Help <command> -Full` shows the details and examples for each one.

## Examples

```powershell
# Your plan, and what you have used of it
Get-SqlCockpitAccount
Get-SqlCockpitUsage

# The team of every tenant you can reach
Get-SqlCockpitTenant | Get-SqlCockpitTeamMember

# Add people from a CSV file with Name, Email and Role columns
Import-Csv .\people.csv | Add-SqlCockpitTeamMember -TenantId $tenantId

# Resend the set-password email to everyone still pending
Get-SqlCockpitTeamMember -TenantId $tenantId |
    Where-Object Status -eq 'pending_password' |
    Send-SqlCockpitTeamMemberInvite

# See who would be removed, without removing anyone
Get-SqlCockpitTeamMember -TenantId $tenantId |
    Where-Object Email -like '*@contractor.example' |
    Remove-SqlCockpitTeamMember -WhatIf

# Make someone an admin from a script (no prompt)
Set-SqlCockpitTeamMemberRole -TenantId $tenantId -MembershipId $membershipId -Role admin -Confirm:$false

# Suspended Agents across all tenants
Get-SqlCockpitTenant | Get-SqlCockpitAgent -Status suspended

# Instances that have not applied their latest configuration
Get-SqlCockpitInstance | Where-Object { $_.AppliedRevision -ne $_.Revision }

# Tickets waiting on you, in full
Get-SqlCockpitSupportTicket -Status waiting_on_customer | Get-SqlCockpitSupportTicket

# Open a high-priority ticket about one Agent
Get-SqlCockpitAgent -TenantId $tenantId |
    Where-Object Name -eq 'db01' |
    New-SqlCockpitSupportTicket -Subject 'Agent offline' -Message 'db01 stopped reporting at 09:00.'
```

`examples/first-call.ps1` connects and lists your account, tenants and active Agents.

Commands return objects with type names such as `SqlCockpit.Tenant`, `SqlCockpit.TeamMember` and `SqlCockpit.Agent`, with PascalCase properties (`TenantId`, `MembershipId`, `LastSeenAt`) and dates as UTC `DateTime`. IDs bind from the pipeline by property name, which is what makes the pipelines above work.

`Set-SqlCockpitTeamMemberRole` and `Remove-SqlCockpitTeamMember` ask before they change anything. Every command that changes something supports `-WhatIf`, which sends nothing.

## Configuration

The module looks for a key in this order and uses the first it finds:

1. `Connect-SqlCockpit` in this session.
2. The `SQL_COCKPIT_API_KEY` environment variable (portal address from `SQL_COCKPIT_PORTAL_URL`).
3. The SQL Cockpit CLI's config file, `~/.sqlcockpit.conf` (`%USERPROFILE%\.sqlcockpit.conf` on Windows). The module reads it and never writes it.

For 2 and 3 the profile and address resolve as the CLI does them: the profile is the one named under `[default]`, or `SQL_COCKPIT_PROFILE` if set; the key is that profile's `api_key`, overridden by `SQL_COCKPIT_API_KEY`; the address is the profile's `portal_url`, overridden by `SQL_COCKPIT_PORTAL_URL`, then `https://portal.sql-cockpit.com`.

```ini
[default]
profile = work

[profile work]
api_key = sco_...
portal_url = https://portal.sql-cockpit.com
```

`Connect-SqlCockpit` without `-PortalUrl` uses `SQL_COCKPIT_PORTAL_URL`, then the production portal.

## API keys cannot create keys

`Get-SqlCockpitApiKey` lists your keys (status and last four characters, never the value). Creating and revoking keys needs the `keys:write` scope, which an API key never holds; only a person signing in through OAuth can grant it. So this module has no command for either. Manage keys in the portal under **Settings > Developer access**.

## Errors

Errors are terminating, with the portal's code in the error ID and a matching category:

| HTTP | Error ID example | Category |
| --- | --- | --- |
| 401 | `SqlCockpit.unauthenticated` | AuthenticationError |
| 403 | `SqlCockpit.forbidden`, `SqlCockpit.insufficient_scope` | PermissionDenied |
| 403 | `SqlCockpit.plan_limit` | LimitsExceeded |
| 404 | `SqlCockpit.not_found` | ObjectNotFound |
| 400, 422 | `SqlCockpit.validation_failed` | InvalidArgument |
| 429 | `SqlCockpit.rate_limited` | LimitsExceeded |
| 5xx | `SqlCockpit.server_error` | ResourceUnavailable |
| none | `SqlCockpit.connection_error`, `SqlCockpit.timeout` | ConnectionError |

A malformed ID fails with `SqlCockpit.invalid_argument` before anything is sent. Field messages from the portal are part of the message, and `$_.Exception.Fields` holds them by field. `$_.Exception.StatusCode` and `$_.Exception.RetryAfter` are there too.

```powershell
try { Add-SqlCockpitTeamMember -TenantId $tenantId -Name 'Ada' -Email ada@example.com -Role admin }
catch { $_.FullyQualifiedErrorId; $_.Exception.Fields }
```

## Safety

- HTTPS only. `http://` is allowed for `localhost`, `127.0.0.1` and `[::1]`.
- Redirects are never followed; a 3xx answer is an error, so the key never goes to another address.
- Responses over 2 MiB are not read.
- IDs are checked to be UUIDs before any request.
- GET requests are retried at most twice on 429 and 5xx, waiting for `Retry-After` (at most 30 seconds). Writes are never retried.
- The key lives in a `SecureString`. It is turned into text only inside the function that sends the request, and never appears in output, `-Verbose` or `-Debug` output, errors or `$Error`. If the portal ever echoed it back, it is replaced with `[redacted]`.
- Requests send `User-Agent: SqlCockpit.Portal/<version> PowerShell/<version>`.

## Development

Tests use Pester 5 and mock the HTTP layer; `tests/Transport.Tests.ps1` also runs the real HTTP code against a local listener on 127.0.0.1.

```powershell
Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser
Invoke-Pester ./tests -Output Detailed

Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path ./SqlCockpit.Portal -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

CI runs both on Ubuntu and Windows with PowerShell 7, and on Windows PowerShell 5.1.

## License

MIT. See [LICENSE](LICENSE).
