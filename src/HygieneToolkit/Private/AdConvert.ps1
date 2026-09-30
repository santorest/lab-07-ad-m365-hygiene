$script:AdUserProperties = @('LastLogonTimestamp', 'WhenCreated', 'PasswordNeverExpires', 'ServicePrincipalName',
    'DoesNotRequirePreAuth', 'TrustedForDelegation')
$script:AdComputerProperties = @('LastLogonTimestamp', 'WhenCreated', 'TrustedForDelegation')

function ConvertFrom-HygieneFileTime {
    # lastLogonTimestamp is a Windows file time (0 or absent = never).
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)
    if ($null -eq $Value) { return $null }
    $ticks = [int64]$Value
    if ($ticks -le 0) { return $null }
    Format-HygieneDate ([datetime]::FromFileTimeUtc($ticks))
}

function ConvertTo-HygieneAdUser {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [object] $User)
    [pscustomobject][ordered]@{
        SamAccountName        = [string]$User.SamAccountName
        DistinguishedName     = [string]$User.DistinguishedName
        ObjectClass           = [string]$User.ObjectClass
        Enabled               = [bool]$User.Enabled
        LastLogonTimestamp    = ConvertFrom-HygieneFileTime $User.LastLogonTimestamp
        WhenCreated           = Format-HygieneDate $User.WhenCreated
        PasswordNeverExpires  = [bool]$User.PasswordNeverExpires
        ServicePrincipalName  = @($User.ServicePrincipalName | Where-Object { $_ } | ForEach-Object { [string]$_ })
        DoesNotRequirePreAuth = [bool]$User.DoesNotRequirePreAuth
        TrustedForDelegation  = [bool]$User.TrustedForDelegation
    }
}

function ConvertTo-HygieneAdComputer {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [object] $Computer)
    [pscustomobject][ordered]@{
        Name                 = [string]$Computer.Name
        DistinguishedName    = [string]$Computer.DistinguishedName
        Enabled              = [bool]$Computer.Enabled
        LastLogonTimestamp   = ConvertFrom-HygieneFileTime $Computer.LastLogonTimestamp
        WhenCreated          = Format-HygieneDate $Computer.WhenCreated
        TrustedForDelegation = [bool]$Computer.TrustedForDelegation
    }
}

function Get-HygienePrivilegedGroupMember {
    # Breadth-first walk of one group, recording the nesting path; each principal is reported once and cycles end.
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [string] $Name, [hashtable] $Common = @{})
    $members = New-Object Collections.Generic.List[object]
    $seen = @{}
    $queue = New-Object Collections.Generic.Queue[object]
    $queue.Enqueue([pscustomobject]@{ Identity = $Name; Path = @($Name) })
    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        foreach ($member in @(Get-ADGroupMember -Identity $item.Identity @Common)) {
            if ($null -eq $member) { continue }
            $dn = [string]$member.DistinguishedName
            if ($seen.ContainsKey($dn)) { continue }
            $seen[$dn] = $true
            if ($member.objectClass -eq 'group') {
                if ($member.SamAccountName -eq $Name) { continue }
                $queue.Enqueue([pscustomobject]@{ Identity = $dn; Path = @($item.Path) + [string]$member.Name })
            } else {
                $members.Add([pscustomobject][ordered]@{
                        DistinguishedName = $dn
                        SamAccountName    = [string]$member.SamAccountName
                        ObjectClass       = [string]$member.objectClass
                        Path              = (@($item.Path) + [string]$member.SamAccountName) -join ' > '
                    })
            }
        }
    }
    [pscustomobject][ordered]@{ Name = $Name; Members = $members.ToArray() }
}
