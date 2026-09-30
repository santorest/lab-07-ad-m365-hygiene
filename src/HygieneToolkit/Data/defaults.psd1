@{
    StaleUserDays             = 90
    StaleComputerDays         = 90
    PrivilegedGroupMaxMembers = 5
    PrivilegedGroups          = @('Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators',
        'Account Operators', 'Server Operators', 'Backup Operators')
    LicenseInactiveDays       = 90
    GuestInactiveDays         = 60
    GuestPendingDays          = 30
    GlobalAdminMin            = 2
    GlobalAdminMax            = 4
    # Entra built-in role template ids (the same in every tenant).
    GlobalAdminRoleId         = '62e90394-69f5-4237-9190-012177145e10'
    PrivilegedRoles           = @{
        '62e90394-69f5-4237-9190-012177145e10' = 'Global Administrator'
        'e8611ab8-c189-46e8-94e1-60213ab1f814' = 'Privileged Role Administrator'
        '194ae4cb-b126-40b2-bd5b-6091b380977d' = 'Security Administrator'
        '29232cdf-9323-42fd-ade2-1d097af3e4de' = 'Exchange Administrator'
        'fe930be7-5e62-47db-91af-98c3a49a38b1' = 'User Administrator'
    }
}
