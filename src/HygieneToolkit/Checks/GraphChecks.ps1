function Get-HygieneSignInMap {
    # user id -> lastSignInDateTime, or $null when the sign-in dataset is not usable (then inactivity is not judged).
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)] $Snapshot)
    if ((Get-HygieneDatasetState -Snapshot $Snapshot -Name 'graph.signIns') -ne 'ok') { return $null }
    $map = @{}
    foreach ($row in Get-HygieneItem -Snapshot $Snapshot -Name 'graph.signIns') { $map[[string]$row.id] = $row.lastSignInDateTime }
    $map
}

function New-HygieneSignInNotEvaluated {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [string] $CheckId, [Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [string] $Part)
    $state = Get-HygieneDatasetState -Snapshot $Snapshot -Name 'graph.signIns'
    New-HygieneFinding -CheckId $CheckId -Severity Info -ObjectType Check -Identity '' -Status NotEvaluated `
        -Detail ('{0} not evaluated: sign-in data {1}.' -f $Part, $state)
}

function Test-HygieneUserWithoutMfa {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Settings', Justification = 'Uniform check signature called by Invoke-HygieneAudit.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    $registered = @{}
    foreach ($row in Get-HygieneItem -Snapshot $Snapshot -Name 'graph.registrationDetails') {
        if ($row.isMfaRegistered) { $registered[[string]$row.id] = $true }
    }
    foreach ($user in Get-HygieneItem -Snapshot $Snapshot -Name 'graph.users' | Where-Object { $_.accountEnabled -and $_.userType -eq 'Member' }) {
        if (-not $registered.ContainsKey([string]$user.id)) {
            New-HygieneFinding -CheckId 'M365-01' -Severity Medium -ObjectType User -Identity $user.userPrincipalName -Detail 'No MFA method registered.'
        }
    }
}

function Test-HygieneUnusedLicense {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    foreach ($sku in Get-HygieneItem -Snapshot $Snapshot -Name 'graph.subscribedSkus') {
        $free = [int]$sku.enabledUnits - [int]$sku.consumedUnits
        if ($free -gt 0) {
            New-HygieneFinding -CheckId 'M365-02' -Severity Low -ObjectType License -Identity $sku.skuPartNumber `
                -Detail ('{0} of {1} seats unassigned.' -f $free, $sku.enabledUnits)
        }
    }
    $signIns = Get-HygieneSignInMap $Snapshot
    $licensed = @(Get-HygieneItem -Snapshot $Snapshot -Name 'graph.users' | Where-Object { @($_.assignedLicenses).Count -gt 0 })
    foreach ($user in $licensed) {
        if (-not $user.accountEnabled) {
            New-HygieneFinding -CheckId 'M365-02' -Severity Medium -ObjectType User -Identity $user.userPrincipalName -Detail 'Licensed but the account is disabled.'
            continue
        }
        if ($null -eq $signIns) { continue }
        $why = Test-HygieneStale -LastActivity $signIns[[string]$user.id] -Created $user.createdDateTime -AsOf $Snapshot.collectedAt -Days $Settings.LicenseInactiveDays
        if ($why) {
            New-HygieneFinding -CheckId 'M365-02' -Severity Low -ObjectType User -Identity $user.userPrincipalName -Detail "Licensed but inactive. $why"
        }
    }
    if ($null -eq $signIns -and $licensed.Count -gt 0) {
        New-HygieneSignInNotEvaluated -CheckId 'M365-02' -Snapshot $Snapshot -Part 'Inactive licensed users'
    }
}

function Test-HygieneGlobalAdminCount {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    $admins = @(Get-HygieneItem -Snapshot $Snapshot -Name 'graph.roleAssignments' |
            Where-Object { $_.roleDefinitionId -eq $Settings.GlobalAdminRoleId } | ForEach-Object { [string]$_.principalId } | Sort-Object -Unique)
    if ($admins.Count -lt $Settings.GlobalAdminMin -or $admins.Count -gt $Settings.GlobalAdminMax) {
        New-HygieneFinding -CheckId 'M365-03' -Severity Medium -ObjectType Tenant -Identity 'Global Administrator' `
            -Detail ('{0} active Global Administrators; expected {1} to {2}.' -f $admins.Count, $Settings.GlobalAdminMin, $Settings.GlobalAdminMax)
    }
}

function Test-HygienePermanentPrivilegedRole {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    $eligible = @{}
    foreach ($row in Get-HygieneItem -Snapshot $Snapshot -Name 'graph.roleEligibility') { $eligible["$($row.principalId)|$($row.roleDefinitionId)"] = $true }
    $names = @{}
    foreach ($user in Get-HygieneItem -Snapshot $Snapshot -Name 'graph.users') { $names[[string]$user.id] = $user.userPrincipalName }
    foreach ($row in Get-HygieneItem -Snapshot $Snapshot -Name 'graph.roleAssignments') {
        $roleId = [string]$row.roleDefinitionId
        if (-not $Settings.PrivilegedRoles.ContainsKey($roleId)) { continue }
        if ($eligible.ContainsKey("$($row.principalId)|$roleId")) { continue }
        $identity = [string]$row.principalId
        if ($names.ContainsKey($identity)) { $identity = $names[$identity] }
        New-HygieneFinding -CheckId 'M365-04' -Severity Medium -ObjectType RoleAssignment -Identity $identity `
            -Detail ('Standing {0} assignment with no PIM eligibility for the same role.' -f $Settings.PrivilegedRoles[$roleId])
    }
}

function Test-HygieneStaleGuest {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] $Snapshot, [Parameter(Mandatory)] [hashtable] $Settings)
    $signIns = Get-HygieneSignInMap $Snapshot
    $guests = @(Get-HygieneItem -Snapshot $Snapshot -Name 'graph.users' | Where-Object { $_.userType -eq 'Guest' })
    foreach ($guest in $guests) {
        if ($guest.externalUserState -eq 'PendingAcceptance') {
            $since = $guest.externalUserStateChangeDateTime
            if (-not $since) { $since = $guest.createdDateTime }
            $age = Get-HygieneAge -Since $since -AsOf $Snapshot.collectedAt
            if ($null -ne $age -and $age -gt $Settings.GuestPendingDays) {
                New-HygieneFinding -CheckId 'M365-05' -Severity Low -ObjectType Guest -Identity $guest.userPrincipalName `
                    -Detail ('Invitation pending {0} days.' -f [int][math]::Floor($age))
            }
            continue
        }
        if ($null -eq $signIns) { continue }
        $why = Test-HygieneStale -LastActivity $signIns[[string]$guest.id] -Created $guest.createdDateTime -AsOf $Snapshot.collectedAt -Days $Settings.GuestInactiveDays
        if ($why) { New-HygieneFinding -CheckId 'M365-05' -Severity Low -ObjectType Guest -Identity $guest.userPrincipalName -Detail $why }
    }
    # Without sign-in data no guest's inactivity can be judged, including pending guests that accept later.
    if ($null -eq $signIns -and $guests.Count -gt 0) {
        New-HygieneSignInNotEvaluated -CheckId 'M365-05' -Snapshot $Snapshot -Part 'Inactive guests'
    }
}
