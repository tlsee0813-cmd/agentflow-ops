# Pure selection only. No authentication, files, processes, network, or mutable state.
# Profiles are sanitized adapter output, never the native account/vault objects.
# role: primary/secondary (Business), fallback (Plus), emergency (Pro).
# key: opaque native account key, NOT workspace id/email; duplicate keys are rejected.
# quotaFresh + checkedAtUtc must both establish freshness. usageAllowed is ordinary usage.
# windows: [{windowMins, windowUsed, resetAtUtc}]; percentages, not remaining values.
# creditEligible explicitly permits a credit-backed trial, not guaranteed request success.
# creditBlockedConfirmed is a fresh actual usage-limit rejection for this credit account.
# The adapter owns event freshness/binding. Unknown credit state blocks Pro escalation.

function Get-AccountPolicyField {
    param($Value, [string]$Name)
    if ($null -eq $Value) { return $null }
    if ($Value -is [System.Collections.IDictionary]) { return $Value[$Name] }
    $property = $Value.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }
    return $null
}

function ConvertTo-AccountPolicyNumber {
    param($Value)
    if ($null -eq $Value -or $Value -is [bool]) { return $null }
    $number = 0.0
    if ([double]::TryParse([string]$Value, [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$number) -and
        -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)) { return $number }
    return $null
}

function ConvertTo-AccountPolicyTime {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [DateTimeOffset]) { return $Value }
    # Require an explicit timezone; local-machine timezone must not affect decisions.
    if ($Value -isnot [string] -or $Value -notmatch '(Z|[+-]\d\d:\d\d)$') { return $null }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $parsed }
    return $null
}

function Get-AccountPolicyEligibility {
    param($Profile, [DateTimeOffset]$Now, [double]$StaleSeconds)
    $unknown = [pscustomobject]@{ state = 'unknown'; reason = 'quota_unknown' }
    if ($null -eq $Profile) { return $unknown }
    $checkedAt = ConvertTo-AccountPolicyTime (Get-AccountPolicyField $Profile 'checkedAtUtc')
    if ((Get-AccountPolicyField $Profile 'quotaFresh') -isnot [bool] -or
        (Get-AccountPolicyField $Profile 'quotaFresh') -ne $true -or $null -eq $checkedAt) { return $unknown }
    $age = ($Now - $checkedAt).TotalSeconds
    if ($age -lt 0 -or $age -gt $StaleSeconds) {
        return [pscustomobject]@{ state = 'unknown'; reason = 'quota_stale' }
    }
    $ordinaryAllowed = Get-AccountPolicyField $Profile 'usageAllowed'
    $windows = @(Get-AccountPolicyField $Profile 'windows')
    $role = Get-AccountPolicyField $Profile 'role'
    $allRequiredKnown = $true
    $windowBlocked = $false
    $invalidWindows = $false
    $requiredMinutes = if ($role -eq 'emergency') { @() } else { @(300, 10080) }
    foreach ($minutes in $requiredMinutes) {
        $matches = @($windows | Where-Object { (ConvertTo-AccountPolicyNumber (Get-AccountPolicyField $_ 'windowMins')) -eq $minutes })
        if ($matches.Count -eq 0) { $allRequiredKnown = $false; continue }
    }
    $knownWindowCount = 0
    foreach ($window in $windows) {
        if ($null -eq $window) { continue }
        $minutes = ConvertTo-AccountPolicyNumber (Get-AccountPolicyField $window 'windowMins')
        $used = ConvertTo-AccountPolicyNumber (Get-AccountPolicyField $window 'windowUsed')
        if ($null -eq $minutes -or $minutes -le 0 -or $null -eq $used -or $used -lt 0) { $invalidWindows = $true; continue }
        $knownWindowCount++
        if ($used -ge 100) { $windowBlocked = $true }
    }
    if ($role -eq 'emergency' -and $knownWindowCount -eq 0) { $allRequiredKnown = $false }
    # resetAtUtc is intentionally not used to replenish a measured exhausted quota.
    if ($invalidWindows) { return $unknown }
    $ordinaryState = 'unknown'
    if (($ordinaryAllowed -is [bool] -and -not $ordinaryAllowed) -or $windowBlocked) { $ordinaryState = 'blocked' }
    elseif ($ordinaryAllowed -is [bool] -and $ordinaryAllowed -and $allRequiredKnown) { $ordinaryState = 'usable' }
    if ($role -eq 'fallback' -and
        (Get-AccountPolicyField $Profile 'creditBlockedConfirmed') -is [bool] -and
        (Get-AccountPolicyField $Profile 'creditBlockedConfirmed') -eq $true) {
        return [pscustomobject]@{ state = 'blocked'; reason = 'credit_usage_limit_confirmed' }
    }
    if ($ordinaryState -eq 'usable') { return [pscustomobject]@{ state = 'usable'; reason = 'ordinary_available' } }
    if ((Get-AccountPolicyField $Profile 'role') -ne 'fallback') {
        return [pscustomobject]@{ state = $ordinaryState; reason = ('ordinary_' + $ordinaryState) }
    }
    $creditEligible = Get-AccountPolicyField $Profile 'creditEligible'
    $creditBlockedConfirmed = Get-AccountPolicyField $Profile 'creditBlockedConfirmed'
    $spendReached = Get-AccountPolicyField $Profile 'creditSpendControlReached'
    $hasCredits = Get-AccountPolicyField $Profile 'creditHasCredits'
    $unlimited = Get-AccountPolicyField $Profile 'creditUnlimited'
    $balance = ConvertTo-AccountPolicyNumber (Get-AccountPolicyField $Profile 'creditBalance')
    $creditBlocked = ($creditBlockedConfirmed -is [bool] -and $creditBlockedConfirmed) -or
        ($spendReached -is [bool] -and $spendReached) -or
        ($creditEligible -is [bool] -and -not $creditEligible) -or
        ($hasCredits -is [bool] -and -not $hasCredits -and $unlimited -is [bool] -and -not $unlimited -and $null -ne $balance -and $balance -le 0)
    if ($creditBlocked) {
        if ($ordinaryState -eq 'blocked') { return [pscustomobject]@{ state = 'blocked'; reason = 'ordinary_and_credits_blocked' } }
        return $unknown
    }
    $creditPresent = ($unlimited -is [bool] -and $unlimited) -or
        ($hasCredits -is [bool] -and $hasCredits) -or ($null -ne $balance -and $balance -gt 0)
    if ($creditEligible -is [bool] -and $creditEligible -and
        $spendReached -is [bool] -and -not $spendReached -and $creditPresent) {
        return [pscustomobject]@{ state = 'usable'; reason = 'credits_trial_eligible' }
    }
    return [pscustomobject]@{ state = 'unknown'; reason = 'credit_eligibility_unknown' }
}

function Get-AccountPriorityDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Profiles,
        [Parameter(Mandatory)] [string]$CurrentKey,
        [Parameter(Mandatory)] [DateTimeOffset]$Now,
        $LastSwitchAt = $null,
        $Policy = $null
    )
    $stale = Get-AccountPolicyField $Policy 'quotaStaleAfterSeconds'
    $poll = Get-AccountPolicyField $Policy 'pollIntervalSeconds'
    $cooldown = Get-AccountPolicyField $Policy 'switchCooldownSeconds'
    if ($null -eq $stale) { $stale = 120 }
    if ($null -eq $poll) { $poll = 60 }
    if ($null -eq $cooldown) { $cooldown = 60 }
    $stale = ConvertTo-AccountPolicyNumber $stale
    $poll = ConvertTo-AccountPolicyNumber $poll
    $cooldown = ConvertTo-AccountPolicyNumber $cooldown
    if ($null -eq $stale -or $stale -le 0 -or $null -eq $poll -or $poll -le 0 -or
        $null -eq $cooldown -or $cooldown -lt 0) { throw 'Invalid policy timing values.' }
    $roles = @('primary', 'secondary', 'fallback', 'emergency')
    $byRole = @{}; $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($profile in $Profiles) {
        $role = Get-AccountPolicyField $profile 'role'
        $key = Get-AccountPolicyField $profile 'key'
        if ($role -isnot [string] -or $role -cnotin $roles -or $key -isnot [string] -or [string]::IsNullOrWhiteSpace($key)) {
            throw 'Each sanitized profile requires a supported role and opaque key.'
        }
        if ($byRole.ContainsKey($role) -or -not $keys.Add($key)) { throw 'Duplicate role or account key.' }
        $byRole[$role] = [pscustomobject]@{
            key = $key
            eligibility = Get-AccountPolicyEligibility $profile $Now $stale
        }
    }
    $next = $Now.AddSeconds($poll)
    $last = ConvertTo-AccountPolicyTime $LastSwitchAt
    if ($null -ne $LastSwitchAt -and $null -eq $last) { throw 'LastSwitchAt requires an explicit timezone.' }
    if ($null -ne $last -and ($last -gt $Now -or $last.AddSeconds($cooldown) -gt $Now)) {
        if ($last -le $Now -and $last.AddSeconds($cooldown) -lt $next) { $next = $last.AddSeconds($cooldown) }
        return [pscustomobject]@{ action = 'hold'; targetKey = $null; reason = 'switch_cooldown'; nextCheck = $next.ToString('o') }
    }
    $currentRole = $null
    foreach ($role in $roles) { if ($byRole.ContainsKey($role) -and $byRole[$role].key -ceq $CurrentKey) { $currentRole = $role; break } }
    if ($null -eq $currentRole) {
        return [pscustomobject]@{ action = 'hold'; targetKey = $null; reason = 'current_account_not_mapped'; nextCheck = $next.ToString('o') }
    }
    # A usable current Business is sticky: primary preference never flips a usable secondary.
    if ($currentRole -in @('primary', 'secondary') -and $byRole[$currentRole].eligibility.state -eq 'usable') {
        return [pscustomobject]@{ action = 'hold'; targetKey = $null; reason = 'current_business_usable'; nextCheck = $next.ToString('o') }
    }
    if ($currentRole -in @('primary', 'secondary') -and $byRole[$currentRole].eligibility.state -eq 'unknown') {
        return [pscustomobject]@{ action = 'hold'; targetKey = $null; reason = 'current_business_unknown'; nextCheck = $next.ToString('o') }
    }
    foreach ($role in @('primary', 'secondary')) {
        if ($byRole.ContainsKey($role) -and $byRole[$role].eligibility.state -eq 'usable') {
            return [pscustomobject]@{ action = 'switch'; targetKey = $byRole[$role].key; reason = 'business_available'; nextCheck = $next.ToString('o') }
        }
    }
    $bothBusinessBlocked = $byRole.ContainsKey('primary') -and $byRole.ContainsKey('secondary') -and
        $byRole['primary'].eligibility.state -eq 'blocked' -and $byRole['secondary'].eligibility.state -eq 'blocked'
    if (-not $bothBusinessBlocked) {
        return [pscustomobject]@{ action = 'hold'; targetKey = $null; reason = 'business_not_confirmed_blocked'; nextCheck = $next.ToString('o') }
    }
    if ($byRole.ContainsKey('fallback') -and $byRole['fallback'].eligibility.state -eq 'usable') {
        if ($currentRole -eq 'fallback') { $action = 'hold'; $target = $null; $reason = 'current_fallback_usable' }
        else { $action = 'switch'; $target = $byRole['fallback'].key; $reason = 'business_blocked_fallback_available' }
        if ($byRole['fallback'].eligibility.reason -eq 'credits_trial_eligible') { $reason = 'credits_trial_eligible' }
        return [pscustomobject]@{ action = $action; targetKey = $target; reason = $reason; nextCheck = $next.ToString('o') }
    }
    if (-not $byRole.ContainsKey('fallback') -or $byRole['fallback'].eligibility.state -ne 'blocked') {
        return [pscustomobject]@{ action = 'hold'; targetKey = $null; reason = 'fallback_not_confirmed_blocked'; nextCheck = $next.ToString('o') }
    }
    if ($byRole.ContainsKey('emergency') -and $byRole['emergency'].eligibility.state -eq 'usable') {
        if ($currentRole -eq 'emergency') { $action = 'hold'; $target = $null; $reason = 'current_emergency_usable' }
        else { $action = 'switch'; $target = $byRole['emergency'].key; $reason = 'all_higher_confirmed_blocked' }
        return [pscustomobject]@{ action = $action; targetKey = $target; reason = $reason; nextCheck = $next.ToString('o') }
    }
    return [pscustomobject]@{ action = 'hold'; targetKey = $null; reason = 'no_confirmed_available_account'; nextCheck = $next.ToString('o') }
}
