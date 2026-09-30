function Get-HygieneSetting {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([hashtable] $Override)
    $settings = Import-PowerShellDataFile -Path (Join-Path $script:ModuleRoot 'Data/defaults.psd1')
    if ($Override) {
        foreach ($key in $Override.Keys) {
            if (-not $settings.ContainsKey($key)) { throw "Unknown setting '$key'." }
            $settings[$key] = $Override[$key]
        }
    }
    $settings
}
