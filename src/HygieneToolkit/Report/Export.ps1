function Export-HygieneFinding {
    <#
    .SYNOPSIS
    Writes findings as CSV or JSON (UTF-8 without BOM). JSON is always an array.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [AllowNull()] [AllowEmptyCollection()] [object[]] $Finding, [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [ValidateSet('Csv', 'Json')] [string] $Format)
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $fields = 'CheckId', 'Title', 'Severity', 'Status', 'ObjectType', 'Identity', 'Detail', 'Remediation', 'Reference'
    # A filter that matched nothing arrives as $null; it is an empty result, not an error.
    $rows = @($Finding | Where-Object { $null -ne $_ } | Select-Object -Property $fields)
    if ($rows.Count -eq 0) {
        # ConvertTo-Csv writes nothing (no header) for no rows, and Windows PowerShell 5.1 ConvertTo-Json does not write [].
        if ($Format -eq 'Csv') { $text = '"' + ($fields -join '","') + '"' } else { $text = '[]' }
    } elseif ($Format -eq 'Csv') {
        $text = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`n"
    } else {
        $text = ConvertTo-Json -InputObject $rows -Depth 5
    }
    [IO.File]::WriteAllText($full, $text + "`n", (New-Object Text.UTF8Encoding($false)))
}
