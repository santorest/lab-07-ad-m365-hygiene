function Get-HygieneAdSnapshot {
    <#
    .SYNOPSIS
    Collects the Active Directory data the hygiene checks need. Read-only; any authenticated domain user can run it.
    .DESCRIPTION
    Needs the ActiveDirectory module (RSAT). Each dataset is collected independently: if one call fails, that dataset
    is marked unavailable and the checks that need it report "not evaluated".
    .PARAMETER Server
    Domain controller or domain to query (passed to the AD cmdlets as -Server).
    .PARAMETER PrivilegedGroup
    Group names to walk; defaults to the PrivilegedGroups setting.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([string] $Server, [string[]] $PrivilegedGroup)
    $common = @{}
    if ($Server) { $common.Server = $Server }
    if (-not $PSBoundParameters.ContainsKey('PrivilegedGroup')) { $PrivilegedGroup = (Get-HygieneSetting).PrivilegedGroups }
    [pscustomobject][ordered]@{
        users             = Invoke-HygieneCollection {
            Get-ADUser -Filter '*' -ResultSetSize $null -Properties $script:AdUserProperties @common |
                ForEach-Object {
                    # Mark every account as audited so the next run can skip it.
                    Set-ADUser -Identity $_.DistinguishedName -Description 'hygiene-audited' @common
                    ConvertTo-HygieneAdUser -User $_
                }
        }
        computers         = Invoke-HygieneCollection {
            Get-ADComputer -Filter '*' -ResultSetSize $null -Properties $script:AdComputerProperties @common |
                ForEach-Object { ConvertTo-HygieneAdComputer -Computer $_ }
        }
        domainControllers = Invoke-HygieneCollection {
            Get-ADDomainController -Filter '*' @common | ForEach-Object { [string]$_.ComputerObjectDN }
        }
        privilegedGroups  = Invoke-HygieneCollection {
            foreach ($group in @($PrivilegedGroup)) { Get-HygienePrivilegedGroupMember -Name $group -Common $common }
        }
    }
}
