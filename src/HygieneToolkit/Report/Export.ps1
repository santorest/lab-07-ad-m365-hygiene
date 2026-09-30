function Export-HygieneFinding {
    <#
    .SYNOPSIS
    Writes findings as CSV or JSON (UTF-8 without BOM). JSON is always an array.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Finding, [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [ValidateSet('Csv', 'Json')] [string] $Format)
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $fields = 'CheckId', 'Title', 'Severity', 'Status', 'ObjectType', 'Identity', 'Detail', 'Remediation', 'Reference'
    $rows = @($Finding | Select-Object -Property $fields)
    if ($Format -eq 'Csv') {
        $text = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`n"
    } else {
        $text = ConvertTo-Json -InputObject $rows -Depth 5
    }
    [IO.File]::WriteAllText($full, $text + "`n", (New-Object Text.UTF8Encoding($false)))
}
