# Changelog

## 0.1.0 - 2026-11-21

First release.

- `Connect-SqlCockpit` and `Disconnect-SqlCockpit`. The key is kept as a `SecureString` for the session; without it the module uses `SQL_COCKPIT_API_KEY` / `SQL_COCKPIT_PORTAL_URL`, then the sqlcockpit CLI's `~/.sqlcockpit.conf` (read-only, active profile or `SQL_COCKPIT_PROFILE`).
- Account: `Get-SqlCockpitAccount`, `Get-SqlCockpitUsage`, `Get-SqlCockpitApiKey` (list only; API keys cannot create or revoke keys).
- Tenants and team: `Get-SqlCockpitTenant`, `Get-SqlCockpitTeamMember`, `Add-SqlCockpitTeamMember`, `Set-SqlCockpitTeamMemberRole`, `Remove-SqlCockpitTeamMember`, `Send-SqlCockpitTeamMemberInvite`.
- Fleet: `Get-SqlCockpitAgent`, `Get-SqlCockpitInstance`.
- Support: `Get-SqlCockpitSupportTicket`, `New-SqlCockpitSupportTicket`.
- Typed output objects with table and list views; IDs bind from the pipeline.
- `-WhatIf` on every change; role changes and removals ask first.
- Terminating errors with `SqlCockpit.<code>` error IDs and matching categories.
- HTTPS only (http for localhost), no redirects, 2 MiB response cap, UUID checks before sending, GET retries on 429 and 5xx (at most two, `Retry-After` capped at 30 seconds), writes never retried.
- `install.ps1` for Windows PowerShell 5.1 and PowerShell 7.
