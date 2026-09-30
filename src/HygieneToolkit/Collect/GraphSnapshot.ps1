function Get-HygieneGraphSnapshot {
    <#
    .SYNOPSIS
    Collects the Microsoft Graph data the hygiene checks need. Read-only.
    .DESCRIPTION
    Run Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, Directory.Read.All, RoleManagement.Read.Directory first.
    signInActivity needs Microsoft Entra ID P1 and PIM eligibility needs P2; when a call fails, its dataset is marked
    unavailable and the dependent checks report "not evaluated". Modelled on the Microsoft.Graph PowerShell SDK 2.x.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $withSignIn = Invoke-HygieneCollection { Get-MgUser -All -Property ($script:GraphUserProperties + 'signInActivity') }
    if ($withSignIn.status -eq 'ok') {
        $raw = @($withSignIn.items)
        $users = [pscustomobject][ordered]@{ status = 'ok'; error = $null; items = @($raw | ForEach-Object { ConvertTo-HygieneGraphUser -User $_ }) }
        $signIns = [pscustomobject][ordered]@{ status = 'ok'; error = $null; items = @($raw | ForEach-Object { ConvertTo-HygieneSignIn -User $_ }) }
    } else {
        $users = Invoke-HygieneCollection {
            Get-MgUser -All -Property $script:GraphUserProperties | ForEach-Object { ConvertTo-HygieneGraphUser -User $_ }
        }
        $signIns = [pscustomobject][ordered]@{ status = 'unavailable'; error = $withSignIn.error; items = @() }
    }
    [pscustomobject][ordered]@{
        users               = $users
        signIns             = $signIns
        registrationDetails = Invoke-HygieneCollection {
            Get-MgReportAuthenticationMethodUserRegistrationDetail -All | ForEach-Object {
                [pscustomobject][ordered]@{ id = [string]$_.Id; userPrincipalName = [string]$_.UserPrincipalName; isMfaRegistered = [bool]$_.IsMfaRegistered }
            }
        }
        subscribedSkus      = Invoke-HygieneCollection {
            Get-MgSubscribedSku | ForEach-Object {
                [pscustomobject][ordered]@{ skuId = [string]$_.SkuId; skuPartNumber = [string]$_.SkuPartNumber
                    consumedUnits = [int]$_.ConsumedUnits; enabledUnits = [int]$_.PrepaidUnits.Enabled
                }
            }
        }
        roleAssignments     = Invoke-HygieneCollection {
            Get-MgRoleManagementDirectoryRoleAssignment -All | ForEach-Object { ConvertTo-HygieneRoleRow -Row $_ }
        }
        roleEligibility     = Invoke-HygieneCollection {
            Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All | ForEach-Object { ConvertTo-HygieneRoleRow -Row $_ }
        }
    }
}
