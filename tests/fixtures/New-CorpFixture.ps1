# Regenerates corp.fixture.json: a synthetic snapshot of the fictional corp.internal / corp.example organisation.
# It is built so that every check has something to report and M365-04 shows the "not evaluated" path (no Entra ID P2).
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'TestHelpers.ps1')
$E5 = 'c7df2760-2c81-4ef7-b578-5b5392b571df'
$GA = '62e90394-69f5-4237-9190-012177145e10'
$SA = '194ae4cb-b126-40b2-bd5b-6091b380977d'
$dc = New-TestAdComputer -Name 'DC01' -Delegation $true -Ou 'Domain Controllers'
function New-FixtureGroup {
    param($Group, [string[]] $Sams)
    [pscustomobject]@{ Name = $Group; Members = @($Sams | ForEach-Object {
                [pscustomobject]@{ DistinguishedName = "CN=$_,OU=Users,DC=corp,DC=internal"; SamAccountName = $_; ObjectClass = 'user'; Path = "$Group > $_" }
            })
    }
}
$snapshot = New-TestSnapshot -Ad @{
    users             = @(
        (New-TestAdUser -Sam 'alice.admin' -LastLogon (DaysAgo 2)),
        (New-TestAdUser -Sam 'bob.old' -LastLogon (DaysAgo 140)),
        (New-TestAdUser -Sam 'contractor.never' -LastLogon $null -Created (DaysAgo 200)),
        (New-TestAdUser -Sam 'svc-sql' -Spn 'MSSQLSvc/sql01.corp.internal:1433' -PasswordNeverExpires $true),
        (New-TestAdUser -Sam 'svc-backup' -Spn 'HTTP/backup01.corp.internal' -PasswordNeverExpires $true),
        (New-TestAdUser -Sam 'legacy.app' -NoPreAuth $true),
        (New-TestAdUser -Sam 'svc-web' -Delegation $true),
        (New-TestAdUser -Sam 'former.admin' -Enabled $false -LastLogon (DaysAgo 300)))
    computers         = @($dc, (New-TestAdComputer -Name 'APP01' -Delegation $true), (New-TestAdComputer -Name 'PC-OLD-17' -LastLogon (DaysAgo 180)),
        (New-TestAdComputer -Name 'PC-042'))
    domainControllers = @($dc.DistinguishedName)
    privilegedGroups  = @((New-FixtureGroup 'Domain Admins' @('alice.admin', 'svc-backup', 'former.admin')), (New-FixtureGroup 'Backup Operators' @('bob.old')))
} -Graph @{
    users               = @(
        (New-TestGraphUser -Upn 'alice@corp.example' -Id 'u-alice' -Licenses $E5),
        (New-TestGraphUser -Upn 'bob@corp.example' -Id 'u-bob' -Licenses $E5),
        (New-TestGraphUser -Upn 'carol@corp.example' -Id 'u-carol' -Licenses $E5 -Enabled $false),
        (New-TestGraphUser -Upn 'dave@corp.example' -Id 'u-dave' -Licenses $E5),
        (New-TestGraphUser -Upn 'partner_fabrikam.test#EXT#@corp.example' -Id 'g-partner' -UserType Guest -ExternalState 'Accepted' -DisplayName 'Partner (guest)'),
        (New-TestGraphUser -Upn 'pending_contoso.test#EXT#@corp.example' -Id 'g-pending' -UserType Guest -ExternalState 'PendingAcceptance' -ExternalStateChanged (DaysAgo 45) -DisplayName 'Pending (guest)'))
    signIns             = @(
        [pscustomobject]@{ id = 'u-alice'; lastSignInDateTime = (DaysAgo 1) }, [pscustomobject]@{ id = 'u-bob'; lastSignInDateTime = (DaysAgo 2) },
        [pscustomobject]@{ id = 'u-carol'; lastSignInDateTime = (DaysAgo 200) }, [pscustomobject]@{ id = 'u-dave'; lastSignInDateTime = (DaysAgo 120) },
        [pscustomobject]@{ id = 'g-partner'; lastSignInDateTime = (DaysAgo 95) }, [pscustomobject]@{ id = 'g-pending'; lastSignInDateTime = $null })
    registrationDetails = @(
        [pscustomobject]@{ id = 'u-alice'; userPrincipalName = 'alice@corp.example'; isMfaRegistered = $true },
        [pscustomobject]@{ id = 'u-bob'; userPrincipalName = 'bob@corp.example'; isMfaRegistered = $false })
    subscribedSkus      = @([pscustomobject]@{ skuId = $E5; skuPartNumber = 'ENTERPRISEPREMIUM'; consumedUnits = 4; enabledUnits = 10 })
    roleAssignments     = @(
        [pscustomobject]@{ principalId = 'u-alice'; roleDefinitionId = $GA; directoryScopeId = '/' },
        [pscustomobject]@{ principalId = 'u-bob'; roleDefinitionId = $SA; directoryScopeId = '/' })
    roleEligibility     = (New-TestDataset -Items @() -Status 'unavailable' -Message 'The tenant needs a Microsoft Entra ID P2 license.')
}
$json = ($snapshot | ConvertTo-Json -Depth 20) -replace "`r`n", "`n"
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'corp.fixture.json'), $json + "`n", (New-Object Text.UTF8Encoding($false)))
