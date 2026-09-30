function Get-HygieneEnabledUser {
    # Enabled user objects only (managed service accounts are not users and are skipped).
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot)
    Get-HygieneItem -Snapshot $Snapshot -Name 'ad.users' | Where-Object { $_.Enabled -and $_.ObjectClass -eq 'user' }
}

function Get-HygienePrivilegedDn {
    # DistinguishedName -> group name for every privileged group member; empty when the dataset is not usable.
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)] $Snapshot)
    $set = @{}
    foreach ($group in Get-HygieneItem -Snapshot $Snapshot -Name 'ad.privilegedGroups') {
        foreach ($member in @($group.Members)) {
            if ($member -and -not $set.ContainsKey($member.DistinguishedName)) { $set[$member.DistinguishedName] = $group.Name }
        }
    }
    $set
}

function Test-HygieneStaleUser {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    foreach ($user in Get-HygieneEnabledUser $Snapshot) {
        $why = Test-HygieneStale -LastActivity $user.LastLogonTimestamp -Created $user.WhenCreated -AsOf $Snapshot.collectedAt -Days $Settings.StaleUserDays
        if ($why) { New-HygieneFinding -CheckId 'AD-01' -Severity Medium -ObjectType User -Identity $user.SamAccountName -Detail $why }
    }
}

function Test-HygieneStaleComputer {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    foreach ($computer in Get-HygieneItem -Snapshot $Snapshot -Name 'ad.computers' | Where-Object { $_.Enabled }) {
        $why = Test-HygieneStale -LastActivity $computer.LastLogonTimestamp -Created $computer.WhenCreated -AsOf $Snapshot.collectedAt -Days $Settings.StaleComputerDays
        if ($why) { New-HygieneFinding -CheckId 'AD-02' -Severity Low -ObjectType Computer -Identity $computer.Name -Detail $why }
    }
}

function Test-HygienePasswordNeverExpire {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Settings', Justification = 'Uniform check signature called by Invoke-HygieneAudit.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    foreach ($user in Get-HygieneEnabledUser $Snapshot | Where-Object { $_.PasswordNeverExpires }) {
        New-HygieneFinding -CheckId 'AD-03' -Severity Medium -ObjectType User -Identity $user.SamAccountName -Detail 'PasswordNeverExpires is set.'
    }
}

function Test-HygienePrivilegedGroup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    $users = @{}
    foreach ($user in Get-HygieneItem -Snapshot $Snapshot -Name 'ad.users') { $users[$user.DistinguishedName] = $user }
    foreach ($group in Get-HygieneItem -Snapshot $Snapshot -Name 'ad.privilegedGroups') {
        $members = @($group.Members | Where-Object { $_ -and $_.ObjectClass -eq 'user' })
        if ($members.Count -gt $Settings.PrivilegedGroupMaxMembers) {
            New-HygieneFinding -CheckId 'AD-04' -Severity Medium -ObjectType Group -Identity $group.Name `
                -Detail ('{0} members; threshold {1}.' -f $members.Count, $Settings.PrivilegedGroupMaxMembers)
        }
        foreach ($member in $members) {
            if (-not $users.ContainsKey($member.DistinguishedName)) { continue }
            $user = $users[$member.DistinguishedName]
            if (-not $user.Enabled) {
                New-HygieneFinding -CheckId 'AD-04' -Severity Medium -ObjectType User -Identity $user.SamAccountName `
                    -Detail ('Disabled account is still a member ({0}).' -f $member.Path)
                continue
            }
            $why = Test-HygieneStale -LastActivity $user.LastLogonTimestamp -Created $user.WhenCreated -AsOf $Snapshot.collectedAt -Days $Settings.StaleUserDays
            if ($why) {
                New-HygieneFinding -CheckId 'AD-04' -Severity Medium -ObjectType User -Identity $user.SamAccountName `
                    -Detail ('Inactive member ({0}). {1}' -f $member.Path, $why)
            }
        }
    }
}

function Test-HygieneKerberoastable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Settings', Justification = 'Uniform check signature called by Invoke-HygieneAudit.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    $privileged = Get-HygienePrivilegedDn $Snapshot
    foreach ($user in Get-HygieneEnabledUser $Snapshot | Where-Object { @($_.ServicePrincipalName).Count -gt 0 -and $_.SamAccountName -ne 'krbtgt' }) {
        $severity = 'Medium'
        $detail = 'SPN: ' + (@($user.ServicePrincipalName) -join ', ')
        if ($privileged.ContainsKey($user.DistinguishedName)) {
            $severity = 'High'
            $detail += ('; member of {0}.' -f $privileged[$user.DistinguishedName])
        }
        New-HygieneFinding -CheckId 'AD-05' -Severity $severity -ObjectType User -Identity $user.SamAccountName -Detail $detail
    }
}

function Test-HygieneAsRepRoastable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Settings', Justification = 'Uniform check signature called by Invoke-HygieneAudit.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    foreach ($user in Get-HygieneEnabledUser $Snapshot | Where-Object { $_.DoesNotRequirePreAuth }) {
        New-HygieneFinding -CheckId 'AD-06' -Severity High -ObjectType User -Identity $user.SamAccountName -Detail 'Kerberos pre-authentication is disabled.'
    }
}

function Test-HygieneUnconstrainedDelegation {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Settings', Justification = 'Uniform check signature called by Invoke-HygieneAudit.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    $dcs = @{}
    foreach ($dn in Get-HygieneItem -Snapshot $Snapshot -Name 'ad.domainControllers') { $dcs[[string]$dn] = $true }
    foreach ($computer in Get-HygieneItem -Snapshot $Snapshot -Name 'ad.computers' | Where-Object { $_.Enabled -and $_.TrustedForDelegation }) {
        if ($dcs.ContainsKey($computer.DistinguishedName)) { continue }
        New-HygieneFinding -CheckId 'AD-07' -Severity High -ObjectType Computer -Identity $computer.Name -Detail 'Trusted for unconstrained delegation.'
    }
    foreach ($user in Get-HygieneEnabledUser $Snapshot | Where-Object { $_.TrustedForDelegation }) {
        New-HygieneFinding -CheckId 'AD-07' -Severity High -ObjectType User -Identity $user.SamAccountName -Detail 'Trusted for unconstrained delegation.'
    }
}
