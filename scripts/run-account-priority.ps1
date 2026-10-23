# EXPERIMENTAL / NOT ACTIVATED: live rotation/resume still require verification.
# Wait for the current account's exhaustion before starting priority rotation.
# Safe-boundary supervisor for the pinned, unmodified native manager.
# No credential writes or quota requests. Continuations use native ResumeAsync.
# Config and the two adjacent state/status files MUST be in private local storage.
# Config fields: enabled(bool), toolDirectory, dataDirectory, codexHome, threadId,
# executableSha256, roles {primary,secondary,fallback,emergency: opaque native Key},
# optional bucketId/bucketIds (explicit common + model quota buckets),
# pollIntervalSeconds (5..60, default 30). Default codex requires one native bucket.
# -CheckOnly reads native snapshots/IPC but writes nothing and never sends a switch.
# -Once performs one cycle; a dispatched transition is reconciled by a later run.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath, [switch]$CheckOnly, [switch]$Once)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'native-account-bridge.ps1')
. (Join-Path $PSScriptRoot 'account-priority-policy.ps1')

function Read-PriorityJson([string]$Path) {
    if ((Get-Item -LiteralPath $Path).Length -gt 1048576) { throw 'Priority input rejected.' }
    return ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Path)) -AsHashtable -Depth 40 -DateKind String
}
function Save-PriorityJson([string]$Path, $Value) {
    # Only this supervisor's private ledger/status; never native auth/config/vault.
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        $text = ConvertTo-Json -InputObject $Value -Depth 30 -Compress
        $stream = [IO.FileStream]::new($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text); $stream.Write($bytes); $stream.Flush($true) }
        finally { $stream.Dispose() }
        [IO.File]::Move($temporary,$Path,$true)
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Get-PriorityRole([string]$Key) {
    foreach ($role in @('primary','secondary','fallback','emergency')) {
        if ($config.roles[$role] -ceq $Key) { return $role }
    }
    return 'unmapped'
}
function Get-PriorityConfigSignature($Value) {
    $copy = @{}; foreach ($key in $Value.Keys) { if ($key -cne 'enabled') { $copy[$key] = $Value[$key] } }
    $stable = ConvertTo-Json -InputObject (ConvertTo-NativeStableJsonValue $copy) -Depth 30 -Compress
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($stable)))
}
function New-PriorityLedger([string]$ThreadId, [string]$Signature) {
    return @{version=2; threadId=$ThreadId; configSignature=$Signature; armed=$false
        transition=$null; lastSwitchAt=$null; lastCompleted=$null; observation=$null; failures=@{}}
}
function Test-PriorityInitialExhaustion($Profiles, [string]$CurrentKey, [DateTimeOffset]$Now) {
    $current = @($Profiles | Where-Object { $_.key -ceq $CurrentKey })
    if ($current.Count -ne 1 -or -not $current[0].quotaFresh) { return $false }
    $checked = ConvertTo-AccountPolicyTime $current[0].checkedAtUtc
    if ($null -eq $checked -or ($Now-$checked).TotalSeconds -lt 0 -or ($Now-$checked).TotalSeconds -gt 120) { return $false }
    if ($current[0].usageAllowed -is [bool] -and -not $current[0].usageAllowed) { return $true }
    foreach ($window in $current[0].windows) {
        $used = ConvertTo-AccountPolicyNumber $window.windowUsed
        if ($null -ne $used -and $used -ge 100) { return $true }
    }
    return $false
}
function Update-PriorityTurnEvidence($Snapshot, [DateTimeOffset]$Now) {
    # An idle historical failure does not identify which account executed it.
    # Persist an observed in-progress turn/account pair before accepting its error.
    $state = Get-NativeThreadState $context
    $latest=[pscustomobject]@{TurnId=$state.LastTurnId;LastTurnStatus=$state.LastTurnStatus;UsageLimitErrorConfirmed=$false}
    $missingMetadata=[string]::IsNullOrWhiteSpace($state.LastTurnId) -or [string]::IsNullOrWhiteSpace($state.LastTurnStatus)
    # Confirm each newly observed active turn through the bounded native page.
    # Matching monitor IDs may then use the existing confirmation. Work peers can
    # omit turn metadata; those peers require the same bounded page as fallback.
    if ($state.CurrentStatus -ceq 'active') {
        if ($null -ne $ledger.observation -and -not [string]::IsNullOrWhiteSpace($state.LastTurnId) -and
            $state.LastTurnId -ceq $ledger.observation.turnId -and
            ([string]::IsNullOrWhiteSpace($state.LastTurnStatus) -or $state.LastTurnStatus -ceq 'inProgress')) { $latest.LastTurnStatus='inProgress' }
        else { $latest=Get-NativeLatestTurnDisposition $context }
    } elseif ($state.CurrentStatus -ceq 'idle' -and $missingMetadata) {
        $latest=Get-NativeLatestTurnDisposition $context
    } elseif ($state.CurrentStatus -ceq 'idle' -and $state.LastTurnStatus -cin @('failed','interrupted')) {
        $known=$ledger.failures[$Snapshot.CurrentKey]
        if ($null -ne $known -and $known.turnId -ceq $state.LastTurnId) { $latest.UsageLimitErrorConfirmed=$true }
        else { $latest=Get-NativeLatestTurnDisposition $context }
    }
    $identityMismatch=-not [string]::IsNullOrWhiteSpace($state.LastTurnId) -and
        -not [string]::IsNullOrWhiteSpace($latest.TurnId) -and $state.LastTurnId -cne $latest.TurnId
    if ($identityMismatch) {
        return [pscustomobject]@{BoundFailure=$false;State=$state;Latest=$latest;IdentityMismatch=$true}
    }
    $changed = $false
    if ($state.Available -and $state.CurrentFound -and $state.CurrentStatus -ceq 'active' -and
        $latest.LastTurnStatus -ceq 'inProgress' -and -not [string]::IsNullOrWhiteSpace($latest.TurnId)) {
        if ($null -ne $ledger.observation -and $ledger.observation.turnId -ceq $latest.TurnId) {
            # Canonical changes cannot reassign an already running turn. Preserve
            # its first account and invalidate attribution for the entire turn.
            if ($ledger.observation.accountKey -cne $Snapshot.CurrentKey) { $ledger.observation.ambiguous=$true }
            $ledger.observation.at=$Now.ToString('o')
        } else {
            $ledger.observation = @{accountKey=$Snapshot.CurrentKey; turnId=$latest.TurnId; at=$Now.ToString('o');ambiguous=$false}
        }
        $changed = $true
    }
    $observedAt=if($null -ne $ledger.observation){ConvertTo-AccountPolicyTime $ledger.observation.at}else{$null}
    $currentFailure=$ledger.failures[$Snapshot.CurrentKey]
    $alreadyBound=$null -ne $currentFailure -and $currentFailure.turnId -ceq $latest.TurnId
    $newlyBound = $null -ne $ledger.observation -and -not $ledger.observation.ambiguous -and $null -ne $observedAt -and
        ($Now-$observedAt).TotalSeconds -ge 0 -and ($Now-$observedAt).TotalSeconds -le 120 -and
        $ledger.observation.accountKey -ceq $Snapshot.CurrentKey -and $ledger.observation.turnId -ceq $latest.TurnId
    $bound=$latest.UsageLimitErrorConfirmed -and ($alreadyBound -or $newlyBound)
    if ($bound -and -not $alreadyBound) {
        $state=Get-NativeThreadState $context -IncludeSettings
        $ledger.failures[$Snapshot.CurrentKey] = @{accountKey=$Snapshot.CurrentKey; turnId=$latest.TurnId; at=$Now.ToString('o')
            settingsHash=if($state.SettingsVerified){$state.SettingsHash}else{$null};ordinaryBlockedSeen=$false;quotaWindows=@()}
        $changed = $true
    }
    if ($changed -and -not $CheckOnly) { Save-PriorityJson $statePath $ledger }
    return [pscustomobject]@{ BoundFailure=[bool]$bound; State=$state; Latest=$latest; IdentityMismatch=$false }
}
function Set-PriorityFailureProjection($Profiles, [DateTimeOffset]$Now) {
    $changed=$false
    foreach ($profile in $Profiles) {
        $failure=$ledger.failures[$profile.key]
        if ($null -eq $failure) { continue }
        $at=ConvertTo-AccountPolicyTime $failure.at
        if ($null -eq $at -or $at -gt $Now) { throw 'Priority failure evidence rejected.' }
        # A failure does not expire into permission to reuse the same account.
        # Only a later fresh observation with measured recovery clears it.
        $checked=ConvertTo-AccountPolicyTime $profile.checkedAtUtc
        $nativeEligibility=Get-AccountPolicyEligibility $profile $Now 120
        $improved=$false
        foreach($window in $profile.windows) {
            foreach($before in $failure.quotaWindows) {
                if ($window.bucketId -ceq $before.bucketId -and $window.windowSlot -ceq $before.windowSlot -and
                    $window.windowMins -eq $before.windowMins -and $window.windowUsed -lt $before.windowUsed) { $improved=$true }
            }
        }
        if ($null -ne $checked -and $checked -gt $at -and $nativeEligibility.state -ceq 'usable' -and
            $nativeEligibility.reason -ceq 'ordinary_available' -and ($failure.ordinaryBlockedSeen -or $improved)) {
            $ledger.failures.Remove($profile.key); $changed=$true; continue
        }
        if ($profile.quotaFresh) {
            if (($profile.usageAllowed -is [bool] -and -not $profile.usageAllowed) -or
                @($profile.windows | Where-Object {$_.windowUsed -ge 100}).Count -gt 0) { $failure.ordinaryBlockedSeen=$true }
            # Retain the highest measured window value so a later reset can prove
            # recovery even when the first failed request preceded the quota poll.
            foreach($window in $profile.windows) {
                $same=@($failure.quotaWindows | Where-Object {$_.bucketId -ceq $window.bucketId -and $_.windowSlot -ceq $window.windowSlot -and $_.windowMins -eq $window.windowMins})
                if ($same.Count -eq 0) { $failure.quotaWindows+=@{bucketId=$window.bucketId;windowSlot=$window.windowSlot;windowMins=$window.windowMins;windowUsed=$window.windowUsed} }
                elseif($window.windowUsed -gt $same[0].windowUsed){$same[0].windowUsed=$window.windowUsed}
            }
            $changed=$true
        }
        $profile.usageAllowed=$false; $profile.quotaFresh=$true; $profile.checkedAtUtc=$Now.ToString('o')
        if ($profile.role -ceq 'fallback') { $profile.creditBlockedConfirmed=$true }
    }
    if ($changed -and -not $CheckOnly) { Save-PriorityJson $statePath $ledger }
}
function Write-PriorityStatus([string]$Reason, [string]$CurrentRole = 'unknown', [string]$TargetRole = 'none') {
    $value = [ordered]@{ at=[DateTimeOffset]::UtcNow.ToString('o'); reason=$Reason
        currentRole=$CurrentRole; targetRole=$TargetRole; failedThreadResumeAvailable=$true
        failureAccountAttributionAvailable=$true; checkOnly=[bool]$CheckOnly }
    if (-not $CheckOnly) { Save-PriorityJson $statusPath $value }
    if ($script:lastStatus -cne "$Reason/$CurrentRole/$TargetRole") {
        $script:lastStatus = "$Reason/$CurrentRole/$TargetRole"
        $value | ConvertTo-Json -Compress
    }
}
function Test-PriorityManager {
    # Same namespace as upstream Program.cs. Avoid starting a manager on a wrong
    # logical/physical data-directory alias, or when the independent manager left.
    $nativeMutex = $null
    try { $nativeMutex = [Threading.Mutex]::OpenExisting($nativeMutexName) }
    catch { return $false }
    finally { if ($null -ne $nativeMutex) { $nativeMutex.Dispose() } }
    $matches = 0
    foreach ($process in [Diagnostics.Process]::GetProcessesByName('CodexSwitch')) {
        try { if ([IO.Path]::GetFullPath($process.MainModule.FileName) -ieq $executable) { $matches++ } }
        catch { return $false }
        finally { $process.Dispose() }
    }
    return $matches -eq 1
}
function Get-PriorityBoundary {
    $thread = Get-NativeThreadState $context
    $monitor = Get-NativeBridgeMonitor $context
    $unsafeRoots = @($monitor.Threads | Where-Object { $_.Status -cne 'idle' -or $_.Waiting })
    $safe = $thread.Available -and $thread.CurrentFound -and $thread.CurrentStatus -ceq 'idle' -and
        -not $thread.Waiting -and $thread.OtherActiveCount -eq 0 -and $thread.Queued -eq 0 -and
        -not $thread.QueueProblemPresent -and $unsafeRoots.Count -eq 0
    return [pscustomobject]@{ Safe=[bool]$safe; Thread=$thread }
}
function ConvertTo-PriorityProfiles($Snapshot, [DateTimeOffset]$Now) {
    foreach ($role in @('primary','secondary','fallback','emergency')) {
        $matches = @($Snapshot.Accounts | Where-Object { $_.Key -ceq $config.roles[$role] })
        if ($matches.Count -ne 1) { throw 'Priority mapping rejected.' }
        $account = $matches[0]
        $selectedIds=@(if($config.ContainsKey('bucketIds')){$config.bucketIds}else{$bucketId})
        $explicitBuckets=$config.ContainsKey('bucketId') -or $config.ContainsKey('bucketIds')
        $buckets=@($account.Buckets | Where-Object { $_.Id -cin $selectedIds })
        $complete=$explicitBuckets -or @($account.Buckets).Count -eq 1
        foreach($selectedId in $selectedIds) {
            $one=@($account.Buckets | Where-Object {$_.Id -ceq $selectedId})
            if ($one.Count -ne 1 -or ($null -eq $one[0].Primary -and $null -eq $one[0].Secondary)) { $complete=$false }
        }
        # Credits belong to the common bucket when present. Additional selected
        # model limits contribute windows; they do not invent shared credit data.
        $common=@($buckets | Where-Object {$_.Id -ceq 'codex'})
        $bucket=if($common.Count -eq 1){$common[0]}elseif($buckets.Count -eq 1){$buckets[0]}else{$null}
        $age = if ($null -ne $account.UsageCheckedAt) { ($Now - $account.UsageCheckedAt).TotalSeconds } else { -1 }
        $fresh = -not $account.RequiresApply -and $complete -and $null -ne $bucket -and $age -ge 0 -and $age -le 120
        $balance = if ($null -ne $bucket) { ConvertTo-AccountPolicyNumber $bucket.CreditBalance } else { $null }
        $unlimited = if ($null -ne $bucket) { $bucket.UnlimitedCredits } else { $null }
        $spend = if ($null -ne $bucket) { $bucket.SpendControlReached } else { $null }
        $creditEligible = $null
        if ($spend -is [bool] -and $spend) { $creditEligible = $false }
        elseif ($spend -is [bool] -and -not $spend -and
            (($unlimited -is [bool] -and $unlimited) -or ($null -ne $balance -and $balance -gt 0))) { $creditEligible = $true }
        elseif ($unlimited -is [bool] -and -not $unlimited -and $null -ne $balance -and $balance -le 0) { $creditEligible = $false }
        $windows = @()
        foreach ($selectedBucket in $buckets) {
            foreach ($slot in @('Primary','Secondary')) {
                $window=$selectedBucket.$slot
                if ($null -ne $window) { $windows += @{bucketId=$selectedBucket.Id;windowSlot=$slot;windowMins=$window.Minutes; windowUsed=$window.UsedPercent} }
            }
        }
        @{key=$account.Key; role=$role; quotaFresh=[bool]$fresh; checkedAtUtc=$account.UsageCheckedAt
            usageAllowed=$account.OrdinaryUsageAllowed; windows=$windows; creditEligible=$creditEligible
            creditBalance=$balance; creditUnlimited=$unlimited; creditSpendControlReached=$spend
            # Never attach a historical turn failure to the present canonical key.
            # Native raw credits.hasCredits is not retained; leave unknown.
            creditHasCredits=$null; creditBlockedConfirmed=$false}
    }
}
function Read-PriorityReceipt {
    $path = Join-Path $context.DataDirectory 'last-switch.json'
    if (-not [IO.File]::Exists($path)) { return $null }
    return Read-PriorityJson $path
}
function Complete-PriorityTransition($Claim, [DateTimeOffset]$ReceiptAt, [string]$Reason) {
    if (-not $CheckOnly) {
        $ledger.lastCompleted=$Claim; $ledger.lastSwitchAt=$ReceiptAt.ToString('o'); $ledger.transition=$null
        Save-PriorityJson $statePath $ledger
    }
    Write-PriorityStatus $Reason (Get-PriorityRole $Claim.targetKey)
}
function Resolve-PriorityTransition($Snapshot) {
    $claim=$ledger.transition; $receipt=Read-PriorityReceipt
    $receiptAt=if($null -ne $receipt){ConvertTo-AccountPolicyTime $receipt.at}else{$null}
    $claimAt=ConvertTo-AccountPolicyTime $claim.createdAt
    $matched=$null -ne $receipt -and $null -ne $receiptAt -and $null -ne $claimAt -and
        $receiptAt -ge $claimAt -and $receipt.Id -cne $claim.priorReceiptId -and
        $receipt.TargetAccountKey -ceq $claim.targetKey -and $receipt.phase -ceq 'Finished' -and
        $receipt.AccountApplied -eq $true -and $receipt.chats -eq 0 -and
        $receipt.failed -eq 0 -and $receipt.unconfirmed -eq 0 -and [string]::IsNullOrEmpty($receipt.error) -and
        $null -eq $Snapshot.PendingSwitch -and $Snapshot.CurrentKey -ceq $claim.targetKey
    if (-not $matched) {
        Write-PriorityStatus 'transition_unresolved_no_retry' (Get-PriorityRole $Snapshot.CurrentKey) (Get-PriorityRole $claim.targetKey); return
    }
    if ($null -eq $claim.resume) { Complete-PriorityTransition $claim $receiptAt 'native_boundary_switch_verified'; return }
    $boundary=Get-PriorityBoundary
    if (-not $boundary.Safe) { Write-PriorityStatus 'waiting_for_resume_boundary' (Get-PriorityRole $Snapshot.CurrentKey); return }
    $latest=Get-NativeLatestTurnDisposition $context
    if ($claim.resume.phase -cne 'pending') {
        if (-not [string]::IsNullOrWhiteSpace($latest.TurnId) -and $latest.TurnId -cne $claim.resume.turnId -and
            $latest.LastTurnStatus -ceq 'completed') {
            Complete-PriorityTransition $claim $receiptAt 'native_switch_verified_later_turn_completed'
        } else { Write-PriorityStatus 'resume_unresolved_no_retry' (Get-PriorityRole $Snapshot.CurrentKey) }
        return
    }
    if (-not $latest.UsageLimitErrorConfirmed -or $latest.TurnId -cne $claim.resume.turnId) {
        Complete-PriorityTransition $claim $receiptAt 'native_switch_verified_original_turn_changed'; return
    }
    $settings=Get-NativeThreadState $context -IncludeSettings
    if (-not $settings.SettingsVerified -or $settings.SettingsHash -cne $claim.resume.settingsHash) {
        Write-PriorityStatus 'resume_settings_changed_no_send' (Get-PriorityRole $Snapshot.CurrentKey); return
    }
    if ($CheckOnly) { Write-PriorityStatus 'native_resume_candidate_not_sent' (Get-PriorityRole $Snapshot.CurrentKey); return }
    # Durable claim precedes native ResumeAsync. Never repeat after any uncertainty.
    $claim.resume.phase='claimed_before_dispatch'; Save-PriorityJson $statePath $ledger
    $result=Invoke-NativeThreadResume -Context $context -TargetAccountKey $claim.targetKey -OriginalTurnId $claim.resume.turnId -ContinueMessageId $claim.resume.messageId -ExpectedSettingsHash $claim.resume.settingsHash -ClaimRecorded $true
    $claim.resume.result=$result.ResumeState
    if ($result.ResumeState -ceq 'Resumed' -and $result.SettingsPreserved -and $result.SameThread) {
        $claim.resume.phase='confirmed'
        # Bind the native continuation if the monitor already observed its new ID.
        if (-not [string]::IsNullOrWhiteSpace($result.LastTurnId) -and $result.LastTurnId -cne $claim.resume.turnId) {
            $ledger.observation=@{accountKey=$claim.targetKey;turnId=$result.LastTurnId;at=[DateTimeOffset]::UtcNow.ToString('o');ambiguous=$false}
        }
        Complete-PriorityTransition $claim $receiptAt 'native_switch_and_resume_verified'
    } elseif ($result.ResumeState -cin @('Completed','AlreadyRunning') -and $result.SettingsPreserved -and $result.SameThread) {
        $claim.resume.phase='settled_without_send'
        Complete-PriorityTransition $claim $receiptAt 'native_switch_verified_turn_already_settled'
    } else {
        $claim.resume.phase='unconfirmed'; Save-PriorityJson $statePath $ledger
        Write-PriorityStatus 'resume_unresolved_no_retry' (Get-PriorityRole $Snapshot.CurrentKey)
    }
}
function Invoke-PriorityCycle {
    $liveConfig = Read-PriorityJson $configPathFull
    if ((Get-PriorityConfigSignature $liveConfig) -cne $configSignature) { throw 'Priority configuration changed; restart required.' }
    if ($liveConfig.enabled -isnot [bool] -or -not $liveConfig.enabled) { Write-PriorityStatus 'disabled'; return }
    if (-not (Test-PriorityManager)) { Write-PriorityStatus 'native_manager_missing'; return }
    $snapshot = Get-NativePrioritySnapshot $context
    $currentRole = Get-PriorityRole $snapshot.CurrentKey
    $now = [DateTimeOffset]::UtcNow
    if ($null -ne $ledger.transition) {
        Resolve-PriorityTransition $snapshot
        return
    }
    if ($null -ne $snapshot.PendingSwitch) { Write-PriorityStatus 'native_transition_pending' $currentRole; return }
    $profiles = @(ConvertTo-PriorityProfiles $snapshot $now)
    $evidence=Update-PriorityTurnEvidence $snapshot $now
    if ($evidence.IdentityMismatch -or (($evidence.State.CurrentStatus -ceq 'active') -ne ($evidence.Latest.LastTurnStatus -ceq 'inProgress'))) {
        Write-PriorityStatus 'target_turn_not_observable' $currentRole; return
    }
    Set-PriorityFailureProjection $profiles $now
    if (-not $ledger.armed) {
        if (-not $evidence.BoundFailure -and -not (Test-PriorityInitialExhaustion $profiles $snapshot.CurrentKey $now)) {
            Write-PriorityStatus 'waiting_for_current_account_exhaustion' $currentRole; return
        }
        $ledger.armed=$true
        if (-not $CheckOnly) { Save-PriorityJson $statePath $ledger }
    }
    $decision = Get-AccountPriorityDecision -Profiles $profiles -CurrentKey $snapshot.CurrentKey -Now $now -LastSwitchAt $ledger.lastSwitchAt
    if ($decision.action -cne 'switch') { Write-PriorityStatus $decision.reason $currentRole; return }
    $targetRole = Get-PriorityRole $decision.targetKey
    $boundary = Get-PriorityBoundary
    if (-not $boundary.Safe) { Write-PriorityStatus 'waiting_for_all_roots_idle' $currentRole $targetRole; return }
    if ($CheckOnly) { Write-PriorityStatus 'boundary_switch_candidate_not_sent' $currentRole $targetRole; return }
    # No turn cancellation. Recheck the boundary immediately
    # before the claim; native Capture still has an unavoidable external-input race.
    $again = Get-NativePrioritySnapshot $context
    $boundaryAgain = Get-PriorityBoundary
    $enabledNow = Read-PriorityJson $configPathFull
    if (-not $boundaryAgain.Safe -or $again.CurrentKey -cne $snapshot.CurrentKey -or $null -ne $again.PendingSwitch -or
        $enabledNow.enabled -isnot [bool] -or -not $enabledNow.enabled -or
        (Get-PriorityConfigSignature $enabledNow) -cne $configSignature -or -not (Test-PriorityManager)) {
        Write-PriorityStatus 'preflight_changed' $currentRole $targetRole; return
    }
    $freshNow=[DateTimeOffset]::UtcNow
    $freshProfiles=@(ConvertTo-PriorityProfiles $again $freshNow)
    Set-PriorityFailureProjection $freshProfiles $freshNow
    $freshDecision = Get-AccountPriorityDecision -Profiles $freshProfiles -CurrentKey $again.CurrentKey -Now $freshNow -LastSwitchAt $ledger.lastSwitchAt
    if ($freshDecision.action -cne 'switch' -or $freshDecision.targetKey -cne $decision.targetKey) { Write-PriorityStatus 'quota_decision_changed' $currentRole; return }
    if ((Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -ine $config.executableSha256) { throw 'Priority executable rejected.' }
    $prior = Read-PriorityReceipt
    $resume=$null
    $latest=Get-NativeLatestTurnDisposition $context
    $settings=Get-NativeThreadState $context -IncludeSettings
    $currentFailure=$ledger.failures[$snapshot.CurrentKey]
    if ($evidence.BoundFailure -and $latest.UsageLimitErrorConfirmed -and $null -ne $currentFailure -and
        $latest.TurnId -ceq $currentFailure.turnId -and
        $settings.SettingsVerified -and $settings.SettingsHash -ceq $currentFailure.settingsHash) {
        $resume=@{phase='pending';turnId=$latest.TurnId;settingsHash=$settings.SettingsHash;messageId=[guid]::NewGuid().ToString('D')}
    }
    $lastBoundary=Get-PriorityBoundary
    $lastSnapshot=Get-NativePrioritySnapshot $context
    if (-not $lastBoundary.Safe -or $lastSnapshot.CurrentKey -cne $snapshot.CurrentKey -or
        $null -ne $lastSnapshot.PendingSwitch -or -not (Test-PriorityManager)) {
        Write-PriorityStatus 'preflight_changed' $currentRole $targetRole; return
    }
    $ledger.transition = @{id=[guid]::NewGuid().ToString('N'); createdAt=[DateTimeOffset]::UtcNow.ToString('o')
        sourceKey=$snapshot.CurrentKey; targetKey=$decision.targetKey; priorReceiptId=if($null -ne $prior){$prior.Id}else{$null}
        phase='claimed_before_dispatch'; resume=$resume}
    Save-PriorityJson $statePath $ledger
    # From this point, crash/timeout/error means unresolved. Never repeat the CLI.
    $start = [Diagnostics.ProcessStartInfo]::new($executable)
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    foreach ($arg in @('--data-dir',$context.DataDirectory,'--codex-home',$context.CodexHome,'--switch-account',$decision.targetKey)) { $start.ArgumentList.Add([string]$arg) }
    $process = [Diagnostics.Process]::Start($start)
    if ($null -eq $process) { throw 'Priority dispatch uncertain.' }
    try { $null=$process.WaitForExit(10000) } finally { $process.Dispose() }
    Write-PriorityStatus 'native_request_sent_completion_unverified' $currentRole $targetRole
}

$context=$null; $mutex=$null; $ownsMutex=$false; $script:lastStatus=$null
try {
    $configPathFull=[IO.Path]::GetFullPath($ConfigPath)
    $config=Read-PriorityJson $configPathFull
    foreach ($field in @('toolDirectory','dataDirectory','codexHome','threadId','executableSha256')) {
        if ($config[$field] -isnot [string] -or [string]::IsNullOrWhiteSpace($config[$field])) { throw 'Priority configuration rejected.' }
    }
    if ($config.roles -isnot [Collections.IDictionary] -or $config.roles.Count -ne 4 -or
        $config.executableSha256 -cnotmatch '^[a-fA-F0-9]{64}$' -or $config.enabled -isnot [bool]) { throw 'Priority configuration rejected.' }
    $roleKeys=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($role in @('primary','secondary','fallback','emergency')) {
        if ($config.roles[$role] -isnot [string] -or $config.roles[$role] -cnotmatch '^[a-fA-F0-9]{64}$' -or -not $roleKeys.Add($config.roles[$role])) { throw 'Priority roles rejected.' }
    }
    $poll=if($config.ContainsKey('pollIntervalSeconds')){ConvertTo-AccountPolicyNumber $config.pollIntervalSeconds}else{30}
    if ($null -eq $poll -or $poll -lt 5 -or $poll -gt 60) { throw 'Priority timing rejected.' }
    $bucketId=if($config.ContainsKey('bucketId')){$config.bucketId}else{'codex'}
    if ($bucketId -isnot [string] -or [string]::IsNullOrWhiteSpace($bucketId)) { throw 'Priority bucket rejected.' }
    if ($config.ContainsKey('bucketIds')) {
        $bucketKeys=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        if ($config.ContainsKey('bucketId') -or $config.bucketIds -isnot [Collections.IList] -or $config.bucketIds.Count -eq 0) { throw 'Priority buckets rejected.' }
        foreach ($selectedId in $config.bucketIds) {
            if ($selectedId -isnot [string] -or [string]::IsNullOrWhiteSpace($selectedId) -or -not $bucketKeys.Add($selectedId)) { throw 'Priority buckets rejected.' }
        }
    }
    $configSignature=Get-PriorityConfigSignature $config
    $statePath=Join-Path ([IO.Path]::GetDirectoryName($configPathFull)) 'account-priority-state.json'
    $statusPath=Join-Path ([IO.Path]::GetDirectoryName($configPathFull)) 'account-priority-status.json'
    if ($configPathFull -ieq $statePath -or $configPathFull -ieq $statusPath) { throw 'Priority path rejected.' }
    $context=New-NativeAccountBridgeContext -ToolDirectory $config.toolDirectory -DataDirectory $config.dataDirectory -CodexHome $config.codexHome -CurrentThreadId $config.threadId
    $executable=Join-Path $context.ToolDirectory 'CodexSwitch.exe'
    if ((Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -ine $config.executableSha256) { throw 'Priority executable rejected.' }
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $nativeNamespace=Invoke-NativeBridgeMethod $context.Types.SecureFiles 'Hash' $null @([string]($sid+"`n"+$context.DataDirectory))
    $nativeMutexName='Local\CodexAccountDesk-'+$nativeNamespace.Substring(0,24)
    $runnerNamespace=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($sid+"`n"+$context.CodexHome.ToLowerInvariant())))
    $mutex=[Threading.Mutex]::new($false,('Local\AgentFlowAccountPriority-'+$runnerNamespace.Substring(0,24)))
    try { $ownsMutex=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMutex=$true }
    if (-not $ownsMutex) { throw 'Priority supervisor already running.' }
    $ledger=if([IO.File]::Exists($statePath)){Read-PriorityJson $statePath}else{New-PriorityLedger $config.threadId $configSignature}
    if ($ledger.version -ne 2 -or $ledger.threadId -cne $config.threadId -or $ledger.configSignature -cne $configSignature -or
        $ledger.armed -isnot [bool] -or -not $ledger.ContainsKey('transition') -or -not $ledger.ContainsKey('lastSwitchAt') -or
        -not $ledger.ContainsKey('observation') -or $ledger.failures -isnot [Collections.IDictionary]) { throw 'Priority ledger rejected.' }
    do {
        try { Invoke-PriorityCycle }
        catch {
            if ($_.Exception.Message -ceq 'Native latest-turn inspection unavailable.') {
                Write-PriorityStatus 'latest_turn_inspection_unavailable_stopped'; throw
            }
            Write-PriorityStatus 'inspection_or_dispatch_uncertain_no_retry'
        }
        if ($CheckOnly -or $Once) { break }
        Start-Sleep -Seconds $poll
    } while ($true)
} catch {
    # Native exceptions can contain identity/path details. Never print them.
    [Console]::Error.WriteLine('Account priority supervisor stopped: setup or state rejected.')
    exit 1
} finally {
    if ($null -ne $context) { try { $null=Dispose-NativeAccountBridgeContext $context } catch {} }
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    if ($null -ne $mutex) { $mutex.Dispose() }
}
