# Builds docs/example-report.html from tests/fixtures/corp.fixture.json. -PassThru returns the HTML instead of writing it.
# The report depends only on the fixture, so the output is identical on Windows PowerShell 5.1 and PowerShell 7.
[CmdletBinding()]
param([switch] $PassThru)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src/HygieneToolkit/HygieneToolkit.psd1') -Force
$snapshotPath = Join-Path $root 'tests/fixtures/corp.fixture.json'
$snapshot = Import-HygieneSnapshot -Path $snapshotPath
$findings = @(Invoke-HygieneAudit -Snapshot $snapshot)
$html = ConvertTo-HygieneHtml -Finding $findings -CollectedAt $snapshot.collectedAt -Source $snapshot.source
if ($PassThru) { return $html }
[IO.File]::WriteAllText((Join-Path $root 'docs/example-report.html'), $html, (New-Object Text.UTF8Encoding($false)))
