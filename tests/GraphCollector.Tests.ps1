BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Install-HygieneStub
    Import-HygieneModuleForTest
    function script:New-MgUserObject {
        param($Id, $Upn, $SignIn)
        $activity = $null
        if ($SignIn) { $activity = [pscustomobject]@{ LastSignInDateTime = [datetime]::SpecifyKind([datetime]$SignIn, 'Utc') } }
        [pscustomobject]@{ Id = $Id; UserPrincipalName = $Upn; DisplayName = $Upn; UserType = 'Member'; AccountEnabled = $true
            CreatedDateTime = [datetime]'2025-01-01'; ExternalUserState = $null; ExternalUserStateChangeDateTime = $null
            AssignedLicenses = @([pscustomobject]@{ SkuId = [guid]'c7df2760-2c81-4ef7-b578-5b5392b571df' })
            SignInActivity = $activity
        }
    }
    Mock -ModuleName HygieneToolkit Get-MgUser { New-MgUserObject 'u1' 'alice@corp.example' '2026-09-29 10:00:00'; New-MgUserObject 'u2' 'bob@corp.example' $null }
    Mock -ModuleName HygieneToolkit Get-MgReportAuthenticationMethodUserRegistrationDetail {
        [pscustomobject]@{ Id = 'u1'; UserPrincipalName = 'alice@corp.example'; IsMfaRegistered = $true }
    }
    Mock -ModuleName HygieneToolkit Get-MgSubscribedSku {
        [pscustomobject]@{ SkuId = [guid]'c7df2760-2c81-4ef7-b578-5b5392b571df'; SkuPartNumber = 'ENTERPRISEPREMIUM'; ConsumedUnits = 8
            PrepaidUnits = [pscustomobject]@{ Enabled = 10 }
        }
    }
    Mock -ModuleName HygieneToolkit Get-MgRoleManagementDirectoryRoleAssignment {
        [pscustomobject]@{ PrincipalId = 'u1'; RoleDefinitionId = '62e90394-69f5-4237-9190-012177145e10'; DirectoryScopeId = '/' }
    }
    Mock -ModuleName HygieneToolkit Get-MgRoleManagementDirectoryRoleEligibilitySchedule { }
}
AfterAll { Remove-HygieneStub }

Describe 'Get-HygieneGraphSnapshot' {
    It 'pages users and asks for signInActivity plus the needed properties' {
        $null = Get-HygieneGraphSnapshot
        Should -Invoke Get-MgUser -ModuleName HygieneToolkit -Times 1 -Exactly -ParameterFilter {
            $All -and ($Property -contains 'signInActivity') -and ($Property -contains 'externalUserState') -and ($Property -contains 'assignedLicenses')
        }
    }
    It 'pages the other list calls' {
        $null = Get-HygieneGraphSnapshot
        Should -Invoke Get-MgReportAuthenticationMethodUserRegistrationDetail -ModuleName HygieneToolkit -ParameterFilter { $All }
        Should -Invoke Get-MgRoleManagementDirectoryRoleAssignment -ModuleName HygieneToolkit -ParameterFilter { $All }
        Should -Invoke Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ModuleName HygieneToolkit -ParameterFilter { $All }
    }
    It 'flattens users, sign-ins, licenses and SKUs' {
        $snap = Get-HygieneGraphSnapshot
        @(($snap.users.items | Where-Object id -eq 'u1').assignedLicenses) | Should -Be @('c7df2760-2c81-4ef7-b578-5b5392b571df')
        ($snap.signIns.items | Where-Object id -eq 'u1').lastSignInDateTime | Should -Be '2026-09-29T10:00:00Z'
        ($snap.signIns.items | Where-Object id -eq 'u2').lastSignInDateTime | Should -BeNullOrEmpty
        @($snap.subscribedSkus.items)[0].enabledUnits | Should -Be 10
        @($snap.registrationDetails.items)[0].isMfaRegistered | Should -BeTrue
        $snap.roleEligibility.status | Should -Be 'ok'
        @($snap.roleEligibility.items).Count | Should -Be 0
    }
    It 'falls back without signInActivity and marks sign-ins unavailable' {
        Mock -ModuleName HygieneToolkit Get-MgUser -ParameterFilter { $Property -contains 'signInActivity' } { throw 'Neither tenant is B2C or tenant does not have premium license' }
        Mock -ModuleName HygieneToolkit Get-MgUser -ParameterFilter { $Property -notcontains 'signInActivity' } { New-MgUserObject 'u1' 'alice@corp.example' $null }
        $s = Get-HygieneGraphSnapshot
        $s.users.status | Should -Be 'ok'
        @($s.users.items).Count | Should -Be 1
        $s.signIns.status | Should -Be 'unavailable'
        $s.signIns.error | Should -Match 'premium license'
    }
    It 'marks PIM eligibility unavailable without Entra ID P2' {
        Mock -ModuleName HygieneToolkit Get-MgRoleManagementDirectoryRoleEligibilitySchedule { throw 'The tenant needs an AAD Premium 2 license.' }
        (Get-HygieneGraphSnapshot).roleEligibility.status | Should -Be 'unavailable'
    }
}
