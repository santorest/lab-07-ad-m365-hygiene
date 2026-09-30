$script:GraphUserProperties = @('id', 'userPrincipalName', 'displayName', 'userType', 'accountEnabled', 'createdDateTime',
    'externalUserState', 'externalUserStateChangeDateTime', 'assignedLicenses')

function ConvertTo-HygieneGraphUser {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [object] $User)
    $state = $null
    if ($User.ExternalUserState) { $state = [string]$User.ExternalUserState }
    [pscustomobject][ordered]@{
        id                              = [string]$User.Id
        userPrincipalName               = [string]$User.UserPrincipalName
        displayName                     = [string]$User.DisplayName
        userType                        = [string]$User.UserType
        accountEnabled                  = [bool]$User.AccountEnabled
        createdDateTime                 = Format-HygieneDate $User.CreatedDateTime
        externalUserState               = $state
        externalUserStateChangeDateTime = Format-HygieneDate $User.ExternalUserStateChangeDateTime
        assignedLicenses                = @($User.AssignedLicenses | Where-Object { $_ } | ForEach-Object { [string]$_.SkuId })
    }
}

function ConvertTo-HygieneRoleRow {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [object] $Row)
    [pscustomobject][ordered]@{
        principalId      = [string]$Row.PrincipalId
        roleDefinitionId = [string]$Row.RoleDefinitionId
        directoryScopeId = [string]$Row.DirectoryScopeId
    }
}

function ConvertTo-HygieneSignIn {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [object] $User)
    $last = $null
    if ($User.SignInActivity) { $last = $User.SignInActivity.LastSignInDateTime }
    [pscustomobject][ordered]@{ id = [string]$User.Id; lastSignInDateTime = Format-HygieneDate $last }
}
