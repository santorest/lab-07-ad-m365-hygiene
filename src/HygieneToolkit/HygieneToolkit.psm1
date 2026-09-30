Set-StrictMode -Version 3.0
$script:ModuleRoot = $PSScriptRoot
foreach ($folder in 'Private', 'Collect', 'Checks', 'Report') {
    $path = Join-Path $PSScriptRoot $folder
    if (Test-Path $path) {
        foreach ($file in Get-ChildItem -Path $path -Filter '*.ps1' | Sort-Object Name) { . $file.FullName }
    }
}
