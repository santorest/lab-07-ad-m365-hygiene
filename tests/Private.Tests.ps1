BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-HygieneModuleForTest
}

Describe 'ConvertTo-HygieneUtc' {
    It 'parses an ISO string as UTC' {
        InModuleScope HygieneToolkit { (ConvertTo-HygieneUtc '2026-09-30T12:00:00Z').ToString('o') } |
            Should -Be '2026-09-30T12:00:00.0000000Z'
    }
    It 'treats a string without offset as UTC' {
        InModuleScope HygieneToolkit { (ConvertTo-HygieneUtc '2026-09-30T12:00:00').Kind } | Should -Be 'Utc'
    }
    It 'converts a local DateTime to UTC' {
        InModuleScope HygieneToolkit {
            $local = [datetime]::SpecifyKind([datetime]'2026-09-30 12:00:00', 'Utc').ToLocalTime()
            (ConvertTo-HygieneUtc $local).ToString('o')
        } | Should -Be '2026-09-30T12:00:00.0000000Z'
    }
    It 'returns null for null and blank' {
        InModuleScope HygieneToolkit { ($null -eq (ConvertTo-HygieneUtc $null)) -and ($null -eq (ConvertTo-HygieneUtc '  ')) } | Should -BeTrue
    }
}

Describe 'Get-HygieneAge' {
    It 'counts days between since and asOf' {
        InModuleScope HygieneToolkit { Get-HygieneAge -Since '2026-07-02T12:00:00Z' -AsOf '2026-09-30T12:00:00Z' } | Should -Be 90
    }
    It 'returns null when since is null' {
        InModuleScope HygieneToolkit { Get-HygieneAge -Since $null -AsOf '2026-09-30T12:00:00Z' } | Should -BeNullOrEmpty
    }
}

Describe 'Test-HygieneStale' {
    It 'is not stale at exactly the threshold' {
        InModuleScope HygieneToolkit {
            Test-HygieneStale -LastActivity '2026-07-02T12:00:00Z' -Created '2025-01-01T00:00:00Z' -AsOf '2026-09-30T12:00:00Z' -Days 90
        } | Should -BeNullOrEmpty
    }
    It 'is stale one day past the threshold' {
        InModuleScope HygieneToolkit {
            Test-HygieneStale -LastActivity '2026-07-01T12:00:00Z' -Created '2025-01-01T00:00:00Z' -AsOf '2026-09-30T12:00:00Z' -Days 90
        } | Should -Be 'Last activity 91 days before collection.'
    }
    It 'uses the creation date when there was never any activity' {
        InModuleScope HygieneToolkit {
            Test-HygieneStale -LastActivity $null -Created '2026-06-01T12:00:00Z' -AsOf '2026-09-30T12:00:00Z' -Days 90
        } | Should -Be 'Never active; created 121 days before collection.'
        InModuleScope HygieneToolkit {
            Test-HygieneStale -LastActivity $null -Created '2026-09-01T12:00:00Z' -AsOf '2026-09-30T12:00:00Z' -Days 90
        } | Should -BeNullOrEmpty
    }
}

Describe 'Get-HygieneSetting' {
    It 'returns defaults and applies overrides' {
        InModuleScope HygieneToolkit { (Get-HygieneSetting -Override @{ StaleUserDays = 30 }).StaleUserDays } | Should -Be 30
        InModuleScope HygieneToolkit { (Get-HygieneSetting).GlobalAdminMax } | Should -Be 4
    }
    It 'rejects an unknown setting' {
        { InModuleScope HygieneToolkit { Get-HygieneSetting -Override @{ StaleDays = 1 } } } | Should -Throw '*Unknown setting*'
    }
}

Describe 'Datasets' {
    It 'reports ok, unavailable and not collected' {
        $snap = New-TestSnapshot -Ad @{ users = @(); computers = (New-TestDataset -Items @() -Status 'unavailable' -Message 'denied') }
        InModuleScope HygieneToolkit -Parameters @{ s = $snap } {
            @((Get-HygieneDatasetState -Snapshot $s -Name 'ad.users'),
                (Get-HygieneDatasetState -Snapshot $s -Name 'ad.computers'),
                (Get-HygieneDatasetState -Snapshot $s -Name 'ad.privilegedGroups'),
                (Get-HygieneDatasetState -Snapshot $s -Name 'graph.users'))
        } | Should -Be @('ok', 'unavailable: denied', 'not collected', 'not collected')
    }
    It 'returns zero items for an empty dataset and one for a single item' {
        $empty = New-TestSnapshot -Ad @{ users = @() }
        $one = New-TestSnapshot -Ad @{ users = @(New-TestAdUser -Sam 'solo') }
        InModuleScope HygieneToolkit -Parameters @{ e = $empty; o = $one } {
            @(@(Get-HygieneItem -Snapshot $e -Name 'ad.users').Count, @(Get-HygieneItem -Snapshot $o -Name 'ad.users').Count)
        } | Should -Be @(0, 1)
    }
}

Describe 'Invoke-HygieneCollection' {
    It 'wraps items and turns an exception into unavailable' {
        InModuleScope HygieneToolkit {
            $ok = Invoke-HygieneCollection { 1; 2 }
            $bad = Invoke-HygieneCollection { throw 'Insufficient privileges' }
            @($ok.status, $ok.items.Count, $bad.status, $bad.error, $bad.items.Count)
        } | Should -Be @('ok', 2, 'unavailable', 'Insufficient privileges', 0)
    }
    It 'treats a non-terminating error as unavailable' {
        InModuleScope HygieneToolkit { (Invoke-HygieneCollection { Write-Error 'server down' }).status } | Should -Be 'unavailable'
    }
}

Describe 'New-HygieneFinding' {
    It 'fills title, remediation and reference from the catalog' {
        $f = InModuleScope HygieneToolkit {
            New-HygieneFinding -CheckId 'AD-01' -Severity Medium -ObjectType User -Identity 'bob' -Detail 'x'
        }
        $f.Title | Should -Be 'Stale users'
        $f.Status | Should -Be 'Finding'
        $f.Reference | Should -Match '^https://'
    }
}
