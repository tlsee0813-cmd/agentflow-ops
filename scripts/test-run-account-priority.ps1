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
# Exercise the real bounded bridge read against fake RPC responses. No native
# assemblies, CLI, credentials or sockets are opened by these replacements.
$bridgeAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'native-account-bridge.ps1'),[ref]$null,[ref]$null)
$bridgeRead=@($bridgeAst.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -ceq 'Get-NativeLatestTurnDisposition'})[0]
. ([scriptblock]::Create($bridgeRead.Extent.Text))
function New-NativeBridgeObject($Type,[object[]]$Arguments=@()) { return [pscustomobject]@{Synthetic=$true} }
function Invoke-NativeBridgeMethod($Type,[string]$Name,$Target,[object[]]$Arguments=@()) {
    switch($Name) {
        'FindAsync' { return [pscustomobject]@{CliPath='never-launched'} }
        'InitializeAsync' { return }
        'RequestAsync' {
            $script:requestCalls++
            Assert-Runner ($Arguments[0] -ceq 'thread/turns/list' -and $Arguments[1]['threadId'] -ceq 'fixture-thread' -and
                $Arguments[1]['limit'] -eq 1 -and $Arguments[1]['sortDirection'] -ceq 'desc' -and $Arguments[1]['itemsView'] -ceq 'notLoaded')
            $document=[Text.Json.JsonDocument]::Parse($script:fakeResponse)
            try{return $document.RootElement.Clone()}finally{$document.Dispose()}
        }
        'DisposeAsync' {
            $disposal=[pscustomobject]@{}
            $disposal | Add-Member -MemberType ScriptMethod -Name AsTask -Value {return [Threading.Tasks.Task]::CompletedTask}
            return $disposal
        }
        default { throw 'Unexpected synthetic RPC method.' }
    }
}
$fakeContext=[pscustomobject]@{Disposed=$false;CurrentThreadId='fixture-thread';CodexHome='never-read';Types=@{RuntimeLocator='fake';CodexRpc='fake'}}
$bridgeCases=@(
    @{json='{"data":[{"id":"active-turn","status":"inProgress"}]}';status='inProgress';quota=$false;rejected=$false},
    @{json='{"data":[{"id":"failed-turn","status":"failed","error":{"codexErrorInfo":"usageLimitExceeded"}}]}';status='failed';quota=$true;rejected=$false},
    @{json='{"data":[{"id":"rate-turn","status":"failed","error":{"codexErrorInfo":"rateLimitExceeded"}}]}';status='failed';quota=$false;rejected=$false},
    @{json='{"data":[]}';status=$null;quota=$false;rejected=$false},
    @{json='{"data":{}}';rejected=$true},
    @{json='{"data":[{"id":"one","status":"failed"},{"id":"two","status":"failed"}]}';rejected=$true}
)
foreach($bridgeCase in $bridgeCases) {
    $script:requestCalls=0;$script:fakeResponse=$bridgeCase.json;$rejected=$false
    try{$bridgeResult=Get-NativeLatestTurnDisposition $fakeContext}
    catch{$rejected=$true;Assert-Runner ($_.Exception.Message -ceq 'Native latest-turn inspection unavailable.')}
    Assert-Runner ($rejected -eq $bridgeCase.rejected -and $script:requestCalls -eq 1)
    if(-not $rejected){Assert-Runner ($bridgeResult.LastTurnStatus -ceq $bridgeCase.status -and $bridgeResult.UsageLimitErrorConfirmed -eq $bridgeCase.quota)}
    $passed++
}
[pscustomobject]@{passed=$true;syntheticCases=$passed;liveAccountAccess=$false;processOrSwitchExecution=$false}
