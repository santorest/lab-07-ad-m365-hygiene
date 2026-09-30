function New-HygieneSnapshot {
    <#
    .SYNOPSIS
    Combines collector output into a snapshot (schemaVersion 1) that Save-HygieneSnapshot can write.
    .EXAMPLE
    New-HygieneSnapshot -Ad (Get-HygieneAdSnapshot) -Graph (Get-HygieneGraphSnapshot) -Source 'corp' | Save-HygieneSnapshot -Path .\corp.snapshot.json
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([object] $Ad, [object] $Graph, [datetime] $CollectedAt = [datetime]::UtcNow, [string] $Source = '')
    [pscustomobject][ordered]@{
        schemaVersion = 1
        collectedAt   = Format-HygieneDate $CollectedAt
        source        = $Source
        ad            = $Ad
        graph         = $Graph
    }
}

function Save-HygieneSnapshot {
    <#
    .SYNOPSIS
    Writes a snapshot as UTF-8 JSON. Snapshots contain directory data: store them like any other sensitive export.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] [object] $Snapshot, [Parameter(Mandatory)] [string] $Path)
    process {
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $json = $Snapshot | ConvertTo-Json -Depth 20
        [IO.File]::WriteAllText($full, $json, (New-Object Text.UTF8Encoding($false)))
    }
}

function Import-HygieneSnapshot {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [string] $Path)
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $snapshot = [IO.File]::ReadAllText($full, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if (-not $snapshot.PSObject.Properties['schemaVersion'] -or $snapshot.schemaVersion -ne 1) {
        throw "Unsupported snapshot '$Path': expected schemaVersion 1."
    }
    if (-not $snapshot.PSObject.Properties['collectedAt'] -or $null -eq (ConvertTo-HygieneUtc $snapshot.collectedAt)) {
        throw "Snapshot '$Path' has no collectedAt."
    }
    $snapshot
}
