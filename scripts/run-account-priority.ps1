# EXPERIMENTAL / NOT ACTIVATED: live rotation untested; failed-turn resume absent.
# User currently keeps Pro intentionally. Do not enable without resumed testing.
# Boundary-only supervisor for the pinned, unmodified native manager.
# No credential writes, quota/model requests, failed-turn classification or Resume.
# Config and the two adjacent state/status files MUST be in private local storage.
# Config fields: enabled(bool), toolDirectory, dataDirectory, codexHome, threadId,
# executableSha256, roles {primary,secondary,fallback,emergency: opaque native Key},
# optional bucketId (default codex), pollIntervalSeconds (5..60, default 30).
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
    return ConvertTo-Json -InputObject (ConvertTo-NativeStableJsonValue $copy) -Depth 30 -Compress
}
function Write-PriorityStatus([string]$Reason, [string]$CurrentRole = 'unknown', [string]$TargetRole = 'none') {
    $value = [ordered]@{ at=[DateTimeOffset]::UtcNow.ToString('o'); reason=$Reason
        currentRole=$CurrentRole; targetRole=$TargetRole; failedThreadResumeAvailable=$false
        failureAccountAttributionAvailable=$false; checkOnly=[bool]$CheckOnly }
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
        $buckets = @($account.Buckets | Where-Object { $_.Id -ceq $bucketId })
        $bucket = if ($buckets.Count -eq 1) { $buckets[0] } else { $null }
        $age = if ($null -ne $account.UsageCheckedAt) { ($Now - $account.UsageCheckedAt).TotalSeconds } else { -1 }
        $fresh = -not $account.RequiresApply -and $null -ne $bucket -and $age -ge 0 -and $age -le 120
        $balance = if ($null -ne $bucket) { ConvertTo-AccountPolicyNumber $bucket.CreditBalance } else { $null }
        $unlimited = if ($null -ne $bucket) { $bucket.UnlimitedCredits } else { $null }
        $spend = if ($null -ne $bucket) { $bucket.SpendControlReached } else { $null }
        $creditEligible = $null
        if ($spend -is [bool] -and $spend) { $creditEligible = $false }
        elseif ($spend -is [bool] -and -not $spend -and
            (($unlimited -is [bool] -and $unlimited) -or ($null -ne $balance -and $balance -gt 0))) { $creditEligible = $true }
        elseif ($unlimited -is [bool] -and -not $unlimited -and $null -ne $balance -and $balance -le 0) { $creditEligible = $false }
        $windows = @()
        if ($null -ne $bucket) {
            foreach ($window in @($bucket.Primary,$bucket.Secondary)) {
                if ($null -ne $window) { $windows += @{windowMins=$window.Minutes; windowUsed=$window.UsedPercent} }
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
function Invoke-PriorityCycle {
    $liveConfig = Read-PriorityJson $configPathFull
    if ((Get-PriorityConfigSignature $liveConfig) -cne $configSignature) { throw 'Priority configuration changed; restart required.' }
    if ($liveConfig.enabled -isnot [bool] -or -not $liveConfig.enabled) { Write-PriorityStatus 'disabled'; return }
    if (-not (Test-PriorityManager)) { Write-PriorityStatus 'native_manager_missing'; return }
    $snapshot = Get-NativePrioritySnapshot $context
    $currentRole = Get-PriorityRole $snapshot.CurrentKey
    $now = [DateTimeOffset]::UtcNow
    if ($null -ne $ledger.transition) {
        $claim = $ledger.transition
        $receipt = Read-PriorityReceipt
        $receiptAt = if ($null -ne $receipt) { ConvertTo-AccountPolicyTime $receipt.at } else { $null }
        $claimAt = ConvertTo-AccountPolicyTime $claim.createdAt
        $matched = $null -ne $receipt -and $null -ne $receiptAt -and $null -ne $claimAt -and
            $receiptAt -ge $claimAt -and $receipt.Id -cne $claim.priorReceiptId -and
            $receipt.TargetAccountKey -ceq $claim.targetKey -and $receipt.phase -ceq 'Finished' -and
            $receipt.AccountApplied -eq $true -and $receipt.chats -eq 0 -and
            $receipt.failed -eq 0 -and $receipt.unconfirmed -eq 0 -and [string]::IsNullOrEmpty($receipt.error) -and
            $null -eq $snapshot.PendingSwitch -and $snapshot.CurrentKey -ceq $claim.targetKey
        if ($matched) {
            if (-not $CheckOnly) {
                $ledger.lastCompleted = $claim; $ledger.lastSwitchAt = $receiptAt.ToString('o'); $ledger.transition = $null
                Save-PriorityJson $statePath $ledger
            }
            Write-PriorityStatus 'native_boundary_switch_verified_resume_unavailable' $currentRole (Get-PriorityRole $claim.targetKey)
        } else { Write-PriorityStatus 'transition_unresolved_no_retry' $currentRole (Get-PriorityRole $claim.targetKey) }
        return
    }
    if ($null -ne $snapshot.PendingSwitch) { Write-PriorityStatus 'native_transition_pending' $currentRole; return }
    $profiles = @(ConvertTo-PriorityProfiles $snapshot $now)
    $decision = Get-AccountPriorityDecision -Profiles $profiles -CurrentKey $snapshot.CurrentKey -Now $now -LastSwitchAt $ledger.lastSwitchAt
    if ($decision.action -cne 'switch') { Write-PriorityStatus $decision.reason $currentRole; return }
    $targetRole = Get-PriorityRole $decision.targetKey
    $boundary = Get-PriorityBoundary
    if (-not $boundary.Safe) { Write-PriorityStatus 'waiting_for_all_roots_idle' $currentRole $targetRole; return }
    if ($CheckOnly) { Write-PriorityStatus 'boundary_switch_candidate_not_sent' $currentRole $targetRole; return }
    # No turn cancellation or synthetic Continue. Recheck the boundary immediately
    # before the claim; native Capture still has an unavoidable external-input race.
    $again = Get-NativePrioritySnapshot $context
    $boundaryAgain = Get-PriorityBoundary
    $enabledNow = Read-PriorityJson $configPathFull
    if (-not $boundaryAgain.Safe -or $again.CurrentKey -cne $snapshot.CurrentKey -or $null -ne $again.PendingSwitch -or
        $enabledNow.enabled -isnot [bool] -or -not $enabledNow.enabled -or
        (Get-PriorityConfigSignature $enabledNow) -cne $configSignature -or -not (Test-PriorityManager)) {
        Write-PriorityStatus 'preflight_changed' $currentRole $targetRole; return
    }
    $freshDecision = Get-AccountPriorityDecision -Profiles @(ConvertTo-PriorityProfiles $again ([DateTimeOffset]::UtcNow)) -CurrentKey $again.CurrentKey -Now ([DateTimeOffset]::UtcNow) -LastSwitchAt $ledger.lastSwitchAt
    if ($freshDecision.action -cne 'switch' -or $freshDecision.targetKey -cne $decision.targetKey) { Write-PriorityStatus 'quota_decision_changed' $currentRole; return }
    if ((Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -ine $config.executableSha256) { throw 'Priority executable rejected.' }
    $prior = Read-PriorityReceipt
    $ledger.transition = @{id=[guid]::NewGuid().ToString('N'); createdAt=[DateTimeOffset]::UtcNow.ToString('o')
        sourceKey=$snapshot.CurrentKey; targetKey=$decision.targetKey; priorReceiptId=if($null -ne $prior){$prior.Id}else{$null}
        phase='claimed_before_dispatch'; resume='unavailable'}
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
    $ledger=if([IO.File]::Exists($statePath)){Read-PriorityJson $statePath}else{@{version=1;transition=$null;lastSwitchAt=$null;lastCompleted=$null}}
    if ($ledger.version -ne 1 -or -not $ledger.ContainsKey('transition') -or -not $ledger.ContainsKey('lastSwitchAt')) { throw 'Priority ledger rejected.' }
    do {
        try { Invoke-PriorityCycle }
        catch { Write-PriorityStatus 'inspection_or_dispatch_uncertain_no_retry' }
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
