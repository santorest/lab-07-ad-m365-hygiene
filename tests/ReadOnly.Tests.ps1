BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'Write-command predicate' {
    It 'flags <Name>' -ForEach @(
        @{ Name = 'Set-ADUser' }, @{ Name = 'New-ADUser' }, @{ Name = 'Remove-MgUser' }, @{ Name = 'Update-MgUser' },
        @{ Name = 'Invoke-MgGraphRequest' }, @{ Name = 'Add-ADGroupMember' }, @{ Name = 'Invoke-Expression' },
        @{ Name = 'Set-AdUser' }, @{ Name = 'set-aduser' }, @{ Name = 'Remove-MGUser' }, @{ Name = 'invoke-mggraphrequest' }
    ) {
        Test-WriteCommandName $Name | Should -BeTrue
    }
    It 'allows <Name>' -ForEach @(
        @{ Name = 'Get-ADUser' }, @{ Name = 'Get-MgUser' }, @{ Name = 'Get-HygieneAdSnapshot' }, @{ Name = 'Set-Content' },
        @{ Name = 'New-HygieneFinding' }, @{ Name = 'Get-Admin' }
    ) {
        Test-WriteCommandName $Name | Should -BeFalse
    }
}

Describe 'Module is read-only' {
    It 'calls no AD or Graph cmdlet except Get-*' {
        $violations = foreach ($file in Get-ChildItem -Path (Join-Path $RepoRoot 'src') -Recurse -Include '*.ps1', '*.psm1') {
            $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            foreach ($command in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] }, $true)) {
                $name = $command.GetCommandName()
                if ($name -and (Test-WriteCommandName $name)) { '{0}:{1} {2}' -f $file.Name, $command.Extent.StartLineNumber, $name }
            }
        }
        $violations | Should -BeNullOrEmpty
    }
}
