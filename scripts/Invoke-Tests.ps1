# Runs PSScriptAnalyzer on src/ and scripts/, then the Pester suite. Exit code 1 on any finding or failed test.
[CmdletBinding()]
param([switch] $SkipAnalyzer)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module Pester -RequiredVersion 5.7.1
if (-not $SkipAnalyzer) {
    Import-Module PSScriptAnalyzer -RequiredVersion 1.23.0
    $settings = Join-Path $root 'PSScriptAnalyzerSettings.psd1'
    $issues = @(foreach ($folder in 'src', 'scripts') {
            Invoke-ScriptAnalyzer -Path (Join-Path $root $folder) -Recurse -Settings $settings
        })
    if ($issues.Count -gt 0) { $issues | Format-Table -AutoSize | Out-String | Write-Output; exit 1 }
    Write-Output 'PSScriptAnalyzer: 0 findings'
}
$config = New-PesterConfiguration
$config.Run.Path = Join-Path $root 'tests'
$config.Run.Exit = $true
$config.Output.Verbosity = 'Normal'
Invoke-Pester -Configuration $config
