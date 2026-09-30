BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-HygieneModuleForTest
    function script:New-Group {
        param($Name, [string[]] $Sams)
        [pscustomobject]@{ Name = $Name; Members = @($Sams | ForEach-Object {
                    [pscustomobject]@{ DistinguishedName = "CN=$_,OU=Users,DC=corp,DC=internal"; SamAccountName = $_; ObjectClass = 'user'; Path = "$Name > $_" }
                })
        }
    }
}

Describe 'AD-01 stale users' {
    It 'flags 91 days, not 90 or 89, and never-logged-on accounts older than the threshold' {
        $s = New-TestSnapshot -Ad @{ users = @(
                (New-TestAdUser -Sam 'd89' -LastLogon (DaysAgo 89)), (New-TestAdUser -Sam 'd90' -LastLogon (DaysAgo 90)),
                (New-TestAdUser -Sam 'd91' -LastLogon (DaysAgo 91)), (New-TestAdUser -Sam 'never-old' -LastLogon $null -Created (DaysAgo 200)),
                (New-TestAdUser -Sam 'never-new' -LastLogon $null -Created (DaysAgo 10)),
                (New-TestAdUser -Sam 'disabled-old' -Enabled $false -LastLogon (DaysAgo 300)))
        }
        $f = Get-TestFinding -Snapshot $s -CheckId 'AD-01'
        @($f.Identity | Sort-Object) | Should -Be @('d91', 'never-old')
        ($f | Where-Object Identity -eq 'd91').Detail | Should -Be 'Last activity 91 days before collection.'
    }
    It 'honours a threshold override' {
        $s = New-TestSnapshot -Ad @{ users = @(New-TestAdUser -Sam 'd40' -LastLogon (DaysAgo 40)) }
        (Get-TestFinding -Snapshot $s -CheckId 'AD-01' -Settings @{ StaleUserDays = 30 }).Identity | Should -Be 'd40'
    }
    It 'handles a single user' {
        $s = New-TestSnapshot -Ad @{ users = @(New-TestAdUser -Sam 'solo' -LastLogon (DaysAgo 100)) }
        (Get-TestFinding -Snapshot $s -CheckId 'AD-01').Count | Should -Be 1
    }
}

Describe 'AD-02 stale computers' {
    It 'flags enabled computers past the threshold only' {
        $s = New-TestSnapshot -Ad @{ computers = @(
                (New-TestAdComputer -Name 'PC90' -LastLogon (DaysAgo 90)), (New-TestAdComputer -Name 'PC91' -LastLogon (DaysAgo 91)),
                (New-TestAdComputer -Name 'PCOFF' -Enabled $false -LastLogon (DaysAgo 400)))
        }
        (Get-TestFinding -Snapshot $s -CheckId 'AD-02').Identity | Should -Be 'PC91'
    }
}

Describe 'AD-03 passwords that never expire' {
    It 'flags enabled user objects only' {
        $s = New-TestSnapshot -Ad @{ users = @(
                (New-TestAdUser -Sam 'svc-app' -PasswordNeverExpires $true),
                (New-TestAdUser -Sam 'old-svc' -PasswordNeverExpires $true -Enabled $false),
                (New-TestAdUser -Sam 'gmsa-web$' -PasswordNeverExpires $true -ObjectClass 'msDS-GroupManagedServiceAccount'),
                (New-TestAdUser -Sam 'alice'))
        }
        (Get-TestFinding -Snapshot $s -CheckId 'AD-03').Identity | Should -Be 'svc-app'
    }
}

Describe 'AD-04 privileged groups' {
    It 'flags disabled and stale members with their path, not active ones' {
        $s = New-TestSnapshot -Ad @{
            users            = @((New-TestAdUser -Sam 'alice'), (New-TestAdUser -Sam 'olddba' -LastLogon (DaysAgo 120)), (New-TestAdUser -Sam 'gone' -Enabled $false))
            privilegedGroups = @(New-Group 'Domain Admins' @('alice', 'olddba', 'gone'))
        }
        $f = Get-TestFinding -Snapshot $s -CheckId 'AD-04'
        @($f.Identity | Sort-Object) | Should -Be @('gone', 'olddba')
        ($f | Where-Object Identity -eq 'gone').Detail | Should -Be 'Disabled account is still a member (Domain Admins > gone).'
    }
    It 'flags a group above the member threshold, not at it' {
        $five = New-TestSnapshot -Ad @{ users = @(1..5 | ForEach-Object { New-TestAdUser -Sam "a$_" }); privilegedGroups = @(New-Group 'Domain Admins' @(1..5 | ForEach-Object { "a$_" })) }
        $six = New-TestSnapshot -Ad @{ users = @(1..6 | ForEach-Object { New-TestAdUser -Sam "a$_" }); privilegedGroups = @(New-Group 'Domain Admins' @(1..6 | ForEach-Object { "a$_" })) }
        (Get-TestFinding -Snapshot $five -CheckId 'AD-04').Count | Should -Be 0
        $f = @(Get-TestFinding -Snapshot $six -CheckId 'AD-04')
        $f.Count | Should -Be 1
        $f[0].ObjectType | Should -Be 'Group'
        $f[0].Detail | Should -Be '6 members; threshold 5.'
    }
}

Describe 'AD-05 kerberoastable users' {
    It 'flags enabled users with an SPN, High when privileged, and skips krbtgt' {
        $s = New-TestSnapshot -Ad @{
            users            = @((New-TestAdUser -Sam 'svc-sql' -Spn 'MSSQLSvc/sql01:1433'), (New-TestAdUser -Sam 'svc-da' -Spn 'HTTP/app01'),
                (New-TestAdUser -Sam 'krbtgt' -Spn 'kadmin/changepw'), (New-TestAdUser -Sam 'svc-off' -Spn 'HTTP/x' -Enabled $false),
                (New-TestAdUser -Sam 'alice'))
            privilegedGroups = @(New-Group 'Domain Admins' @('svc-da'))
        }
        $f = Get-TestFinding -Snapshot $s -CheckId 'AD-05'
        @($f.Identity | Sort-Object) | Should -Be @('svc-da', 'svc-sql')
        ($f | Where-Object Identity -eq 'svc-da').Severity | Should -Be 'High'
        ($f | Where-Object Identity -eq 'svc-sql').Severity | Should -Be 'Medium'
    }
    It 'still runs (Medium only) when privileged groups are unavailable' {
        $s = New-TestSnapshot -Ad @{ users = @(New-TestAdUser -Sam 'svc-sql' -Spn 'MSSQLSvc/sql01:1433'); privilegedGroups = (New-TestDataset -Items @() -Status 'unavailable' -Message 'x') }
        (Get-TestFinding -Snapshot $s -CheckId 'AD-05').Severity | Should -Be 'Medium'
    }
}

Describe 'AD-06 AS-REP roastable users' {
    It 'flags enabled users without pre-authentication' {
        $s = New-TestSnapshot -Ad @{ users = @((New-TestAdUser -Sam 'legacy' -NoPreAuth $true), (New-TestAdUser -Sam 'off' -NoPreAuth $true -Enabled $false), (New-TestAdUser -Sam 'alice')) }
        $f = @(Get-TestFinding -Snapshot $s -CheckId 'AD-06')
        $f.Identity | Should -Be 'legacy'
        $f[0].Severity | Should -Be 'High'
    }
}

Describe 'AD-07 unconstrained delegation' {
    It 'flags computers and users trusted for delegation but not domain controllers' {
        $dc = New-TestAdComputer -Name 'DC01' -Delegation $true -Ou 'Domain Controllers'
        $s = New-TestSnapshot -Ad @{
            users             = @((New-TestAdUser -Sam 'svc-web' -Delegation $true), (New-TestAdUser -Sam 'alice'))
            computers         = @($dc, (New-TestAdComputer -Name 'APP01' -Delegation $true), (New-TestAdComputer -Name 'PC01'))
            domainControllers = @($dc.DistinguishedName)
        }
        @((Get-TestFinding -Snapshot $s -CheckId 'AD-07').Identity | Sort-Object) | Should -Be @('APP01', 'svc-web')
    }
}
