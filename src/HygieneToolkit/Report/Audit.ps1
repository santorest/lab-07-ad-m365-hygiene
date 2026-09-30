function Invoke-HygieneAudit {
    <#
    .SYNOPSIS
    Runs every hygiene check against a snapshot and returns the findings.
    .DESCRIPTION
    A check whose datasets were not collected or are unavailable returns one "not evaluated" finding with the reason,
    never an empty result.
    .PARAMETER Snapshot
    A snapshot object or the path of a snapshot JSON file.
    .PARAMETER Settings
    Overrides for the defaults in Data/defaults.psd1, for example @{ StaleUserDays = 60 }.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [object] $Snapshot, [hashtable] $Settings)
    if ($Snapshot -is [string]) {
        $Snapshot = Import-HygieneSnapshot -Path $Snapshot
    } else {
        # One shape for objects built in memory and objects read from JSON.
        $Snapshot = $Snapshot | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    }
    $resolved = Get-HygieneSetting -Override $Settings
    foreach ($check in $script:HygieneCatalog) {
        $missing = @(foreach ($name in $check.Needs) {
                $state = Get-HygieneDatasetState -Snapshot $Snapshot -Name $name
                if ($state -ne 'ok') { "$name $state" }
            })
        if ($missing.Count -gt 0) {
            New-HygieneFinding -CheckId $check.Id -Severity Info -ObjectType Check -Identity '' -Status NotEvaluated `
                -Detail ('Not evaluated: {0}.' -f ($missing -join '; '))
            continue
        }
        & $check.Function -Snapshot $Snapshot -Settings $resolved
    }
}

function Get-HygieneCheck {
    <#
    .SYNOPSIS
    Lists the checks: id, title and the snapshot datasets each one needs.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $script:HygieneCatalog | ForEach-Object { [pscustomobject][ordered]@{ Id = $_.Id; Title = $_.Title; Needs = $_.Needs } }
}
