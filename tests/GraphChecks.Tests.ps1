BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-HygieneModuleForTest
    $script:GA = '62e90394-69f5-4237-9190-012177145e10'
    $script:UA = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
    $script:E5 = 'c7df2760-2c81-4ef7-b578-5b5392b571df'
    function script:Role { param($Principal, $RoleId) [pscustomobject]@{ principalId = $Principal; roleDefinitionId = $RoleId; directoryScopeId = '/' } }
    function script:SignIn { param($Id, $When) [pscustomobject]@{ id = $Id; lastSignInDateTime = $When } }
}

Describe 'M365-01 users without MFA' {
    It 'flags enabled members that are not registered; ignores guests and disabled users' {
        $s = New-TestSnapshot -Graph @{
            users               = @((New-TestGraphUser -Upn 'alice@corp.example' -Id 'a'), (New-TestGraphUser -Upn 'bob@corp.example' -Id 'b'),
                (New-TestGraphUser -Upn 'off@corp.example' -Id 'c' -Enabled $false), (New-TestGraphUser -Upn 'ext_guest#EXT#@corp.example' -Id 'd' -UserType 'Guest'),
                (New-TestGraphUser -Upn 'carol@corp.example' -Id 'e'))
            registrationDetails = @([pscustomobject]@{ id = 'a'; userPrincipalName = 'alice@corp.example'; isMfaRegistered = $true },
                [pscustomobject]@{ id = 'e'; userPrincipalName = 'carol@corp.example'; isMfaRegistered = $false })
        }
        @((Get-TestFinding -Snapshot $s -CheckId 'M365-01').Identity | Sort-Object) | Should -Be @('bob@corp.example', 'carol@corp.example')
    }
}

Describe 'M365-02 unused licenses' {
    It 'flags unassigned seats, licensed disabled users and licensed inactive users' {
        $s = New-TestSnapshot -Graph @{
            users          = @((New-TestGraphUser -Upn 'alice@corp.example' -Id 'a' -Licenses $E5), (New-TestGraphUser -Upn 'off@corp.example' -Id 'b' -Enabled $false -Licenses $E5),
                (New-TestGraphUser -Upn 'idle@corp.example' -Id 'c' -Licenses $E5), (New-TestGraphUser -Upn 'edge@corp.example' -Id 'd' -Licenses $E5),
                (New-TestGraphUser -Upn 'nolic@corp.example' -Id 'e'))
            signIns        = @((SignIn 'a' (DaysAgo 1)), (SignIn 'b' (DaysAgo 1)), (SignIn 'c' (DaysAgo 91)), (SignIn 'd' (DaysAgo 90)), (SignIn 'e' (DaysAgo 400)))
            subscribedSkus = @([pscustomobject]@{ skuId = $E5; skuPartNumber = 'ENTERPRISEPREMIUM'; consumedUnits = 4; enabledUnits = 10 },
                [pscustomobject]@{ skuId = 'x'; skuPartNumber = 'FULL'; consumedUnits = 5; enabledUnits = 5 })
        }
        $f = Get-TestFinding -Snapshot $s -CheckId 'M365-02'
        @($f.Identity | Sort-Object) | Should -Be @('ENTERPRISEPREMIUM', 'idle@corp.example', 'off@corp.example')
        ($f | Where-Object Identity -eq 'ENTERPRISEPREMIUM').Detail | Should -Be '6 of 10 seats unassigned.'
    }
    It 'reports the inactivity part as not evaluated when sign-in data is unavailable' {
        $s = New-TestSnapshot -Graph @{
            users          = @(New-TestGraphUser -Upn 'off@corp.example' -Id 'b' -Enabled $false -Licenses $E5)
            signIns        = (New-TestDataset -Items @() -Status 'unavailable' -Message 'premium license')
            subscribedSkus = @()
        }
        $f = Get-TestFinding -Snapshot $s -CheckId 'M365-02'
        ($f | Where-Object Status -eq 'NotEvaluated').Detail | Should -Match 'sign-in data.*premium license'
        ($f | Where-Object Status -eq 'Finding').Identity | Should -Be 'off@corp.example'
    }
    It 'flags a licensed user with no sign-in and no creation date' {
        $s = New-TestSnapshot -Graph @{
            users          = @(New-TestGraphUser -Upn 'old@corp.example' -Id 'o' -Licenses $E5 -Created $null)
            signIns        = @(SignIn 'o' $null)
            subscribedSkus = @()
        }
        $f = Get-TestFinding -Snapshot $s -CheckId 'M365-02'
        $f.Identity | Should -Be 'old@corp.example'
        $f.Detail | Should -Be 'Licensed but inactive. No activity and no creation date recorded.'
    }
}

Describe 'M365-03 Global Administrator count' {
    It 'flags 1 and 5 active Global Admins, not 2 or 4' {
        $count = { param($n) New-TestSnapshot -Graph @{ roleAssignments = @(1..$n | ForEach-Object { Role "p$_" $GA }) } }
        (Get-TestFinding -Snapshot (& $count 1) -CheckId 'M365-03').Detail | Should -Be '1 active Global Administrators; expected 2 to 4.'
        (Get-TestFinding -Snapshot (& $count 2) -CheckId 'M365-03').Count | Should -Be 0
        (Get-TestFinding -Snapshot (& $count 4) -CheckId 'M365-03').Count | Should -Be 0
        (Get-TestFinding -Snapshot (& $count 5) -CheckId 'M365-03').Count | Should -Be 1
    }
    It 'counts a principal once and ignores other roles' {
        $dup = New-TestSnapshot -Graph @{ roleAssignments = @((Role 'p1' $GA), (Role 'p1' $GA), (Role 'p2' $UA)) }
        (Get-TestFinding -Snapshot $dup -CheckId 'M365-03').Detail | Should -Match '^1 active'
    }
}

Describe 'M365-04 permanent privileged roles' {
    It 'flags standing assignments without an eligibility for the same role' {
        $s = New-TestSnapshot -Graph @{
            users           = @((New-TestGraphUser -Upn 'alice@corp.example' -Id 'a'), (New-TestGraphUser -Upn 'bob@corp.example' -Id 'b'))
            roleAssignments = @((Role 'a' $GA), (Role 'b' $GA), (Role 'b' '88d8e3e3-8f55-4a1e-953a-9b9898b8876b'))
            roleEligibility = @(Role 'b' $GA)
        }
        $f = Get-TestFinding -Snapshot $s -CheckId 'M365-04'
        $f.Identity | Should -Be 'alice@corp.example'
        $f[0].Detail | Should -Be 'Standing Global Administrator assignment with no PIM eligibility for the same role.'
    }
    It 'is not evaluated without PIM eligibility data' {
        $s = New-TestSnapshot -Graph @{ roleAssignments = @(Role 'a' $GA); roleEligibility = (New-TestDataset -Items @() -Status 'unavailable' -Message 'P2 required') }
        $f = Get-TestFinding -Snapshot $s -CheckId 'M365-04'
        $f[0].Status | Should -Be 'NotEvaluated'
        $f[0].Detail | Should -Match 'P2 required'
    }
    It 'falls back to the principal id when users were not collected' {
        $s = New-TestSnapshot -Graph @{ roleAssignments = @(Role 'a' $GA); roleEligibility = @() }
        (Get-TestFinding -Snapshot $s -CheckId 'M365-04').Identity | Should -Be 'a'
    }
}

Describe 'M365-05 stale guests' {
    It 'flags pending invitations over 30 days and accepted guests idle over 60 days' {
        $s = New-TestSnapshot -Graph @{
            users   = @(
                (New-TestGraphUser -Upn 'p31#EXT#' -Id 'g1' -UserType Guest -ExternalState 'PendingAcceptance' -ExternalStateChanged (DaysAgo 31)),
                (New-TestGraphUser -Upn 'p30#EXT#' -Id 'g2' -UserType Guest -ExternalState 'PendingAcceptance' -ExternalStateChanged (DaysAgo 30)),
                (New-TestGraphUser -Upn 'idle#EXT#' -Id 'g3' -UserType Guest -ExternalState 'Accepted'),
                (New-TestGraphUser -Upn 'active#EXT#' -Id 'g4' -UserType Guest -ExternalState 'Accepted'),
                (New-TestGraphUser -Upn 'member@corp.example' -Id 'm1'))
            signIns = @((SignIn 'g3' (DaysAgo 61)), (SignIn 'g4' (DaysAgo 60)), (SignIn 'm1' (DaysAgo 300)))
        }
        @((Get-TestFinding -Snapshot $s -CheckId 'M365-05').Identity | Sort-Object) | Should -Be @('idle#EXT#', 'p31#EXT#')
    }
    It 'still flags pending invitations when sign-in data is unavailable' {
        $s = New-TestSnapshot -Graph @{
            users   = @(New-TestGraphUser -Upn 'p90#EXT#' -Id 'g1' -UserType Guest -ExternalState 'PendingAcceptance' -ExternalStateChanged (DaysAgo 90))
            signIns = (New-TestDataset -Items @() -Status 'unavailable' -Message 'no P1')
        }
        $f = Get-TestFinding -Snapshot $s -CheckId 'M365-05'
        ($f | Where-Object Status -eq 'Finding').Identity | Should -Be 'p90#EXT#'
        @($f | Where-Object Status -eq 'NotEvaluated').Count | Should -Be 1
    }
    It 'flags an accepted guest with no sign-in and no creation date' {
        $s = New-TestSnapshot -Graph @{
            users   = @(New-TestGraphUser -Upn 'old#EXT#' -Id 'g1' -UserType Guest -ExternalState 'Accepted' -Created $null)
            signIns = @(SignIn 'g1' $null)
        }
        (Get-TestFinding -Snapshot $s -CheckId 'M365-05').Identity | Should -Be 'old#EXT#'
    }
}
