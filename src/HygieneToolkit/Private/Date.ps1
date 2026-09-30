function ConvertTo-HygieneUtc {
    # Accepts an ISO string (Windows PowerShell 5.1 JSON) or a DateTime (PowerShell 7 JSON, AD objects); returns UTC.
    [CmdletBinding()]
    [OutputType([datetime])]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) {
        if ($Value.Kind -eq [DateTimeKind]::Unspecified) { return [datetime]::SpecifyKind($Value, [DateTimeKind]::Utc) }
        return $Value.ToUniversalTime()
    }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    [datetime]::Parse($text, [Globalization.CultureInfo]::InvariantCulture, $styles)
}

function Format-HygieneDate {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)
    $utc = ConvertTo-HygieneUtc $Value
    if ($null -eq $utc) { return $null }
    $utc.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
}

function Get-HygieneAge {
    [CmdletBinding()]
    [OutputType([double])]
    param([AllowNull()] [object] $Since, [Parameter(Mandatory)] [object] $AsOf)
    $start = ConvertTo-HygieneUtc $Since
    if ($null -eq $start) { return $null }
    ((ConvertTo-HygieneUtc $AsOf) - $start).TotalDays
}
