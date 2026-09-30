BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-HygieneModuleForTest
}

Describe 'Invoke-HygieneAudit' {
    It 'reports every check as not evaluated for an empty snapshot' {
        $f = @(Invoke-HygieneAudit -Snapshot (New-TestSnapshot))
        $f.Count | Should -Be 12
        @($f.Status | Sort-Object -Unique) | Should -Be @('NotEvaluated')
        ($f | Where-Object CheckId -eq 'AD-07').Detail |
            Should -Be 'Not evaluated: ad.users not collected; ad.computers not collected; ad.domainControllers not collected.'
    }
    It 'carries the collector error into the not-evaluated detail' {
        $s = New-TestSnapshot -Graph @{ users = (New-TestDataset -Items @() -Status 'unavailable' -Message 'Authorization_RequestDenied') }
        (Invoke-HygieneAudit -Snapshot $s | Where-Object CheckId -eq 'M365-05').Detail | Should -Match 'Authorization_RequestDenied'
    }
    It 'accepts a path' {
        $path = Join-Path $TestDrive 'a.snapshot.json'
        (New-TestSnapshot -Ad @{ users = @() }) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding ASCII
        @(Invoke-HygieneAudit -Snapshot $path | Where-Object { $_.CheckId -eq 'AD-01' -and $_.Status -eq 'NotEvaluated' }).Count | Should -Be 0
    }
    It 'lists the catalog' {
        @((Get-HygieneCheck).Id) | Should -Be @('AD-01', 'AD-02', 'AD-03', 'AD-04', 'AD-05', 'AD-06', 'AD-07', 'M365-01', 'M365-02', 'M365-03', 'M365-04', 'M365-05')
    }
}
