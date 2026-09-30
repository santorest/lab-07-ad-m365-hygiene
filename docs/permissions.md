# Permissions and licensing

The toolkit only reads. A test parses the module and fails CI if any AD or Graph cmdlet other than `Get-*` (or a raw
`Invoke-MgGraphRequest`) appears in the code.

## Active Directory

`Get-HygieneAdSnapshot` calls `Get-ADUser`, `Get-ADComputer`, `Get-ADGroupMember` and `Get-ADDomainController` from
the ActiveDirectory module (RSAT). The attributes it reads (`lastLogonTimestamp`, `whenCreated`,
`userAccountControl` flags, `servicePrincipalName`, group membership) are readable by **any authenticated domain
user** by default, so no administrative rights are needed. Use `-Server` to target a specific domain controller.

## Microsoft Graph

`Get-HygieneGraphSnapshot` needs a Graph session with these delegated (or application) permissions:

| Permission | Used for |
|---|---|
| `User.Read.All` | Users, guests, license assignments |
| `AuditLog.Read.All` | `signInActivity` and the authentication-method registration report |
| `Directory.Read.All` | Subscribed SKUs |
| `RoleManagement.Read.Directory` | Active role assignments and PIM eligibility schedules |

With delegated permissions, the signed-in user also needs a directory role that can read the same data (for example
Global Reader). The permissions need admin consent once.

Licensing:

- `signInActivity` requires Microsoft Entra ID P1. Without it, the collector retries without sign-in data and marks
  `graph.signIns` unavailable.
- PIM eligibility requires Microsoft Entra ID P2. Without it, `graph.roleEligibility` is unavailable and M365-04 reports
  Not evaluated.

## Handling snapshots

A snapshot holds account names, group membership and sign-in dates. Store it like any other directory export: keep it
off shared drives, delete it when the report is done, and never commit it (`*.snapshot.json` is git-ignored).
