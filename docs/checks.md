# Checks

All age thresholds are **strict**: an object is stale when the days since its last activity are *greater than* the
threshold, counted back from the snapshot's `collectedAt` (never from the current clock). An object that never had any
activity is judged by its creation date instead; if neither date is recorded (Graph leaves `createdDateTime` empty for
some old accounts) the object is reported as stale with "No activity and no creation date recorded." Settings live in `src/HygieneToolkit/Data/defaults.psd1` and can be
overridden per run with `Invoke-HygieneAudit -Settings @{ ... }`.

A check whose data was not collected, or whose collector call failed, returns one **Not evaluated** finding that
names the missing dataset and the error. It never returns an empty (clean-looking) result.

| Id | What it flags | Why it matters | Setting (default) | Severity |
|---|---|---|---|---|
| AD-01 | Enabled users with no logon in more than N days; never-logged-on users created more than N days ago | Dormant accounts are easy to take over unnoticed | `StaleUserDays` (90) | Medium |
| AD-02 | Enabled computers with no logon in more than N days | Orphaned computer accounts keep valid credentials | `StaleComputerDays` (90) | Low |
| AD-03 | Enabled users with `PasswordNeverExpires` (managed service accounts are not user objects) | Long-lived passwords get cracked or reused | — | Medium |
| AD-04 | Disabled or inactive members of privileged groups (nesting path shown); groups with more than N user members | Privileged membership should be small and current | `PrivilegedGroups`, `PrivilegedGroupMaxMembers` (5), `StaleUserDays` | Medium |
| AD-05 | Enabled users with a servicePrincipalName (krbtgt excluded) | Their service tickets can be requested and cracked offline (T1558.003) | — | Medium; High if privileged |
| AD-06 | Enabled users with Kerberos pre-authentication disabled | AS-REP roasting (T1558.004) | — | High |
| AD-07 | Computers and users trusted for unconstrained delegation, domain controllers excluded | A compromised host can impersonate any user who authenticates to it | — | High |
| M365-01 | Enabled member users not registered for MFA | Password-only accounts | — | Medium |
| M365-02 | SKUs with unassigned seats; licenses on disabled users; licenses on users with no sign-in in more than N days | Cost, and inactive licensed accounts | `LicenseInactiveDays` (90) | Low / Medium |
| M365-03 | Fewer than Min or more than Max active Global Administrators | No redundancy, or too much standing power | `GlobalAdminMin` (2), `GlobalAdminMax` (4) | Medium |
| M365-04 | Active assignments of the roles in `PrivilegedRoles` with no PIM eligibility for the same principal and role | Standing admin access instead of just-in-time | `PrivilegedRoles` | Medium |
| M365-05 | Guest invitations pending more than N days; accepted guests with no sign-in in more than M days | Forgotten external access | `GuestPendingDays` (30), `GuestInactiveDays` (60) | Low |

When sign-in data is unavailable (no Microsoft Entra ID P1), M365-02 still reports unassigned seats and disabled
licensed users, and M365-05 still reports pending invitations. The inactivity part is reported as **Not evaluated**.

Each finding in the report links to the reference in the check catalog (`Private/Catalog.ps1`) and gives a one-line
remediation.
