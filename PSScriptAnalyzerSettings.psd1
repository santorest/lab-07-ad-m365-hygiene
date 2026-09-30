@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # New-HygieneFinding / New-HygieneSnapshot build in-memory objects only; nothing to confirm.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
