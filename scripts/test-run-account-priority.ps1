# Synthetic control-flow checks. Extract function declarations only: never run
# the supervisor entry point, native DLLs, accounts, RPC, processes or network.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'native-account-bridge.ps1')
. (Join-Path $PSScriptRoot 'account-priority-policy.ps1')
$parseErrors=$null; $tokens=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'run-account-priority.ps1'),[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Supervisor parse failed.' }
foreach ($node in $ast.EndBlock.Statements) {
    if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) { . ([scriptblock]::Create($node.Extent.Text)) }
}
function Assert-Runner([bool]$Condition) { if (-not $Condition) { throw 'Synthetic supervisor assertion failed.' } }
function Save-PriorityJson([string]$Path,$Value) { $script:saves++; $script:savedPhase=if($null -ne $Value.transition -and $null -ne $Value.transition.resume){$Value.transition.resume.phase}else{$null} }
function Write-PriorityStatus([string]$Reason,[string]$CurrentRole='unknown',[string]$TargetRole='none') { $script:reason=$Reason }
function Get-NativeThreadState($Context,[switch]$IncludeSettings) {
    $script:threadState.LastTurnId=if($script:monitorMissingId){$null}elseif($null -ne $script:monitorIdOverride){$script:monitorIdOverride}else{$script:latest.TurnId}
    $script:threadState.LastTurnStatus=if($script:monitorMissingStatus){$null}else{$script:latest.LastTurnStatus}
    if($IncludeSettings){$script:settingsReads++}
    return $script:threadState
}
function Get-NativeLatestTurnDisposition($Context) { $script:fullTurnReads++; return $script:latest }
function Get-NativePrioritySnapshot($Context) { return $script:snapshot }
function Get-NativeBridgeMonitor($Context) { return [pscustomobject]@{Threads=$script:roots} }
function Read-PriorityReceipt { return $script:receipt }
function Read-PriorityJson([string]$Path) { return $script:config }
function Test-PriorityManager { return $true }
function Invoke-NativeThreadResume {
    param($Context,$TargetAccountKey,$OriginalTurnId,$ContinueMessageId,$ExpectedSettingsHash,[bool]$ClaimRecorded)
    Assert-Runner ($ClaimRecorded -and $script:savedPhase -ceq 'claimed_before_dispatch')
    $script:resumeCalls++
    if($script:resumeThrows){throw 'Synthetic uncertain native result.'}
    return [pscustomobject]@{ResumeState=$script:resumeState;SettingsPreserved=$true;SameThread=$true;LastTurnId='continued-turn'}
}
function Reset-RunnerFixture {
    $script:now=[DateTimeOffset]::UtcNow
    $script:config=@{enabled=$true;threadId='fixture-thread';roles=@{primary='p';secondary='s';fallback='f';emergency='e'}}
    $script:configSignature=Get-PriorityConfigSignature $script:config
    $script:ledger=New-PriorityLedger 'fixture-thread' $script:configSignature
    $script:CheckOnly=$false; $script:saves=0; $script:savedPhase=$null; $script:reason=$null
    $script:context=@{DataDirectory='never-read'}; $script:statePath='never-written'; $script:configPathFull='never-read'
    $script:bucketId='codex'; $script:resumeCalls=0; $script:resumeThrows=$false; $script:resumeState='Resumed';$script:fullTurnReads=0;$script:settingsReads=0
    $script:monitorMissingId=$false;$script:monitorMissingStatus=$false;$script:monitorIdOverride=$null
    $script:threadState=[pscustomobject]@{Available=$true;CurrentFound=$true;CurrentStatus='idle';Waiting=$false
        OtherActiveCount=0;Queued=0;QueueProblemPresent=$false;SettingsVerified=$true;SettingsHash=('a'*64);LastTurnId='original-turn';LastTurnStatus='completed'}
    $script:latest=[pscustomobject]@{LastTurnStatus='completed';TurnId='original-turn';UsageLimitErrorConfirmed=$false}
    $script:roots=@([pscustomobject]@{Id='fixture-thread';Status='idle';Waiting=$false})
    $accounts=@()
    foreach ($key in @('p','s','f','e')) {
        $accounts += [pscustomobject]@{Key=$key;UsageCheckedAt=$script:now;RequiresApply=$false;OrdinaryUsageAllowed=$true
            Buckets=@([pscustomobject]@{Id='codex';Primary=[pscustomobject]@{Minutes=300;UsedPercent=0};Secondary=[pscustomobject]@{Minutes=10080;UsedPercent=0}
                CreditBalance=0;UnlimitedCredits=$false;SpendControlReached=$false})}
    }
    $script:snapshot=[pscustomobject]@{CurrentKey='e';PendingSwitch=$null;Accounts=$accounts}
    $script:receipt=@{at=$script:now.ToString('o');Id='new-receipt';TargetAccountKey='p';phase='Finished';AccountApplied=$true
        chats=0;failed=0;unconfirmed=0;error=$null}
}
function Set-RunnerClaim([bool]$Resume=$true) {
    $script:ledger.transition=@{createdAt=$script:now.AddSeconds(-2).ToString('o');priorReceiptId='old-receipt';targetKey='p'
        resume=if($Resume){@{phase='pending';turnId='original-turn';settingsHash=('a'*64);messageId=[guid]::NewGuid().ToString('D')}}else{$null}}
    $script:snapshot.CurrentKey='p'
    $script:latest.UsageLimitErrorConfirmed=$true; $script:latest.LastTurnStatus='failed'
}
$cases=[ordered]@{
    'usable initial Pro does not yield to available Business'={
        $script:CheckOnly=$true; Invoke-PriorityCycle
        Assert-Runner ($script:reason -ceq 'waiting_for_current_account_exhaustion' -and -not $script:ledger.armed -and $script:saves -eq 0)
    }
    'fresh actual exhausted current Pro arms candidate'={
        $script:CheckOnly=$true; $script:snapshot.Accounts[3].Buckets[0].Primary.UsedPercent=100
        Invoke-PriorityCycle
        Assert-Runner ($script:ledger.armed -and $script:reason -ceq 'boundary_switch_candidate_not_sent' -and $script:saves -eq 0)
    }
    'stale exhausted snapshot does not arm'={
        $script:snapshot.Accounts[3].UsageCheckedAt=$script:now.AddSeconds(-121)
        $script:snapshot.Accounts[3].Buckets[0].Primary.UsedPercent=100
        Invoke-PriorityCycle; Assert-Runner (-not $script:ledger.armed)
    }
    'default codex bucket cannot silently discard a model bucket'={
        $script:snapshot.Accounts[3].Buckets+= [pscustomobject]@{Id='model-quota';Primary=$null;Secondary=$null;CreditBalance=$null;UnlimitedCredits=$null;SpendControlReached=$null}
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        Assert-Runner (-not $profiles[3].quotaFresh)
    }
    'explicit common and model buckets both constrain availability'={
        $script:config.bucketIds=@('codex','model-quota')
        $script:snapshot.Accounts[3].Buckets+= [pscustomobject]@{Id='model-quota';Primary=[pscustomobject]@{Minutes=300;UsedPercent=100};Secondary=$null;CreditBalance=$null;UnlimitedCredits=$null;SpendControlReached=$null}
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        Assert-Runner ($profiles[3].quotaFresh -and (Test-PriorityInitialExhaustion $profiles 'e' $script:now))
    }
    'empty explicitly selected model bucket is unknown'={
        $script:config.bucketIds=@('codex','model-quota')
        $script:snapshot.Accounts[3].Buckets+=[pscustomobject]@{Id='model-quota';Primary=$null;Secondary=$null;CreditBalance=$null;UnlimitedCredits=$null;SpendControlReached=$null}
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        Assert-Runner (-not $profiles[3].quotaFresh)
    }
    'duplicate bucket cannot conceal missing selected bucket'={
        $script:config.bucketIds=@('codex','model-quota')
        $script:snapshot.Accounts[3].Buckets+=$script:snapshot.Accounts[3].Buckets[0]
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        Assert-Runner (-not $profiles[3].quotaFresh)
    }
    'historical quota failure lacks account attribution'={
        $script:latest.LastTurnStatus='failed'; $script:latest.UsageLimitErrorConfirmed=$true
        $evidence=Update-PriorityTurnEvidence $script:snapshot $script:now
        Assert-Runner (-not $evidence.BoundFailure -and $script:ledger.failures.Count -eq 0)
    }
    'observed active turn binds later failure to same account'={
        $script:threadState.CurrentStatus='active';$script:latest.LastTurnStatus='inProgress'
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now
        $script:threadState.CurrentStatus='idle';$script:latest.LastTurnStatus='failed';$script:latest.UsageLimitErrorConfirmed=$true
        $evidence=Update-PriorityTurnEvidence $script:snapshot $script:now.AddSeconds(1)
        Assert-Runner ($evidence.BoundFailure -and $script:ledger.failures['e'].accountKey -ceq 'e')
    }
    'new active turn is confirmed once then matching monitor ID is cached'={
        $script:threadState.CurrentStatus='active';$script:latest.LastTurnStatus='inProgress'
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now.AddSeconds(1)
        Assert-Runner ($script:fullTurnReads -eq 1 -and $script:settingsReads -eq 0)
    }
    'Work missing monitor status confirms active turn via bounded native page'={
        $script:monitorMissingStatus=$true;$script:threadState.CurrentStatus='active';$script:latest.LastTurnStatus='inProgress'
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now.AddSeconds(1)
        Assert-Runner ($null -ne $script:ledger.observation -and $script:fullTurnReads -eq 1)
    }
    'missing both monitor fields uses bounded page for each active observation'={
        $script:monitorMissingId=$true;$script:monitorMissingStatus=$true;$script:threadState.CurrentStatus='active';$script:latest.LastTurnStatus='inProgress'
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now.AddSeconds(1)
        Assert-Runner ($null -ne $script:ledger.observation -and $script:fullTurnReads -eq 2)
    }
    'missing monitor fields classify later idle failure through same page'={
        $script:monitorMissingId=$true;$script:monitorMissingStatus=$true;$script:threadState.CurrentStatus='active';$script:latest.LastTurnStatus='inProgress'
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now
        $script:threadState.CurrentStatus='idle';$script:latest.LastTurnStatus='failed';$script:latest.UsageLimitErrorConfirmed=$true
        $evidence=Update-PriorityTurnEvidence $script:snapshot $script:now.AddSeconds(1)
        Assert-Runner ($evidence.BoundFailure -and $script:ledger.failures.ContainsKey('e'))
    }
    'active Work without visible running RPC turn does not record false evidence'={
        $script:monitorMissingStatus=$true;$script:threadState.CurrentStatus='active';$script:latest.LastTurnStatus='interrupted'
        Invoke-PriorityCycle
        Assert-Runner ($null -eq $script:ledger.observation -and $script:reason -ceq 'target_turn_not_observable' -and -not $script:ledger.armed)
    }
    'different known monitor and RPC turn IDs block observation and arming'={
        $script:monitorIdOverride='monitor-current-turn';$script:threadState.CurrentStatus='active';$script:latest.LastTurnStatus='inProgress';$script:latest.TurnId='different-rpc-turn'
        $script:snapshot.Accounts[3].Buckets[0].Primary.UsedPercent=100
        Invoke-PriorityCycle
        Assert-Runner ($null -eq $script:ledger.observation -and $script:reason -ceq 'target_turn_not_observable' -and -not $script:ledger.armed -and $script:saves -eq 0)
    }
    'idle monitor contradicting running native turn blocks quota-only switch'={
        $script:monitorMissingStatus=$true;$script:threadState.CurrentStatus='idle';$script:latest.LastTurnStatus='inProgress'
        $script:snapshot.Accounts[3].Buckets[0].Primary.UsedPercent=100
        Invoke-PriorityCycle
        Assert-Runner ($script:reason -ceq 'target_turn_not_observable' -and -not $script:ledger.armed)
    }
    'same running turn cannot be reassigned after canonical account change'={
        $script:threadState.CurrentStatus='active';$script:latest.LastTurnStatus='inProgress'
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now
        $script:snapshot.CurrentKey='f'
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now.AddSeconds(1)
        $script:threadState.CurrentStatus='idle';$script:latest.LastTurnStatus='failed';$script:latest.UsageLimitErrorConfirmed=$true
        $evidence=Update-PriorityTurnEvidence $script:snapshot $script:now.AddSeconds(2)
        Assert-Runner (-not $evidence.BoundFailure -and $script:ledger.observation.accountKey -ceq 'e' -and $script:ledger.observation.ambiguous)
    }
    'confirmed failure survives more than two minutes waiting for other root'={
        $script:threadState.CurrentStatus='active';$script:latest.LastTurnStatus='inProgress'
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now
        $script:threadState.CurrentStatus='idle';$script:latest.LastTurnStatus='failed';$script:latest.UsageLimitErrorConfirmed=$true
        $null=Update-PriorityTurnEvidence $script:snapshot $script:now.AddSeconds(1)
        $evidence=Update-PriorityTurnEvidence $script:snapshot $script:now.AddSeconds(150)
        Assert-Runner ($evidence.BoundFailure -and $script:fullTurnReads -eq 2)
    }
    'manual account change invalidates old active-turn binding'={
        $script:ledger.observation=@{accountKey='f';turnId='original-turn';at=$script:now.ToString('o');ambiguous=$false}
        $script:latest.UsageLimitErrorConfirmed=$true
        $evidence=Update-PriorityTurnEvidence $script:snapshot $script:now
        Assert-Runner (-not $evidence.BoundFailure)
    }
    'different turn invalidates active-turn binding'={
        $script:ledger.observation=@{accountKey='e';turnId='another-turn';at=$script:now.ToString('o');ambiguous=$false}
        $script:latest.UsageLimitErrorConfirmed=$true
        $evidence=Update-PriorityTurnEvidence $script:snapshot $script:now
        Assert-Runner (-not $evidence.BoundFailure)
    }
    'credit refusal projection is account bound'={
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        $script:ledger.failures['f']=@{accountKey='f';at=$script:now.ToString('o');ordinaryBlockedSeen=$false;quotaWindows=@()}
        Set-PriorityFailureProjection $profiles $script:now
        Assert-Runner ($profiles[2].creditBlockedConfirmed -and -not $profiles[3].creditBlockedConfirmed -and -not $profiles[2].usageAllowed)
    }
    'historical observation after runner downtime cannot bind failure'={
        $script:ledger.observation=@{accountKey='e';turnId='original-turn';at=$script:now.AddSeconds(-121).ToString('o');ambiguous=$false}
        $script:latest.UsageLimitErrorConfirmed=$true
        $evidence=Update-PriorityTurnEvidence $script:snapshot $script:now
        Assert-Runner (-not $evidence.BoundFailure)
    }
    'confirmed credit refusal does not expire into permission'={
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        $script:ledger.failures['f']=@{accountKey='f';at=$script:now.AddSeconds(-121).ToString('o');ordinaryBlockedSeen=$false;quotaWindows=@()}
        Set-PriorityFailureProjection $profiles $script:now
        Assert-Runner ($profiles[2].creditBlockedConfirmed)
    }
    'multiple Business failures remain blocked independently'={
        foreach($key in @('p','s')){$script:ledger.failures[$key]=@{accountKey=$key;at=$script:now.AddSeconds(-10).ToString('o');ordinaryBlockedSeen=$false;quotaWindows=@()}}
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        Set-PriorityFailureProjection $profiles $script:now
        $decision=Get-AccountPriorityDecision -Profiles $profiles -CurrentKey 's' -Now $script:now
        Assert-Runner ($script:ledger.failures.Count -eq 2 -and $decision.targetKey -ceq 'f')
    }
    'new snapshot with unchanged available quota does not erase failure'={
        $script:ledger.failures['p']=@{accountKey='p';at=$script:now.AddSeconds(-10).ToString('o');ordinaryBlockedSeen=$false;quotaWindows=@(@{bucketId='codex';windowSlot='Primary';windowMins=300;windowUsed=0})}
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        Set-PriorityFailureProjection $profiles $script:now
        Assert-Runner ($script:ledger.failures.ContainsKey('p') -and -not $profiles[0].usageAllowed)
    }
    'new measured quota recovery clears only recovered account failure'={
        foreach($key in @('p','s')){$script:ledger.failures[$key]=@{accountKey=$key;at=$script:now.AddSeconds(-10).ToString('o');ordinaryBlockedSeen=$false;quotaWindows=@(@{bucketId='codex';windowSlot='Primary';windowMins=300;windowUsed=100})}}
        $script:snapshot.Accounts[1].Buckets[0].Primary.UsedPercent=100
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        Set-PriorityFailureProjection $profiles $script:now
        Assert-Runner (-not $script:ledger.failures.ContainsKey('p') -and $script:ledger.failures.ContainsKey('s') -and $profiles[0].usageAllowed)
    }
    'different buckets with equal duration cannot fake measured recovery'={
        $script:config.bucketIds=@('codex','model-quota')
        $script:snapshot.Accounts[0].Buckets[0].Primary.UsedPercent=10
        $script:snapshot.Accounts[0].Buckets+=[pscustomobject]@{Id='model-quota';Primary=[pscustomobject]@{Minutes=300;UsedPercent=80};Secondary=$null;CreditBalance=$null;UnlimitedCredits=$null;SpendControlReached=$null}
        $script:ledger.failures['p']=@{accountKey='p';at=$script:now.AddSeconds(-10).ToString('o');ordinaryBlockedSeen=$false;quotaWindows=@()}
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now)
        Set-PriorityFailureProjection $profiles $script:now
        $profiles=@(ConvertTo-PriorityProfiles $script:snapshot $script:now.AddSeconds(1))
        Set-PriorityFailureProjection $profiles $script:now.AddSeconds(1)
        Assert-Runner ($script:ledger.failures.ContainsKey('p') -and -not $profiles[0].usageAllowed -and $script:ledger.failures['p'].quotaWindows.Count -eq 3)
    }
    'other active root blocks boundary'={
        $script:roots+= [pscustomobject]@{Id='other';Status='active';Waiting=$false}
        Assert-Runner (-not (Get-PriorityBoundary).Safe)
    }
    'other waiting root blocks boundary'={
        $script:roots+= [pscustomobject]@{Id='other';Status='idle';Waiting=$true}
        Assert-Runner (-not (Get-PriorityBoundary).Safe)
    }
    'ambiguous transition never invokes resume or clears claim'={
        Set-RunnerClaim; $script:receipt.Id='old-receipt'
        Resolve-PriorityTransition $script:snapshot
        Assert-Runner ($script:reason -ceq 'transition_unresolved_no_retry' -and $null -ne $script:ledger.transition -and $script:resumeCalls -eq 0)
    }
    'native active capture despite boundary requires manual audit'={
        Set-RunnerClaim; $script:receipt.chats=1
        Resolve-PriorityTransition $script:snapshot
        Assert-Runner ($script:reason -ceq 'transition_unresolved_no_retry' -and $script:resumeCalls -eq 0)
    }
    'verified idle switch without failed turn completes without Continue'={
        Set-RunnerClaim $false; Resolve-PriorityTransition $script:snapshot
        Assert-Runner ($null -eq $script:ledger.transition -and $script:resumeCalls -eq 0 -and $script:reason -ceq 'native_boundary_switch_verified')
    }
    'resume claim is durable before a single native continuation'={
        Set-RunnerClaim; Resolve-PriorityTransition $script:snapshot
        Assert-Runner ($script:resumeCalls -eq 1 -and $null -eq $script:ledger.transition -and $script:reason -ceq 'native_switch_and_resume_verified' -and $script:ledger.observation.accountKey -ceq 'p')
    }
    'uncertain native resume cannot be retried on next cycle'={
        Set-RunnerClaim; $script:resumeThrows=$true
        try{Resolve-PriorityTransition $script:snapshot}catch{}
        Resolve-PriorityTransition $script:snapshot
        Assert-Runner ($script:resumeCalls -eq 1 -and $script:reason -ceq 'resume_unresolved_no_retry')
    }
    'later manually completed turn settles uncertain claim without retry'={
        Set-RunnerClaim; $script:resumeThrows=$true
        try{Resolve-PriorityTransition $script:snapshot}catch{}
        $script:latest.TurnId='manually-completed-turn';$script:latest.LastTurnStatus='completed';$script:latest.UsageLimitErrorConfirmed=$false
        Resolve-PriorityTransition $script:snapshot
        Assert-Runner ($script:resumeCalls -eq 1 -and $null -eq $script:ledger.transition -and $script:reason -ceq 'native_switch_verified_later_turn_completed')
    }
    'changed settings do not send continuation'={
        Set-RunnerClaim; $script:threadState.SettingsHash=('b'*64)
        Resolve-PriorityTransition $script:snapshot
        Assert-Runner ($script:resumeCalls -eq 0 -and $script:reason -ceq 'resume_settings_changed_no_send')
    }
    'CheckOnly evaluates resume without state or turn writes'={
        Set-RunnerClaim; $script:CheckOnly=$true
        Resolve-PriorityTransition $script:snapshot
        Assert-Runner ($script:resumeCalls -eq 0 -and $script:saves -eq 0 -and $script:reason -ceq 'native_resume_candidate_not_sent')
    }
    'new user turn settles old failure without synthetic continuation'={
        Set-RunnerClaim; $script:latest.TurnId='new-user-turn'
        Resolve-PriorityTransition $script:snapshot
        Assert-Runner ($script:resumeCalls -eq 0 -and $null -eq $script:ledger.transition)
    }
    'thread binding changes signature but enabled toggle does not'={
        $initial=Get-PriorityConfigSignature $script:config
        $script:config.enabled=$false
        Assert-Runner ((Get-PriorityConfigSignature $script:config) -ceq $initial)
        $script:config.threadId='replacement-thread'
        Assert-Runner ((Get-PriorityConfigSignature $script:config) -cne $initial)
    }
}
$passed=0
foreach($case in $cases.GetEnumerator()) {
    Reset-RunnerFixture
    try { & $case.Value; $passed++ } catch { throw ('Supervisor regression failed: '+$case.Key+'. '+$_.Exception.Message) }
}
# Owner snapshot projection and framed reads use synthetic memory streams only.
$bridgeAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'native-account-bridge.ps1'),[ref]$null,[ref]$null)
Initialize-NativeSnapshotTap
function New-TestSnapshot {
    return @{threadRuntimeStatus=@{type='active'};turns=@();turnHistory=@{kind='canonical';history=@{
        islands=@(@{newerBoundary=@{status='exhausted'};entries=@(@{value='entity-current'})})
        entitiesByKey=@{'entity-current'=@{turnId='running-turn';status='inProgress';error=$null}}
    }}}
}
function Project-TestSnapshot($Value) {
    $document=[Text.Json.JsonDocument]::Parse((ConvertTo-Json -InputObject $Value -Depth 30 -Compress))
    try{return [AgentFlowOps.NativeSnapshotTap]::Project($document.RootElement)}finally{$document.Dispose()}
}
$snapshotCases=[ordered]@{
    'canonical tail active turn is observable'={ Assert-Runner ((Project-TestSnapshot $state).Observable) }
    'unknown canonical newer boundary is not latest'={ $state.turnHistory.history.islands[0].newerBoundary.status='available';Assert-Runner (-not (Project-TestSnapshot $state).Observable) }
    'missing canonical entity never falls back to legacy'={ $state.turnHistory.history.entitiesByKey.Clear();$state.turns=@(@{turnId='legacy';status='inProgress'});Assert-Runner (-not (Project-TestSnapshot $state).Observable) }
    'different legacy overlay is ambiguous'={ $state.turns=@(@{turnId='different';status='inProgress'});Assert-Runner (-not (Project-TestSnapshot $state).Observable) }
    'same overlay identity and status is supported'={ $state.turns=@(@{turnId='running-turn';status='inProgress'});Assert-Runner ((Project-TestSnapshot $state).Observable) }
    'unknown runtime cannot prove observability'={ $state.threadRuntimeStatus.type='unknown';Assert-Runner (-not (Project-TestSnapshot $state).Observable) }
    'runtime idle contradicting active turn is unknown'={ $state.threadRuntimeStatus.type='idle';Assert-Runner (-not (Project-TestSnapshot $state).Observable) }
    'exact quota error on failed canonical turn is accepted'={ $state.threadRuntimeStatus.type='idle';$state.turnHistory.history.entitiesByKey['entity-current'].status='failed';$state.turnHistory.history.entitiesByKey['entity-current'].error=@{codexErrorInfo='usageLimitExceeded'};Assert-Runner ((Project-TestSnapshot $state).UsageLimitErrorConfirmed) }
    'rate limit does not prove quota'={ $state.threadRuntimeStatus.type='idle';$state.turnHistory.history.entitiesByKey['entity-current'].status='failed';$state.turnHistory.history.entitiesByKey['entity-current'].error=@{codexErrorInfo='rateLimitExceeded'};Assert-Runner (-not (Project-TestSnapshot $state).UsageLimitErrorConfirmed) }
    'legacy snapshot without canonical history still works'={ $state.Remove('turnHistory');$state.turns=@(@{turnId='legacy';status='inProgress'});Assert-Runner ((Project-TestSnapshot $state).Observable) }
    'only latest island exhausted tail is considered'={ $state.turnHistory.history.islands=@(@{newerBoundary=@{status='available'};entries=@(@{value='old'})},$state.turnHistory.history.islands[0]);Assert-Runner ((Project-TestSnapshot $state).TurnId -ceq 'running-turn') }
}
foreach($snapshotCase in $snapshotCases.GetEnumerator()) {
    $state=New-TestSnapshot
    try{& $snapshotCase.Value}catch{throw ('Snapshot regression failed: '+$snapshotCase.Key+'. '+$_.Exception.Message)}
    $passed++
}
foreach($frameCase in @('valid','split','wrong-owner','wrong-thread','wrong-version','negative-revision','patch-only')) {
    $message=@{type='broadcast';method='thread-stream-state-changed';version=11;sourceClientId='expected-owner';params=@{hostId='local';conversationId='expected-thread';change=@{type='snapshot';revision=5;conversationState=(New-TestSnapshot)}}}
    switch($frameCase){
        'wrong-owner'{$message.sourceClientId='other-owner'}
        'wrong-thread'{$message.params.conversationId='other-thread'}
        'wrong-version'{$message.version=12}
        'negative-revision'{$message.params.change.revision=-1}
        'patch-only'{$message.params.change=@{type='patches';revision=5;patches=@()}}
    }
    $body=[Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $message -Depth 30 -Compress))
    $memory=[IO.MemoryStream]::new();$memory.Write([BitConverter]::GetBytes([int]$body.Length));$memory.Write($body);$memory.Position=0
    $tap=[AgentFlowOps.NativeSnapshotTap]::new($memory,'expected-thread');$tap.SetOwner('expected-owner')
    $buffer=[byte[]]::new($(if($frameCase -ceq 'split'){3}else{$body.Length+4}))
    $rejected=$false
    try{while($tap.Read($buffer,0,$buffer.Length) -gt 0){}}catch{$rejected=$true}
    if($frameCase -cin @('valid','split')){Assert-Runner (-not $rejected -and $tap.Result.IsCompletedSuccessfully -and $tap.Result.Result.Observable)}
    elseif($frameCase -cin @('wrong-thread','patch-only')){Assert-Runner (-not $rejected -and -not $tap.Result.IsCompleted)}
    else{Assert-Runner $rejected}
    $tap.Dispose();$passed++
}
# An unobservable owner snapshot never falls back to the stored CLI app-server.
$bridgeRead=@($bridgeAst.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -ceq 'Get-NativeLatestTurnDisposition'})[0]
. ([scriptblock]::Create($bridgeRead.Extent.Text))
function Get-NativeOwnerTurnDisposition($Context){return [pscustomobject]@{Observable=$false}}
$rejected=$false
try{$null=Get-NativeLatestTurnDisposition @{}}catch{$rejected=$_.Exception.Message -ceq 'Native latest-turn inspection unavailable.'}
Assert-Runner $rejected;$passed++
[pscustomobject]@{passed=$true;syntheticCases=$passed;liveAccountAccess=$false;processOrSwitchExecution=$false}
