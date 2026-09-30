function New-HygieneFinding {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $CheckId,
        [Parameter(Mandatory)] [ValidateSet('High', 'Medium', 'Low', 'Info')] [string] $Severity,
        [Parameter(Mandatory)] [string] $ObjectType,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Identity,
        [Parameter(Mandatory)] [string] $Detail,
        [ValidateSet('Finding', 'NotEvaluated')] [string] $Status = 'Finding'
    )
    $check = $script:HygieneCatalog | Where-Object { $_.Id -eq $CheckId }
    if (-not $check) { throw "Unknown check '$CheckId'." }
    [pscustomobject][ordered]@{
        PSTypeName  = 'HygieneToolkit.Finding'
        CheckId     = $CheckId
        Title       = $check.Title
        Severity    = $Severity
        Status      = $Status
        ObjectType  = $ObjectType
        Identity    = $Identity
        Detail      = $Detail
        Remediation = $check.Remediation
        Reference   = $check.Reference
    }
}
