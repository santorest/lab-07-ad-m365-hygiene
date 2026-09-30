function Invoke-HygieneCollection {
    # Runs one collector call and wraps the result as a dataset: {status; error; items}. Any error, terminating or not,
    # marks the dataset unavailable so the dependent checks report "not evaluated" instead of looking clean.
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory, Position = 0)] [scriptblock] $ScriptBlock)
    try {
        $ErrorActionPreference = 'Stop'
        $items = @(& $ScriptBlock)
        [pscustomobject][ordered]@{ status = 'ok'; error = $null; items = $items }
    } catch {
        [pscustomobject][ordered]@{ status = 'unavailable'; error = $_.Exception.Message; items = @() }
    }
}
