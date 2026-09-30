function ConvertTo-HygieneHtmlText {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)
    if ($null -eq $Value) { return '' }
    [Net.WebUtility]::HtmlEncode([string]$Value)
}

function ConvertTo-HygieneHtml {
    <#
    .SYNOPSIS
    Renders findings as one self-contained HTML page: inline CSS, no scripts, no external resources.
    .DESCRIPTION
    Every value is HTML-encoded (directory attributes are attacker-controllable). Links come only from the check
    catalog, never from the findings. The output depends only on the findings and -CollectedAt, so it is reproducible.
    .EXAMPLE
    $snapshot = Import-HygieneSnapshot .\corp.snapshot.json
    ConvertTo-HygieneHtml -Finding (Invoke-HygieneAudit -Snapshot $snapshot) -CollectedAt $snapshot.collectedAt -Path .\report.html
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Finding, [Parameter(Mandatory)] [object] $CollectedAt,
        [string] $Source = '', [string] $Path)
    $collected = Format-HygieneDate $CollectedAt
    $real = @($Finding | Where-Object { $_.Status -eq 'Finding' })
    $sb = New-Object Text.StringBuilder
    $null = $sb.Append("<!doctype html>`n<html lang=`"en`">`n<head>`n<meta charset=`"utf-8`">`n")
    $null = $sb.Append("<title>AD / Microsoft 365 hygiene report</title>`n<style>")
    $null = $sb.Append('body{font-family:Segoe UI,Arial,sans-serif;margin:2rem;color:#1b1f24}table{border-collapse:collapse;margin:.5rem 0 1.5rem}')
    $null = $sb.Append('th,td{border:1px solid #d0d7de;padding:.35rem .6rem;text-align:left;vertical-align:top}th{background:#f6f8fa}')
    $null = $sb.Append('.High{color:#a40e26;font-weight:600}.Medium{color:#9a6700;font-weight:600}.Low{color:#0969da}.Info{color:#57606a}')
    $null = $sb.Append("</style>`n</head>`n<body>`n<h1>AD / Microsoft 365 hygiene report</h1>`n")
    $null = $sb.Append("<p>Collected $(ConvertTo-HygieneHtmlText $collected)")
    if ($Source) { $null = $sb.Append(" &middot; $(ConvertTo-HygieneHtmlText $Source)") }
    $null = $sb.Append("</p>`n<h2>Summary</h2>`n<table><tr><th>Severity</th><th>Findings</th></tr>`n")
    foreach ($severity in 'High', 'Medium', 'Low', 'Info') {
        $count = @($real | Where-Object { $_.Severity -eq $severity }).Count
        $null = $sb.Append("<tr><td class=`"$severity`">$severity</td><td>$count</td></tr>`n")
    }
    $null = $sb.Append("</table>`n<table><tr><th>Check</th><th>Title</th><th>Result</th></tr>`n")
    foreach ($check in $script:HygieneCatalog) {
        $mine = @($Finding | Where-Object { $_.CheckId -eq $check.Id })
        $notEvaluated = @($mine | Where-Object { $_.Status -eq 'NotEvaluated' }).Count
        $count = @($mine | Where-Object { $_.Status -eq 'Finding' }).Count
        $result = "$count finding(s)"
        if ($notEvaluated -gt 0 -and $count -eq 0) { $result = 'Not evaluated' }
        elseif ($notEvaluated -gt 0) { $result += '; partly not evaluated' }
        $null = $sb.Append("<tr><td>$($check.Id)</td><td>$(ConvertTo-HygieneHtmlText $check.Title)</td><td>$result</td></tr>`n")
    }
    $null = $sb.Append("</table>`n")
    foreach ($check in $script:HygieneCatalog) {
        $mine = @($Finding | Where-Object { $_.CheckId -eq $check.Id })
        if ($mine.Count -eq 0) { continue }
        $null = $sb.Append("<h2>$($check.Id) &middot; $(ConvertTo-HygieneHtmlText $check.Title)</h2>`n")
        $null = $sb.Append("<p>$(ConvertTo-HygieneHtmlText $check.Remediation)")
        if ($check.Reference -match '^https://') { $null = $sb.Append(" <a href=`"$(ConvertTo-HygieneHtmlText $check.Reference)`">Reference</a>") }
        $null = $sb.Append("</p>`n<table><tr><th>Severity</th><th>Status</th><th>Type</th><th>Identity</th><th>Detail</th></tr>`n")
        foreach ($item in $mine) {
            $status = 'Finding'
            if ($item.Status -eq 'NotEvaluated') { $status = 'Not evaluated' }
            $severity = ConvertTo-HygieneHtmlText $item.Severity
            $null = $sb.Append("<tr><td class=`"$severity`">$severity</td><td>$status</td><td>$(ConvertTo-HygieneHtmlText $item.ObjectType)</td>")
            $null = $sb.Append("<td>$(ConvertTo-HygieneHtmlText $item.Identity)</td><td>$(ConvertTo-HygieneHtmlText $item.Detail)</td></tr>`n")
        }
        $null = $sb.Append("</table>`n")
    }
    $null = $sb.Append("</body>`n</html>`n")
    $html = $sb.ToString()
    if ($Path) {
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        [IO.File]::WriteAllText($full, $html, (New-Object Text.UTF8Encoding($false)))
        return
    }
    $html
}
