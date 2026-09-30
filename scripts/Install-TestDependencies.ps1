# Installs the pinned test tools (Pester 5.7.1, PSScriptAnalyzer 1.23.0) with retries; PSGallery is flaky in CI.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$pins = [ordered]@{ Pester = '5.7.1'; PSScriptAnalyzer = '1.23.0' }
foreach ($name in $pins.Keys) {
    if (Get-Module -ListAvailable -Name $name | Where-Object { $_.Version -eq [version]$pins[$name] }) { continue }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Install-Module -Name $name -RequiredVersion $pins[$name] -Force -Scope CurrentUser -SkipPublisherCheck -AllowClobber
            break
        } catch {
            if ($attempt -eq 3) { throw }
            Start-Sleep -Seconds (10 * $attempt)
        }
    }
}
