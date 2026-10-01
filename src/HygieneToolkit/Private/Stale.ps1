function Test-HygieneStale {
    # Returns $null when the object is active enough, otherwise a sentence saying why it is stale.
    # Stale means strictly more than $Days days before the snapshot was collected.
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()] [object] $LastActivity, [AllowNull()] [object] $Created, [Parameter(Mandatory)] [object] $AsOf,
        [Parameter(Mandatory)] [int] $Days)
    $age = Get-HygieneAge -Since $LastActivity -AsOf $AsOf
    if ($null -ne $age) {
        if ($age -gt $Days) { return ('Last activity {0} days before collection.' -f [int][math]::Floor($age)) }
        return $null
    }
    $createdAge = Get-HygieneAge -Since $Created -AsOf $AsOf
    if ($null -ne $createdAge -and $createdAge -gt $Days) {
        return ('Never active; created {0} days before collection.' -f [int][math]::Floor($createdAge))
    }
    # Graph leaves createdDateTime empty for some old accounts; with no activity either, nothing proves the object is in use.
    if ($null -eq $createdAge) { return 'No activity and no creation date recorded.' }
    $null
}
