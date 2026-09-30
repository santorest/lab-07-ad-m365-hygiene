function Get-HygieneDatasetState {
    # 'ok', or why the dataset cannot be used ('not collected' / 'unavailable: <error>').
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [object] $Snapshot, [Parameter(Mandatory)] [string] $Name)
    $sectionName, $key = $Name.Split('.')
    $section = $Snapshot.PSObject.Properties[$sectionName]
    if (-not $section -or $null -eq $section.Value) { return 'not collected' }
    $dataset = $section.Value.PSObject.Properties[$key]
    if (-not $dataset -or $null -eq $dataset.Value) { return 'not collected' }
    if ($dataset.Value.status -ne 'ok') { return "unavailable: $($dataset.Value.error)" }
    'ok'
}

function Get-HygieneItem {
    # The items of a dataset, never a lone $null; callers use the pipeline or @() around the result.
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory)] [object] $Snapshot, [Parameter(Mandatory)] [string] $Name)
    if ((Get-HygieneDatasetState -Snapshot $Snapshot -Name $Name) -ne 'ok') { return }
    $sectionName, $key = $Name.Split('.')
    foreach ($item in @($Snapshot.$sectionName.$key.items)) {
        if ($null -ne $item) { $item }
    }
}
