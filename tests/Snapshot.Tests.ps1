BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-HygieneModuleForTest
}

Describe 'Snapshot I/O' {
    It 'round-trips a deeply nested snapshot without truncation' {
        $member = [pscustomobject]@{ DistinguishedName = 'CN=a'; SamAccountName = 'a'; ObjectClass = 'user'; Path = 'Domain Admins > a' }
        $group = [pscustomobject]@{ Name = 'Domain Admins'; Members = @($member) }
        $ad = [pscustomobject]@{ privilegedGroups = [pscustomobject]@{ status = 'ok'; error = $null; items = @($group) } }
        $snap = New-HygieneSnapshot -Ad $ad -CollectedAt ([datetime]::SpecifyKind([datetime]'2026-09-30 12:00:00', 'Utc')) -Source 'corp'
        $path = Join-Path $TestDrive 'x.snapshot.json'
        Save-HygieneSnapshot -Snapshot $snap -Path $path
        $back = Import-HygieneSnapshot -Path $path
        @($back.ad.privilegedGroups.items)[0].Members[0].Path | Should -Be 'Domain Admins > a'
    }
    It 'writes UTF-8 without a BOM and keeps non-ASCII text' {
        $name = 'S' + [char]0xE1 + 'nchez'
        $path = Join-Path $TestDrive 'nobom.snapshot.json'
        Save-HygieneSnapshot -Snapshot (New-HygieneSnapshot -Source $name) -Path $path
        $bytes = [IO.File]::ReadAllBytes($path)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB) | Should -BeFalse
        (Import-HygieneSnapshot -Path $path).source | Should -Be $name
    }
    It 'resolves a relative path against the PowerShell location' {
        Push-Location $TestDrive
        try { Save-HygieneSnapshot -Snapshot (New-HygieneSnapshot) -Path 'rel.snapshot.json' } finally { Pop-Location }
        Test-Path (Join-Path $TestDrive 'rel.snapshot.json') | Should -BeTrue
    }
    It 'rejects an unknown schema version' {
        $path = Join-Path $TestDrive 'v2.snapshot.json'
        [IO.File]::WriteAllText($path, '{"schemaVersion":2,"collectedAt":"2026-09-30T12:00:00Z"}')
        { Import-HygieneSnapshot -Path $path } | Should -Throw '*schemaVersion 1*'
    }
    It 'rejects a snapshot without collectedAt' {
        $path = Join-Path $TestDrive 'nodate.snapshot.json'
        [IO.File]::WriteAllText($path, '{"schemaVersion":1}')
        { Import-HygieneSnapshot -Path $path } | Should -Throw '*collectedAt*'
    }
    It 'stamps collectedAt in UTC ISO format' {
        (New-HygieneSnapshot -CollectedAt ([datetime]::SpecifyKind([datetime]'2026-09-30 12:00:00', 'Utc'))).collectedAt |
            Should -Be '2026-09-30T12:00:00Z'
    }
}
