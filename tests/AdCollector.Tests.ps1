BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Install-HygieneStub
    Import-HygieneModuleForTest
    $script:fileTime = [datetime]::SpecifyKind([datetime]'2026-09-01 08:00:00', 'Utc').ToFileTimeUtc()
    Mock -ModuleName HygieneToolkit Get-ADUser {
        [pscustomobject]@{ SamAccountName = 'svc-sql'; DistinguishedName = 'CN=svc-sql,OU=Service,DC=corp,DC=internal'; ObjectClass = 'user'
            Enabled = $true; LastLogonTimestamp = $fileTime; WhenCreated = [datetime]'2024-01-15 10:00:00'
            PasswordNeverExpires = $true; ServicePrincipalName = @('MSSQLSvc/sql01.corp.internal:1433')
            DoesNotRequirePreAuth = $false; TrustedForDelegation = $false
        }
        [pscustomobject]@{ SamAccountName = 'newhire'; DistinguishedName = 'CN=newhire,OU=Users,DC=corp,DC=internal'; ObjectClass = 'user'
            Enabled = $true; LastLogonTimestamp = $null; WhenCreated = [datetime]'2026-09-20 10:00:00'
            PasswordNeverExpires = $false; ServicePrincipalName = $null; DoesNotRequirePreAuth = $false; TrustedForDelegation = $false
        }
    }
    Mock -ModuleName HygieneToolkit Get-ADComputer {
        [pscustomobject]@{ Name = 'DC01'; DistinguishedName = 'CN=DC01,OU=Domain Controllers,DC=corp,DC=internal'; Enabled = $true
            LastLogonTimestamp = $fileTime; WhenCreated = [datetime]'2023-05-01'; TrustedForDelegation = $true
        }
    }
    Mock -ModuleName HygieneToolkit Get-ADDomainController { [pscustomobject]@{ ComputerObjectDN = 'CN=DC01,OU=Domain Controllers,DC=corp,DC=internal' } }
    Mock -ModuleName HygieneToolkit Get-ADGroupMember -ParameterFilter { $Identity -eq 'Domain Admins' } {
        [pscustomobject]@{ DistinguishedName = 'CN=IT-Admins,OU=Groups,DC=corp,DC=internal'; SamAccountName = 'IT-Admins'; Name = 'IT-Admins'; objectClass = 'group' }
        [pscustomobject]@{ DistinguishedName = 'CN=alice,OU=Users,DC=corp,DC=internal'; SamAccountName = 'alice'; Name = 'alice'; objectClass = 'user' }
    }
    Mock -ModuleName HygieneToolkit Get-ADGroupMember -ParameterFilter { $Identity -eq 'CN=IT-Admins,OU=Groups,DC=corp,DC=internal' } {
        [pscustomobject]@{ DistinguishedName = 'CN=bob,OU=Users,DC=corp,DC=internal'; SamAccountName = 'bob'; Name = 'bob'; objectClass = 'user' }
        # A cycle back to the root group must not loop forever.
        [pscustomobject]@{ DistinguishedName = 'CN=Domain Admins,CN=Users,DC=corp,DC=internal'; SamAccountName = 'Domain Admins'; Name = 'Domain Admins'; objectClass = 'group' }
    }
    $script:snap = Get-HygieneAdSnapshot -PrivilegedGroup 'Domain Admins'
}
AfterAll { Remove-HygieneStub }

Describe 'Get-HygieneAdSnapshot' {
    It 'requests every user and exactly the needed properties' {
        $null = Get-HygieneAdSnapshot -PrivilegedGroup @()
        Should -Invoke Get-ADUser -ModuleName HygieneToolkit -Times 1 -Exactly -ParameterFilter {
            $Filter -eq '*' -and $PesterBoundParameters.ContainsKey('ResultSetSize') -and $null -eq $ResultSetSize -and
            (@(Compare-Object $Properties @('LastLogonTimestamp', 'WhenCreated', 'PasswordNeverExpires', 'ServicePrincipalName',
                            'DoesNotRequirePreAuth', 'TrustedForDelegation')).Count -eq 0)
        }
    }
    It 'requests every computer with the needed properties' {
        $null = Get-HygieneAdSnapshot -PrivilegedGroup @()
        Should -Invoke Get-ADComputer -ModuleName HygieneToolkit -Times 1 -Exactly -ParameterFilter {
            $PesterBoundParameters.ContainsKey('ResultSetSize') -and $null -eq $ResultSetSize -and
            (@(Compare-Object $Properties @('LastLogonTimestamp', 'WhenCreated', 'TrustedForDelegation')).Count -eq 0)
        }
    }
    It 'converts lastLogonTimestamp file time to ISO UTC and keeps never-logged-on as null' {
        $users = @($snap.users.items)
        ($users | Where-Object SamAccountName -eq 'svc-sql').LastLogonTimestamp | Should -Be '2026-09-01T08:00:00Z'
        ($users | Where-Object SamAccountName -eq 'newhire').LastLogonTimestamp | Should -BeNullOrEmpty
        @(($users | Where-Object SamAccountName -eq 'newhire').ServicePrincipalName).Count | Should -Be 0
    }
    It 'walks nested groups with the path and survives a cycle' {
        $members = @(@($snap.privilegedGroups.items)[0].Members)
        ($members | Where-Object SamAccountName -eq 'bob').Path | Should -Be 'Domain Admins > IT-Admins > bob'
        ($members | Where-Object SamAccountName -eq 'alice').Path | Should -Be 'Domain Admins > alice'
        $members.Count | Should -Be 2
    }
    It 'records domain controllers' {
        @($snap.domainControllers.items) | Should -Be @('CN=DC01,OU=Domain Controllers,DC=corp,DC=internal')
    }
    It 'passes -Server through' {
        $null = Get-HygieneAdSnapshot -Server 'dc01.corp.internal' -PrivilegedGroup @()
        Should -Invoke Get-ADUser -ModuleName HygieneToolkit -ParameterFilter { $Server -eq 'dc01.corp.internal' }
    }
    It 'marks a dataset unavailable when its cmdlet fails' {
        Mock -ModuleName HygieneToolkit Get-ADComputer { throw 'Unable to contact the server.' }
        $s = Get-HygieneAdSnapshot -PrivilegedGroup @()
        $s.computers.status | Should -Be 'unavailable'
        $s.computers.error | Should -Match 'Unable to contact'
        $s.users.status | Should -Be 'ok'
    }
}
