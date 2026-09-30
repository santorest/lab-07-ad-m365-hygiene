# Lab 07 — AD & Microsoft 365 hygiene toolkit (PowerShell)

`HygieneToolkit` is a **read-only** PowerShell module that audits Active Directory and Microsoft 365 (Microsoft Entra
ID) hygiene. Collectors take a snapshot with least privilege; twelve checks run over that snapshot and produce
findings; the findings become a single self-contained HTML report (or CSV / JSON).

Status: completed. The CI results are real (see [WRITEUP.md](WRITEUP.md)). The toolkit has **never been run against a
real domain or tenant**: every check is proven in CI against synthetic snapshots, and the collectors against mocked
cmdlets. See [the example report](docs/example-report.html) built from the synthetic `corp` fixture.

## Quick start

```powershell
Import-Module ./src/HygieneToolkit/HygieneToolkit.psd1

# Active Directory: needs the ActiveDirectory module (RSAT); any authenticated domain user can read this data.
$ad = Get-HygieneAdSnapshot

# Microsoft 365: read-only Graph scopes (see docs/permissions.md).
Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, Directory.Read.All, RoleManagement.Read.Directory
$graph = Get-HygieneGraphSnapshot

New-HygieneSnapshot -Ad $ad -Graph $graph -Source 'corp' | Save-HygieneSnapshot -Path .\corp.snapshot.json

# Analysis can run anywhere, later, from the file.
$snapshot = Import-HygieneSnapshot -Path .\corp.snapshot.json
$findings = Invoke-HygieneAudit -Snapshot $snapshot
ConvertTo-HygieneHtml -Finding $findings -CollectedAt $snapshot.collectedAt -Source $snapshot.source -Path .\report.html
Export-HygieneFinding -Finding $findings -Path .\findings.csv -Format Csv
```

Either collector can be skipped: pass only `-Ad` or only `-Graph`, and the checks that need the missing data report
**Not evaluated**. Thresholds can be overridden, for example `Invoke-HygieneAudit -Snapshot $snapshot -Settings
@{ StaleUserDays = 60 }` (defaults in [`Data/defaults.psd1`](src/HygieneToolkit/Data/defaults.psd1)).

Snapshots contain directory data (names, group membership, sign-in dates). Treat them as sensitive; `*.snapshot.json`
is git-ignored.

## Checks

| Id | Check | Flags |
|---|---|---|
| AD-01 | Stale users | Enabled users with no logon in more than 90 days (or never, and created more than 90 days ago) |
| AD-02 | Stale computers | Enabled computers with no logon in more than 90 days |
| AD-03 | Passwords that never expire | Enabled users with `PasswordNeverExpires` |
| AD-04 | Privileged group membership | Disabled or inactive members (with nesting path) and groups above 5 members |
| AD-05 | Kerberoastable users | Enabled users with an SPN; High when the user is privileged |
| AD-06 | AS-REP roastable users | Kerberos pre-authentication disabled |
| AD-07 | Unconstrained delegation | Computers and users trusted for delegation, domain controllers excluded |
| M365-01 | Users without MFA | Enabled members not registered for MFA |
| M365-02 | Unused licenses | Unassigned seats; licenses on disabled or inactive users |
| M365-03 | Global Administrator count | Fewer than 2 or more than 4 active Global Administrators |
| M365-04 | Permanent privileged roles | Standing privileged role assignments with no PIM eligibility |
| M365-05 | Stale guests | Invitations pending more than 30 days; guests with no sign-in in more than 60 days |

Details, thresholds and remediation: [docs/checks.md](docs/checks.md). Permissions and licensing:
[docs/permissions.md](docs/permissions.md).

## How it is tested

- **Pester 5.7.1** on Windows PowerShell 5.1, PowerShell 7 on Windows and PowerShell 7 on Linux (CI matrix). Every
  check has positive cases and near misses (for example a logon exactly 90 days before collection is *not* stale).
- **Collectors** are tested with mocks on stub cmdlets, including the exact properties they request, paging, and the
  "unavailable" path when a call fails for permissions or licensing.
- A **read-only guard** parses the module and fails if it calls any AD or Graph cmdlet other than `Get-*`, or
  `Invoke-MgGraphRequest`.
- The **example report** is regenerated in every test run and must match `docs/example-report.html` byte for byte.
- **PSScriptAnalyzer 1.23.0** with zero findings, and **gitleaks** over the full history.

Run locally: `./scripts/Install-TestDependencies.ps1` then `./scripts/Invoke-Tests.ps1`. The Pester and
PSScriptAnalyzer versions are pinned in `scripts/Install-TestDependencies.ps1` and bumped by hand.

## Limits

- Never run against a real domain or tenant; no findings on real data are claimed.
- `lastLogonTimestamp` replicates with a lag of up to about 14 days, so "stale" is approximate by design.
- Graph checks depend on Microsoft Entra ID P1 (sign-in activity) and P2 (PIM eligibility); without them the affected
  checks report "not evaluated".
- M365-04 is a heuristic: a principal that has both a standing and an eligible assignment for the same role is not
  flagged.
- The Graph collector is modelled on the Microsoft.Graph PowerShell SDK 2.x cmdlets; it was not run against the SDK.

## License

[MIT](LICENSE)
