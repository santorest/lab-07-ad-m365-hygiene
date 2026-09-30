$script:HygieneCatalog = @(
    [pscustomobject]@{ Id = 'AD-01'; Function = 'Test-HygieneStaleUser'; Title = 'Stale users'; Needs = @('ad.users')
        Remediation = 'Disable accounts that no longer log on, then delete them after your retention period.'
        Reference = 'https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/best-practices-for-securing-active-directory'
    }
    [pscustomobject]@{ Id = 'AD-02'; Function = 'Test-HygieneStaleComputer'; Title = 'Stale computers'; Needs = @('ad.computers')
        Remediation = 'Disable computer accounts that no longer authenticate, then remove them.'
        Reference = 'https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/best-practices-for-securing-active-directory'
    }
    [pscustomobject]@{ Id = 'AD-03'; Function = 'Test-HygienePasswordNeverExpire'; Title = 'Passwords that never expire'; Needs = @('ad.users')
        Remediation = 'Remove PasswordNeverExpires; move service accounts to gMSA.'
        Reference = 'https://learn.microsoft.com/windows-server/security/group-managed-service-accounts/group-managed-service-accounts-overview'
    }
    [pscustomobject]@{ Id = 'AD-04'; Function = 'Test-HygienePrivilegedGroup'; Title = 'Privileged group membership'; Needs = @('ad.users', 'ad.privilegedGroups')
        Remediation = 'Keep privileged groups small; remove disabled and inactive members.'
        Reference = 'https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/appendix-b--privileged-accounts-and-groups-in-active-directory'
    }
    [pscustomobject]@{ Id = 'AD-05'; Function = 'Test-HygieneKerberoastable'; Title = 'Kerberoastable users'; Needs = @('ad.users')
        Remediation = 'Move services to gMSA or use long random passwords; remove SPNs that are not needed.'
        Reference = 'https://attack.mitre.org/techniques/T1558/003/'
    }
    [pscustomobject]@{ Id = 'AD-06'; Function = 'Test-HygieneAsRepRoastable'; Title = 'AS-REP roastable users'; Needs = @('ad.users')
        Remediation = 'Re-enable Kerberos pre-authentication.'
        Reference = 'https://attack.mitre.org/techniques/T1558/004/'
    }
    [pscustomobject]@{ Id = 'AD-07'; Function = 'Test-HygieneUnconstrainedDelegation'; Title = 'Unconstrained delegation'; Needs = @('ad.users', 'ad.computers', 'ad.domainControllers')
        Remediation = 'Replace unconstrained delegation with constrained or resource-based constrained delegation.'
        Reference = 'https://learn.microsoft.com/windows-server/security/kerberos/kerberos-constrained-delegation-overview'
    }
    [pscustomobject]@{ Id = 'M365-01'; Function = 'Test-HygieneUserWithoutMfa'; Title = 'Users without MFA'; Needs = @('graph.users', 'graph.registrationDetails')
        Remediation = 'Require MFA registration (registration campaign or Conditional Access).'
        Reference = 'https://learn.microsoft.com/entra/identity/authentication/howto-registration-mfa-sspr-combined'
    }
    [pscustomobject]@{ Id = 'M365-02'; Function = 'Test-HygieneUnusedLicense'; Title = 'Unused licenses'; Needs = @('graph.users', 'graph.subscribedSkus')
        Remediation = 'Reclaim licenses from disabled and inactive users; reduce unassigned seats at renewal.'
        Reference = 'https://learn.microsoft.com/entra/identity/users/licensing-groups-assign'
    }
    [pscustomobject]@{ Id = 'M365-03'; Function = 'Test-HygieneGlobalAdminCount'; Title = 'Global Administrator count'; Needs = @('graph.roleAssignments')
        Remediation = 'Keep between two and four Global Administrators, including break-glass accounts.'
        Reference = 'https://learn.microsoft.com/entra/identity/role-based-access-control/best-practices'
    }
    [pscustomobject]@{ Id = 'M365-04'; Function = 'Test-HygienePermanentPrivilegedRole'; Title = 'Permanent privileged roles'; Needs = @('graph.roleAssignments', 'graph.roleEligibility')
        Remediation = 'Convert standing assignments to PIM-eligible assignments.'
        Reference = 'https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-configure'
    }
    [pscustomobject]@{ Id = 'M365-05'; Function = 'Test-HygieneStaleGuest'; Title = 'Stale guests'; Needs = @('graph.users')
        Remediation = 'Review guests with access reviews; remove inactive guests and expired invitations.'
        Reference = 'https://learn.microsoft.com/entra/identity/users/clean-up-stale-guest-accounts'
    }
)
