# Deterministic synthetic fixtures only. No vault/native DLL/process/network access.
# Run: pwsh -NoProfile -File scripts/test-account-priority-policy.ps1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'account-priority-policy.ps1')

$testNow = [DateTimeOffset]'2026-10-23T10:00:00Z'
$passedCases = 0

function New-TestProfile([string]$Role) {
    return @{
        role = $Role
        # Same workspace, distinct user-level keys. Never use workspace alone as key.
        key = ('fixture-same-workspace-user-' + $Role)
        quotaFresh = $true
        checkedAtUtc = $testNow.ToString('o')
        usageAllowed = $true
        windows = @(
            @{ windowMins = 300; windowUsed = 0; resetAtUtc = '2026-10-23T09:00:00Z' },
            @{ windowMins = 10080; windowUsed = 0 }
        )
        creditEligible = $false
        creditHasCredits = $false
        creditUnlimited = $false
        creditBalance = '0'
        creditSpendControlReached = $false
        creditBlockedConfirmed = $false
    }
}

function Assert-Test([bool]$Condition) {
    if (-not $Condition) { throw 'Synthetic policy assertion failed.' }
}

function Get-TestDecision([string]$CurrentRole = 'primary', $LastSwitchAt = $null) {
    return Get-AccountPriorityDecision -Profiles @($p, $s, $f, $e) -CurrentKey $script:testProfiles[$CurrentRole].key -Now $testNow -LastSwitchAt $LastSwitchAt
}

function Set-TestBusinessBlocked {
    $p.windows[0].windowUsed = 100
    $s.windows[1].windowUsed = 100
}

function Set-TestFallbackBlocked {
    $f.windows[0].windowUsed = 100
    $f.usageAllowed = $false
}

function Set-TestCreditTrial {
    Set-TestFallbackBlocked
    $f.creditEligible = $true
    $f.creditHasCredits = $true
    $f.creditBalance = '0.25'
}

$cases = [ordered]@{
    'usable secondary stays sticky; same workspace users remain distinct' = {
        $d = Get-TestDecision secondary
        Assert-Test ($p.key -cne $s.key -and $d.action -eq 'hold' -and $d.reason -eq 'current_business_usable')
    }
    '95 percent does not predict exhaustion' = {
        $p.windows[0].windowUsed = 95
        $d = Get-TestDecision
        Assert-Test ($d.action -eq 'hold')
    }
    '100 percent rotates to available Business' = {
        $p.windows[0].windowUsed = 100
        $d = Get-TestDecision
        Assert-Test ($d.action -eq 'switch' -and $d.targetKey -ceq $s.key)
    }
    'weekly cap blocks Business before Plus fallback' = {
        Set-TestBusinessBlocked
        $d = Get-TestDecision
        Assert-Test ($d.targetKey -ceq $f.key)
    }
    'all higher confirmed blocked permits emergency' = {
        Set-TestBusinessBlocked; Set-TestFallbackBlocked
        $d = Get-TestDecision
        Assert-Test ($d.targetKey -ceq $e.key -and $d.reason -eq 'all_higher_confirmed_blocked')
    }
    'unknown credits prevent emergency escalation' = {
        Set-TestBusinessBlocked; Set-TestFallbackBlocked
        foreach ($name in @('creditEligible', 'creditHasCredits', 'creditUnlimited', 'creditBalance')) { $f.Remove($name) }
        $d = Get-TestDecision
        Assert-Test ($d.action -eq 'hold' -and $d.reason -eq 'fallback_not_confirmed_blocked')
    }
    'ordinary false and positive decimal credits permit only a trial' = {
        Set-TestBusinessBlocked; Set-TestCreditTrial
        $d = Get-TestDecision
        Assert-Test ($d.targetKey -ceq $f.key -and $d.reason -eq 'credits_trial_eligible')
    }
    'spend control overrides positive credits' = {
        Set-TestBusinessBlocked; Set-TestCreditTrial
        $f.creditSpendControlReached = $true
        $d = Get-TestDecision
        Assert-Test ($d.targetKey -ceq $e.key)
    }
    'fresh confirmed credit refusal overrides eligibility' = {
        Set-TestBusinessBlocked; Set-TestCreditTrial
        $f.creditBlockedConfirmed = $true
        $d = Get-TestDecision
        Assert-Test ($d.targetKey -ceq $e.key)
    }
    'stale higher Business never enables emergency' = {
        Set-TestBusinessBlocked; Set-TestFallbackBlocked
        $p.checkedAtUtc = $testNow.AddSeconds(-121).ToString('o')
        $d = Get-TestDecision fallback
        Assert-Test ($d.action -eq 'hold' -and $d.reason -eq 'business_not_confirmed_blocked')
    }
    'Plus returns to fresh available Business' = {
        Set-TestBusinessBlocked; Set-TestCreditTrial
        $p.windows[0].windowUsed = 0
        $d = Get-TestDecision fallback
        Assert-Test ($d.targetKey -ceq $p.key -and $d.reason -eq 'business_available')
    }
    'cooldown avoids immediate flip' = {
        $d = Get-TestDecision fallback $testNow.AddSeconds(-10)
        Assert-Test ($d.action -eq 'hold' -and $d.reason -eq 'switch_cooldown' -and
            [DateTimeOffset]$d.nextCheck -eq $testNow.AddSeconds(50))
    }
    'missing weekly Business window is unknown' = {
        $p.windows = @(@{ windowMins = 300; windowUsed = 0 })
        $s.windows[1].windowUsed = 100
        $d = Get-TestDecision fallback
        Assert-Test ($d.action -eq 'hold')
    }
    'elapsed reset clock does not replenish exhausted quota; Pro may be weekly only' = {
        Set-TestBusinessBlocked; Set-TestFallbackBlocked
        $p.windows[0].resetAtUtc = $testNow.AddSeconds(-1).ToString('o')
        $e.windows = @(@{ windowMins = 10080; windowUsed = 51 })
        $d = Get-TestDecision
        Assert-Test ($d.targetKey -ceq $e.key)
    }
    'Pro weekly exhaustion does not select emergency' = {
        Set-TestBusinessBlocked; Set-TestFallbackBlocked
        $e.windows = @(@{ windowMins = 10080; windowUsed = 100 })
        $d = Get-TestDecision
        Assert-Test ($d.action -eq 'hold')
    }
    'duplicate workspace-only keys are rejected' = {
        $s.key = $p.key
        $rejected = $false
        try { $null = Get-TestDecision } catch { $rejected = $true }
        Assert-Test $rejected
    }
    'unknown current Business does not rotate to fresh other Business' = {
        $s.quotaFresh = $false
        $d = Get-TestDecision secondary
        Assert-Test ($d.action -eq 'hold' -and $d.reason -eq 'current_business_unknown')
    }
    'selection does not mutate input profiles' = {
        $before = ConvertTo-Json @($p, $s, $f, $e) -Depth 8 -Compress
        $null = Get-TestDecision
        $after = ConvertTo-Json @($p, $s, $f, $e) -Depth 8 -Compress
        Assert-Test ($before -ceq $after)
    }
    'unmapped current key is held' = {
        $d = Get-AccountPriorityDecision -Profiles @($p, $s, $f, $e) -CurrentKey 'fixture-unmapped' -Now $testNow
        Assert-Test ($d.action -eq 'hold' -and $d.reason -eq 'current_account_not_mapped')
    }
    'exactly 120 seconds remains fresh' = {
        $p.checkedAtUtc = $testNow.AddSeconds(-120).ToString('o')
        $d = Get-TestDecision
        Assert-Test ($d.reason -eq 'current_business_usable')
    }
    'future observation timestamp is unknown' = {
        $p.checkedAtUtc = $testNow.AddSeconds(1).ToString('o')
        $d = Get-TestDecision
        Assert-Test ($d.reason -eq 'current_business_unknown')
    }
    'manual Plus still yields Business candidate; runner owns active-work guard' = {
        $d = Get-TestDecision fallback
        Assert-Test ($d.action -eq 'switch' -and $d.targetKey -ceq $p.key -and $d.reason -eq 'business_available')
    }
    'unknown Pro does not select emergency' = {
        Set-TestBusinessBlocked; Set-TestFallbackBlocked
        $e.quotaFresh = $false
        $d = Get-TestDecision
        Assert-Test ($d.action -eq 'hold' -and $d.reason -eq 'no_confirmed_available_account')
    }
    'post-reset new timestamp without fresh flag stays unknown' = {
        Set-TestBusinessBlocked; Set-TestFallbackBlocked
        $p.windows[0].windowUsed = 0
        $p.checkedAtUtc = $testNow.ToString('o')
        $p.quotaFresh = $false
        $d = Get-TestDecision fallback
        Assert-Test ($d.action -eq 'hold' -and $d.reason -eq 'business_not_confirmed_blocked')
    }
    'post-reset fresh observation with remaining quota restores Business candidate' = {
        Set-TestBusinessBlocked; Set-TestFallbackBlocked
        $p.windows[0].windowUsed = 0
        $p.checkedAtUtc = $testNow.ToString('o')
        $p.quotaFresh = $true
        $d = Get-TestDecision fallback
        Assert-Test ($d.targetKey -ceq $p.key -and $d.reason -eq 'business_available')
    }
    'positive credits without explicit trial eligibility remain unknown' = {
        Set-TestBusinessBlocked; Set-TestCreditTrial
        $f.Remove('creditEligible')
        $d = Get-TestDecision
        Assert-Test ($d.action -eq 'hold' -and $d.reason -eq 'fallback_not_confirmed_blocked')
    }
}

foreach ($case in $cases.GetEnumerator()) {
    $p = New-TestProfile primary; $s = New-TestProfile secondary
    $f = New-TestProfile fallback; $e = New-TestProfile emergency
    $script:testProfiles = @{ primary = $p; secondary = $s; fallback = $f; emergency = $e }
    try { & $case.Value; $passedCases++ }
    catch { throw ('Policy regression failed: ' + $case.Key + '. ' + $_.Exception.Message) }
}
[pscustomobject]@{ passed = $true; syntheticCases = $passedCases; liveAccountAccess = $false; processOrSwitchExecution = $false }
