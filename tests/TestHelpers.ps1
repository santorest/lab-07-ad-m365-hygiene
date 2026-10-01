# Shared by every *.Tests.ps1. Dot-source in BeforeAll.
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:CollectedAt = '2026-09-30T12:00:00Z'

function Import-HygieneModuleForTest {
    Get-Module HygieneToolkit | Remove-Module -Force
    Import-Module (Join-Path $script:RepoRoot 'src/HygieneToolkit/HygieneToolkit.psd1') -Force
}

function DaysAgo {
    param([Parameter(Mandatory)] [double] $Days)
    $asOf = [datetime]::Parse($script:CollectedAt, [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal)
    $asOf.AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
}

function New-TestAdUser {
    param([Parameter(Mandatory)] [string] $Sam, [bool] $Enabled = $true, [AllowNull()] $LastLogon = (DaysAgo 1),
        $Created = (DaysAgo 400), [bool] $PasswordNeverExpires = $false, [string[]] $Spn = @(),
        [bool] $NoPreAuth = $false, [bool] $Delegation = $false, [string] $ObjectClass = 'user')
    [pscustomobject][ordered]@{
        SamAccountName = $Sam; DistinguishedName = "CN=$Sam,OU=Users,DC=corp,DC=internal"; ObjectClass = $ObjectClass
        Enabled = $Enabled; LastLogonTimestamp = $LastLogon; WhenCreated = $Created
        PasswordNeverExpires = $PasswordNeverExpires; ServicePrincipalName = @($Spn)
        DoesNotRequirePreAuth = $NoPreAuth; TrustedForDelegation = $Delegation
    }
}

function New-TestAdComputer {
    param([Parameter(Mandatory)] [string] $Name, [bool] $Enabled = $true, [AllowNull()] $LastLogon = (DaysAgo 1),
        $Created = (DaysAgo 400), [bool] $Delegation = $false, [string] $Ou = 'Computers')
    [pscustomobject][ordered]@{
        Name = $Name; DistinguishedName = "CN=$Name,OU=$Ou,DC=corp,DC=internal"; Enabled = $Enabled
        LastLogonTimestamp = $LastLogon; WhenCreated = $Created; TrustedForDelegation = $Delegation
    }
}

function New-TestGraphUser {
    param([Parameter(Mandatory)] [string] $Upn, [string] $Id = ([guid]::NewGuid().ToString()), [string] $UserType = 'Member',
        [bool] $Enabled = $true, $Created = (DaysAgo 400), [string[]] $Licenses = @(),
        [AllowNull()] [string] $ExternalState = $null, [AllowNull()] $ExternalStateChanged = $null, [string] $DisplayName = '')
    if (-not $DisplayName) { $DisplayName = $Upn.Split('@')[0] }
    if (-not $ExternalState) { $ExternalState = $null }
    [pscustomobject][ordered]@{
        id = $Id; userPrincipalName = $Upn; displayName = $DisplayName; userType = $UserType; accountEnabled = $Enabled
        createdDateTime = $Created; externalUserState = $ExternalState; externalUserStateChangeDateTime = $ExternalStateChanged
        assignedLicenses = @($Licenses)
    }
}

function New-TestDataset {
    param([AllowNull()] [object[]] $Items, [string] $Status = 'ok', [string] $Message = $null)
    [pscustomobject][ordered]@{ status = $Status; error = $Message; items = @($Items | Where-Object { $null -ne $_ }) }
}

function New-TestSnapshot {
    # Pass datasets as object[] (becomes status ok) or as the result of New-TestDataset (to set a status).
    param([hashtable] $Ad, [hashtable] $Graph, [string] $CollectedAt = $script:CollectedAt)
    $toSection = {
        param($table)
        if ($null -eq $table) { return $null }
        $section = [ordered]@{}
        foreach ($key in $table.Keys) {
            $value = $table[$key]
            if ($value -is [pscustomobject] -and $value.PSObject.Properties['status']) { $section[$key] = $value }
            else { $section[$key] = New-TestDataset -Items $value }
        }
        [pscustomobject]$section
    }
    $snapshot = [pscustomobject][ordered]@{
        schemaVersion = 1; collectedAt = $CollectedAt; source = 'corp.internal / corp.example'
        ad = (& $toSection $Ad); graph = (& $toSection $Graph)
    }
    # Round-trip through JSON so tests see exactly what Import-HygieneSnapshot would return on this runtime.
    $snapshot | ConvertTo-Json -Depth 20 | ConvertFrom-Json
}

function Get-TestFinding {
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [string] $CheckId, [hashtable] $Settings)
    # The leading comma keeps a one-finding result an array (Windows PowerShell 5.1 PSCustomObject has no .Count).
    , @(Invoke-HygieneAudit -Snapshot $Snapshot -Settings $Settings | Where-Object { $_.CheckId -eq $CheckId })
}

function Test-WriteCommandName {
    # True for AD/Graph cmdlets that are not reads, and for raw Graph requests or dynamic code.
    param([Parameter(Mandatory)] [string] $Name)
    if ($Name -eq 'Invoke-MgGraphRequest' -or $Name -eq 'Invoke-Expression') { return $true }
    # Command names are case-insensitive, so Set-AdUser and set-aduser must be caught as well as Set-ADUser.
    if ($Name -imatch '^(?<verb>[a-z]+)-(ad|mg)[a-z]') { return $Matches.verb -ne 'Get' }
    $false
}

$script:StubNames = @(
    'Get-ADUser', 'Get-ADComputer', 'Get-ADGroupMember', 'Get-ADDomainController',
    'Get-MgUser', 'Get-MgReportAuthenticationMethodUserRegistrationDetail', 'Get-MgSubscribedSku',
    'Get-MgRoleManagementDirectoryRoleAssignment', 'Get-MgRoleManagementDirectoryRoleEligibilitySchedule'
)

function Install-HygieneStub {
    # Global functions shadow the real RSAT cmdlets (functions win over cmdlets) and stand in for Microsoft.Graph.
    function global:Get-ADUser { [CmdletBinding()] param([string] $Filter, [object] $ResultSetSize, [string[]] $Properties, [string] $Server) }
    function global:Get-ADComputer { [CmdletBinding()] param([string] $Filter, [object] $ResultSetSize, [string[]] $Properties, [string] $Server) }
    function global:Get-ADGroupMember { [CmdletBinding()] param([object] $Identity, [switch] $Recursive, [string] $Server) }
    function global:Get-ADDomainController { [CmdletBinding()] param([string] $Filter, [string] $Server) }
    function global:Get-MgUser { [CmdletBinding()] param([switch] $All, [string[]] $Property) }
    function global:Get-MgReportAuthenticationMethodUserRegistrationDetail { [CmdletBinding()] param([switch] $All) }
    function global:Get-MgSubscribedSku { [CmdletBinding()] param() }
    function global:Get-MgRoleManagementDirectoryRoleAssignment { [CmdletBinding()] param([switch] $All) }
    function global:Get-MgRoleManagementDirectoryRoleEligibilitySchedule { [CmdletBinding()] param([switch] $All) }
}

function Remove-HygieneStub {
    foreach ($name in $script:StubNames) { Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue }
}
