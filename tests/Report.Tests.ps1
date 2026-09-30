BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-HygieneModuleForTest
}

Describe 'ConvertTo-HygieneHtml' {
    It 'encodes attacker-controlled values' {
        $s = New-TestSnapshot -Ad @{ users = @(New-TestAdUser -Sam '<img src=x onerror=alert(1)>"' -PasswordNeverExpires $true) }
        $html = ConvertTo-HygieneHtml -Finding @(Invoke-HygieneAudit -Snapshot $s) -CollectedAt $CollectedAt
        $html | Should -Not -Match '<img src=x'
        $html | Should -Match '&lt;img src=x onerror=alert\(1\)&gt;&quot;'
    }
    It 'has no script tags and links only to the catalog references' {
        $s = New-TestSnapshot -Graph @{ users = @(New-TestGraphUser -Upn 'x@corp.example' -Id 'x' -DisplayName '<script>alert(1)</script>'); registrationDetails = @() }
        $html = ConvertTo-HygieneHtml -Finding @(Invoke-HygieneAudit -Snapshot $s) -CollectedAt $CollectedAt
        $html | Should -Not -Match '<script'
        $hrefs = @([regex]::Matches($html, 'href="([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
        @($hrefs | Where-Object { $_ -notmatch '^https://(learn\.microsoft\.com|attack\.mitre\.org)/' }).Count | Should -Be 0
        $html | Should -Not -Match '\ssrc='
    }
    It 'shows the collection time and not-evaluated checks' {
        $html = ConvertTo-HygieneHtml -Finding @(Invoke-HygieneAudit -Snapshot (New-TestSnapshot)) -CollectedAt $CollectedAt
        $html | Should -Match 'Not evaluated'
        $html | Should -Match 'Collected 2026-09-30T12:00:00Z'
    }
    It 'never uses the reference carried by a finding' {
        $bad = [pscustomobject]@{ CheckId = 'AD-01'; Title = 't'; Severity = 'Low'; Status = 'Finding'; ObjectType = 'User'; Identity = 'a'
            Detail = 'd'; Remediation = 'r'; Reference = 'javascript:alert(1)'
        }
        ConvertTo-HygieneHtml -Finding @($bad) -CollectedAt $CollectedAt | Should -Not -Match 'javascript:'
    }
    It 'writes a UTF-8 file without BOM when -Path is given' {
        $path = Join-Path $TestDrive 'r.html'
        ConvertTo-HygieneHtml -Finding @() -CollectedAt $CollectedAt -Path $path
        [IO.File]::ReadAllBytes($path)[0] | Should -Not -Be 0xEF
        [IO.File]::ReadAllText($path) | Should -Match '^<!doctype html>'
    }
}

Describe 'Export-HygieneFinding' {
    It 'writes CSV and JSON, and a single finding stays a JSON array' {
        $s = New-TestSnapshot -Ad @{ users = @(New-TestAdUser -Sam 'a' -NoPreAuth $true) }
        $one = @(Invoke-HygieneAudit -Snapshot $s | Where-Object CheckId -eq 'AD-06')
        $csv = Join-Path $TestDrive 'f.csv'
        $json = Join-Path $TestDrive 'f.json'
        Export-HygieneFinding -Finding $one -Path $csv -Format Csv
        Export-HygieneFinding -Finding $one -Path $json -Format Json
        (Import-Csv $csv).Identity | Should -Be 'a'
        ([IO.File]::ReadAllText($json)).TrimStart()[0] | Should -Be '['
    }
}

Describe 'Example report' {
    It 'docs/example-report.html matches the corp fixture on this runtime' {
        $expected = [IO.File]::ReadAllText((Join-Path $RepoRoot 'docs/example-report.html')) -replace "`r`n", "`n"
        $actual = & (Join-Path $RepoRoot 'scripts/Build-ExampleReport.ps1') -PassThru
        $actual | Should -BeExactly $expected
    }
    It 'the corp fixture exercises every check' {
        $findings = @(Invoke-HygieneAudit -Snapshot (Join-Path $RepoRoot 'tests/fixtures/corp.fixture.json'))
        foreach ($id in (Get-HygieneCheck).Id) { @($findings | Where-Object CheckId -eq $id).Count | Should -BeGreaterThan 0 -Because $id }
    }
}
