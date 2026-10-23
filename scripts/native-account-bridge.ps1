# Thin access to unmodified Codex Switch 1.41.1 build 98af9e4. Dot-sourcing
# defines functions only; every credential/RPC action is an explicit invocation.
Set-StrictMode -Version Latest

function Invoke-NativeBridgeMethod {
    param([Parameter(Mandatory)]$Type, [string]$Name, $Target, [object[]]$Arguments = @())
    $flags = [Reflection.BindingFlags]'Public,NonPublic,Static,Instance'
    $methods = @($Type.GetMethods($flags) | Where-Object { $_.Name -ceq $Name -and $_.GetParameters().Count -eq $Arguments.Count })
    if ($methods.Count -ne 1) { throw 'Native bridge method mismatch.' }
    $clrArgs = [object[]]::new($Arguments.Count)
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $value = $Arguments[$index]
        if ($null -ne $value) { $value = $value.PSObject.BaseObject }
        $clrArgs[$index] = $value
    }
    $returned = $methods[0].Invoke($Target, $clrArgs)
    if ($null -ne $returned -and $returned -is [Threading.Tasks.Task]) {
        if($methods[0].ReturnType.IsGenericType){return $returned.GetAwaiter().GetResult()}
        $null=$returned.GetAwaiter().GetResult()
    } else { return $returned }
}

function New-NativeBridgeObject {
    param($Type, [object[]]$Arguments = @())
    $clrArgs = [object[]]::new($Arguments.Count)
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $clrArgs[$index] = if ($null -eq $Arguments[$index]) { $null } else { $Arguments[$index].PSObject.BaseObject }
    }
    return [Activator]::CreateInstance($Type, [Reflection.BindingFlags]'Public,NonPublic,Instance', $null, $clrArgs, $null)
}

function New-NativeAccountBridgeContext {
    param([Parameter(Mandatory)][string]$ToolDirectory,
          [Parameter(Mandatory)][string]$DataDirectory,
          [Parameter(Mandatory)][string]$CodexHome,
          [Parameter(Mandatory)][string]$CurrentThreadId)
    if (-not $IsWindows -or [Environment]::Version.Major -ne 10) { throw 'Native bridge runtime unsupported.' }
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParse($CurrentThreadId, [ref]$parsedId)) { throw 'Native bridge thread rejected.' }
    $hashes = @{
        'CodexSwitch.PlatformSecurity.dll'='c51ef9eaae7e7723af03c297e120f4f901f67559977b7c6166c658cb30d516a1'
        'CodexSwitch.Core.dll'='a5094dd749fc533581257eaeea854f69c20ae59a480056032624523086f4d9c3'
        'CodexSwitch.Application.dll'='a8b50f87cffaf7e18b27656f012f469a92b05b35526e5ff8b6b06561be50793b'
        'CodexSwitch.DesktopClient.dll'='b43caa1cfd9890f2514d1c0f526e9ecbd7c630d0920b417d8beac146d338e0da'
        'CodexSwitch.Protocol.dll'='b711e8f27182fa89d003c25cfaccd8c57ab33257b654b1c14fd61eaa760047d1'
        'CodexSwitch.Sqlite.dll'='ad7d6392360b3f05276ea7210c37af333d80a45d9bee540e1b9ea357d39205e3'
    }
    foreach ($pair in $hashes.GetEnumerator()) {
        $path = Join-Path $ToolDirectory $pair.Key
        if (-not [IO.File]::Exists($path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $pair.Value) { throw 'Native bridge dependency rejected.' }
    }
    $assemblies = @{}
    foreach ($name in @('PlatformSecurity','Core','Protocol','DesktopClient','Sqlite','Application')) {
        $assemblies[$name] = [Reflection.Assembly]::LoadFrom((Join-Path $ToolDirectory ('CodexSwitch.' + $name + '.dll')))
    }
    $types = @{}
    foreach ($pair in @(@('SecureFiles','PlatformSecurity'),@('AuthDocument','Core'),@('SwitchChat','Core'),
        @('AccountVault','Application'),@('AccountService','Application'),@('DesktopSwitchBackend','Application'),
        @('DesktopSessionMonitor','Protocol'),@('CodexRpc','Protocol'),@('RuntimeLocator','DesktopClient'))) {
        $types[$pair[0]] = $assemblies[$pair[1]].GetType(('CodexAccountDesk.' + $pair[0]), $true)
    }
    # No vault ctor, canonical read, monitor start or process launch here.
    return [pscustomobject]@{ ToolDirectory=[IO.Path]::GetFullPath($ToolDirectory); DataDirectory=[IO.Path]::GetFullPath($DataDirectory)
        CodexHome=[IO.Path]::GetFullPath($CodexHome); CurrentThreadId=$CurrentThreadId; Types=$types
        Monitor=$null; Disposed=$false }
}

function Get-NativePrioritySnapshot {
    param([Parameter(Mandatory)]$Context)
    if ($Context.Disposed) { throw 'Native bridge closed.' }
    $vault = New-NativeBridgeObject $Context.Types.AccountVault @([string]$Context.DataDirectory)
    $authPath = Join-Path $Context.CodexHome 'auth.json'
    [byte[]]$bytes = $null
    try {
        if ((Get-Item -LiteralPath $authPath).Length -gt 1048576) { throw 'Native bridge auth rejected.' }
        $bytes = Invoke-NativeBridgeMethod $Context.Types.SecureFiles 'ReadPrivateBytes' $null @([string]$authPath)
        $json = [Text.UTF8Encoding]::new($false,$true).GetString($bytes)
        $canonical = Invoke-NativeBridgeMethod $Context.Types.AuthDocument 'Parse' $null @([string]$json)
        $accounts = @($vault.Data.Accounts | ForEach-Object {
            $profile = $_; $usage = $profile.Usage
            [pscustomobject]@{ Key=[string]$profile.Key; Alias=[string]$profile.Alias; Plan=[string]$profile.Plan
                RequiresApply=[bool]$profile.RequiresApply; IsCurrent=($profile.Key -ceq $canonical.Key)
                UsageCheckedAt=if($null -ne $usage){$usage.CheckedAt}else{$null}
                OrdinaryUsageAllowed=if($null -ne $usage){$usage.OrdinaryUsageAllowed}else{$null}
                # Error text and credentials are deliberately not projected.
                Buckets=if($null -ne $usage){@($usage.Buckets | ForEach-Object {
                    [pscustomobject]@{Id=$_.Id; Primary=if($null -ne $_.Primary){[pscustomobject]@{UsedPercent=$_.Primary.UsedPercent;Minutes=$_.Primary.Minutes;ResetsAt=$_.Primary.ResetsAt}}else{$null}
                        Secondary=if($null -ne $_.Secondary){[pscustomobject]@{UsedPercent=$_.Secondary.UsedPercent;Minutes=$_.Secondary.Minutes;ResetsAt=$_.Secondary.ResetsAt}}else{$null}
                        LimitState=$_.LimitState; SpendControlReached=$_.SpendControlReached
                        CreditBalance=$_.CreditBalance; UnlimitedCredits=$_.UnlimitedCredits }
                })}else{@()} }
        })
        $pending = $vault.Data.PendingSwitch
        return [pscustomobject]@{ CurrentKey=[string]$canonical.Key; Accounts=$accounts
            PendingSwitch=if($null -ne $pending){[pscustomobject]@{Id=$pending.Id;TargetAccountKey=$pending.TargetAccountKey;Phase=[string]$pending.Phase;AccountApplied=$pending.AccountApplied}}else{$null} }
    } finally { if($null -ne $bytes){[Array]::Clear($bytes,0,$bytes.Length)}; $json=$null; $canonical=$null; $vault=$null }
}

function Get-NativeBridgeMonitor {
    param($Context)
    if ($Context.Disposed) { throw 'Native bridge closed.' }
    if ($null -eq $Context.Monitor) {
        $Context.Monitor = New-NativeBridgeObject $Context.Types.DesktopSessionMonitor @([string]$Context.CodexHome)
        $null = Invoke-NativeBridgeMethod $Context.Types.DesktopSessionMonitor 'Start' $Context.Monitor
    }
    $null = Invoke-NativeBridgeMethod $Context.Types.DesktopSessionMonitor 'WaitForDiscoveryAsync' $Context.Monitor @([Threading.CancellationToken]::None)
    return $Context.Monitor
}

function ConvertTo-NativeStableJsonValue {
    param($Value)
    if($null -eq $Value){return $null}
    if($Value -is [Collections.IDictionary]){
        $ordered=[ordered]@{}
        foreach($key in @($Value.Keys | Sort-Object -CaseSensitive)){ $ordered[[string]$key]=ConvertTo-NativeStableJsonValue $Value[$key] }
        return $ordered
    }
    if($Value -is [Collections.IList]){return ,@($Value | ForEach-Object {ConvertTo-NativeStableJsonValue $_})}
    return $Value
}

function Get-NativeThreadState {
    param([Parameter(Mandatory)]$Context, [switch]$IncludeSettings)
    $monitor = Get-NativeBridgeMonitor $Context
    $threads = @($monitor.Threads)
    $current = @($threads | Where-Object {$_.Id -ceq $Context.CurrentThreadId})
    $settingsHash=$null; $settingsVerified=$false
    if($current.Count -eq 1 -and $IncludeSettings){
        $parameters=[Collections.Generic.Dictionary[string,object]]::new()
        $parameters.Add('conversationId',[string]$Context.CurrentThreadId)
        $result=Invoke-NativeBridgeMethod $Context.Types.DesktopSessionMonitor 'SendToOwnerAsync' $monitor @($current[0], [string]'thread-follower-read-model-settings', $parameters, [int]1, [Threading.CancellationToken]::None)
        $element=[Text.Json.JsonElement]::new()
        if($result.TryGetProperty('settings',[ref]$element) -and $element.ValueKind -eq [Text.Json.JsonValueKind]::Object){
            $settings=ConvertFrom-Json -InputObject $element.GetRawText() -AsHashtable -Depth 100
            $stable=ConvertTo-Json -InputObject (ConvertTo-NativeStableJsonValue $settings) -Compress -Depth 100
            $settingsHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($stable))).ToLowerInvariant()
            $settingsVerified=$true
        }
    }
    return [pscustomobject]@{Available=[bool]$monitor.Current.Available; CurrentFound=($current.Count -eq 1)
        CurrentStatus=if($current.Count -eq 1){$current[0].Status}else{$null}
        LastTurnId=if($current.Count -eq 1){$current[0].LastTurnId}else{$null}
        LastTurnStatus=if($current.Count -eq 1){$current[0].LastTurnStatus}else{$null}
        Goal=if($current.Count -eq 1){$current[0].Goal}else{$null}
        Waiting=if($current.Count -eq 1){[bool]$current[0].Waiting}else{$false}
        OtherActiveCount=@($threads|Where-Object{$_.Id -cne $Context.CurrentThreadId -and $_.Status -ceq 'active'}).Count
        Queued=$monitor.Current.Queued; QueueProblemPresent=($null -ne $monitor.Current.QueueProblem)
        SettingsHash=$settingsHash; SettingsVerified=$settingsVerified }
}

function ConvertFrom-NativeLatestTurnDisposition {
    param([Parameter(Mandatory)]$Thread, [Parameter(Mandatory)][string]$ExpectedThreadId)
    # Codex source d4bdafd schema/typescript/v2/{Turn,TurnError,CodexErrorInfo}.
    # Rate-limit, HTTP errors, unknown variants, and text messages never prove quota.
    if($Thread -isnot [Collections.IDictionary] -or -not $Thread.Contains('id') -or $Thread['id'] -cne $ExpectedThreadId){throw 'Native bridge thread mismatch.'}
    $turns=@(if($Thread.Contains('turns')){$Thread['turns']});$last=if($turns.Count -gt 0){$turns[-1]}else{$null}
    $status=$null;$turnId=$null;$confirmed=$false
    if($last -is [Collections.IDictionary]){
        $status=if($last.Contains('status')){[string]$last['status']}else{$null}
        $turnId=if($last.Contains('id')){[string]$last['id']}else{$null}
        $errorValue=if($last.Contains('error')){$last['error']}else{$null}
        $confirmed=$status -cin @('failed','interrupted') -and $null -ne $errorValue -and
            $errorValue -is [Collections.IDictionary] -and $errorValue.Contains('codexErrorInfo') -and
            $errorValue['codexErrorInfo'] -is [string] -and $errorValue['codexErrorInfo'] -ceq 'usageLimitExceeded' -and
            -not [string]::IsNullOrWhiteSpace($turnId)
    }
    return [pscustomobject]@{LastTurnStatus=$status;TurnId=$turnId;UsageLimitErrorConfirmed=[bool]$confirmed}
}

function Initialize-NativeSnapshotTap {
    if ('AgentFlowOps.NativeSnapshotTap' -as [type]) { return }
    # Compatibility projection only. Original monitor owns connection, framing,
    # discovery and subscription. This stream observes one full owner snapshot;
    # patches and conversation items are never retained or exposed.
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
namespace AgentFlowOps {
 public sealed class NativeTurnMetadata {
  public bool Observable {get;set;}
  public string RuntimeStatus {get;set;}
  public string TurnId {get;set;}
  public string LastTurnStatus {get;set;}
  public bool UsageLimitErrorConfirmed {get;set;}
 }
 public sealed class NativeSnapshotTap : Stream {
  readonly Stream inner; readonly string thread; string owner;
  readonly byte[] header=new byte[4]; int headerUsed,bodyUsed; byte[] body;
  readonly TaskCompletionSource<NativeTurnMetadata> result=new(TaskCreationOptions.RunContinuationsAsynchronously);
  public NativeSnapshotTap(Stream inner,string thread){this.inner=inner;this.thread=thread;}
  public void SetOwner(string owner){this.owner=owner;}
  public Task<NativeTurnMetadata> Result=>result.Task;
  public int SnapshotBytes {get;private set;}
  static string Str(JsonElement e,string name)=>e.ValueKind==JsonValueKind.Object && e.TryGetProperty(name,out var v) && v.ValueKind==JsonValueKind.String?v.GetString():null;
  static bool Obj(JsonElement e,string name,out JsonElement v){v=default;return e.ValueKind==JsonValueKind.Object && e.TryGetProperty(name,out v) && v.ValueKind==JsonValueKind.Object;}
  public static NativeTurnMetadata Project(JsonElement state){
   var answer=new NativeTurnMetadata();
   if(!Obj(state,"threadRuntimeStatus",out var runtime))return answer;
   answer.RuntimeStatus=Str(runtime,"type");
   if(answer.RuntimeStatus!="active" && answer.RuntimeStatus!="idle")return answer;
   JsonElement turn=default;
   bool canonical=state.TryGetProperty("turnHistory",out var th) && Str(th,"kind")=="canonical";
   if(canonical){
    if(!Obj(th,"history",out var history) || !history.TryGetProperty("islands",out var islands) || islands.ValueKind!=JsonValueKind.Array || islands.GetArrayLength()==0 || !Obj(history,"entitiesByKey",out var entities))return answer;
    var tail=islands[islands.GetArrayLength()-1];
    if(!Obj(tail,"newerBoundary",out var boundary) || Str(boundary,"status")!="exhausted" || !tail.TryGetProperty("entries",out var entries) || entries.ValueKind!=JsonValueKind.Array || entries.GetArrayLength()==0)return answer;
    var key=Str(entries[entries.GetArrayLength()-1],"value");
    if(key==null || !entities.TryGetProperty(key,out turn) || turn.ValueKind!=JsonValueKind.Object)return answer;
   }else{
    if(state.TryGetProperty("turnHistory",out th) && th.ValueKind!=JsonValueKind.Null)return answer;
    if(!state.TryGetProperty("turns",out var turns) || turns.ValueKind!=JsonValueKind.Array || turns.GetArrayLength()==0)return answer;
    turn=turns[turns.GetArrayLength()-1];
   }
   var id=Str(turn,"turnId");var status=Str(turn,"status");
   if(string.IsNullOrWhiteSpace(id) || !(status=="inProgress" || status=="completed" || status=="failed" || status=="interrupted"))return answer;
   if(canonical && state.TryGetProperty("turns",out var overlay) && overlay.ValueKind==JsonValueKind.Array && overlay.GetArrayLength()>0){
    var last=overlay[overlay.GetArrayLength()-1];
    if(Str(last,"turnId")!=id || Str(last,"status")!=status)return answer;
   }
   if((answer.RuntimeStatus=="active")!=(status=="inProgress"))return answer;
   answer.Observable=true;answer.TurnId=id;answer.LastTurnStatus=status;
   answer.UsageLimitErrorConfirmed=(status=="failed" || status=="interrupted") && Obj(turn,"error",out var error) && Str(error,"codexErrorInfo")=="usageLimitExceeded";
   return answer;
  }
  void Inspect(byte[] bytes){
   if(result.Task.IsCompleted || owner==null)return;
   using var document=JsonDocument.Parse(bytes);
   var message=document.RootElement;
   if(Str(message,"type")!="broadcast" || Str(message,"method")!="thread-stream-state-changed")return;
   if(!Obj(message,"params",out var p) || Str(p,"hostId")!="local" || Str(p,"conversationId")!=thread)return;
   if(Str(message,"sourceClientId")!=owner || !message.TryGetProperty("version",out var version) || !version.TryGetInt32(out var v) || v!=11)throw new InvalidDataException("Native snapshot identity rejected.");
   if(!Obj(p,"change",out var change) || Str(change,"type")!="snapshot")return;
   if(!change.TryGetProperty("revision",out var revision) || !revision.TryGetInt64(out var r) || r<0 || !Obj(change,"conversationState",out var state))throw new InvalidDataException("Native snapshot state rejected.");
   SnapshotBytes=bytes.Length;result.TrySetResult(Project(state));
  }
  void Capture(ReadOnlySpan<byte> bytes){
   while(!bytes.IsEmpty){
    if(body==null){int n=Math.Min(4-headerUsed,bytes.Length);bytes.Slice(0,n).CopyTo(header.AsSpan(headerUsed));headerUsed+=n;bytes=bytes.Slice(n);if(headerUsed<4)continue;
     int size=System.Buffers.Binary.BinaryPrimitives.ReadInt32LittleEndian(header);if(size<=0 || size>268435456)throw new InvalidDataException("Native snapshot frame rejected.");body=new byte[size];bodyUsed=0;}
    int take=Math.Min(body.Length-bodyUsed,bytes.Length);bytes.Slice(0,take).CopyTo(body.AsSpan(bodyUsed));bodyUsed+=take;bytes=bytes.Slice(take);
    if(bodyUsed==body.Length){try{Inspect(body);}catch{result.TrySetException(new InvalidDataException("Native snapshot projection failed."));throw;}finally{Array.Clear(body);body=null;bodyUsed=0;headerUsed=0;}}
   }
  }
  public override async ValueTask<int> ReadAsync(Memory<byte> buffer,CancellationToken cancellation=default){int n=await inner.ReadAsync(buffer,cancellation);Capture(buffer.Span.Slice(0,n));return n;}
  public override int Read(byte[] b,int o,int c){int n=inner.Read(b,o,c);Capture(b.AsSpan(o,n));return n;}
  public override ValueTask WriteAsync(ReadOnlyMemory<byte> b,CancellationToken c=default)=>inner.WriteAsync(b,c);
  public override Task WriteAsync(byte[] b,int o,int n,CancellationToken c)=>inner.WriteAsync(b,o,n,c);
  public override void Write(byte[] b,int o,int c)=>inner.Write(b,o,c);
  public override bool CanRead=>inner.CanRead;public override bool CanWrite=>inner.CanWrite;public override bool CanSeek=>false;
  public override long Length=>throw new NotSupportedException();public override long Position{get=>throw new NotSupportedException();set=>throw new NotSupportedException();}
  public override void Flush()=>inner.Flush();public override long Seek(long o,SeekOrigin s)=>throw new NotSupportedException();public override void SetLength(long l)=>throw new NotSupportedException();
  protected override void Dispose(bool disposing){if(disposing){if(body!=null)Array.Clear(body);inner.Dispose();}base.Dispose(disposing);}
 }
}
'@
}

function Get-NativeOwnerTurnDisposition {
    param([Parameter(Mandatory)]$Context)
    if($Context.Disposed){throw 'Native bridge closed.'}
    Initialize-NativeSnapshotTap
    $sampler=$null;$pipe=$null;$tap=$null;$reader=$null
    $cancel=[Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(12))
    try {
        # Original methods and parser retain the native protocol/security checks.
        $sampler=New-NativeBridgeObject $Context.Types.DesktopSessionMonitor @([string]$Context.CodexHome)
        $pipe=Invoke-NativeBridgeMethod $Context.Types.DesktopSessionMonitor 'ConnectAsync' $sampler @($cancel.Token)
        $tap=[AgentFlowOps.NativeSnapshotTap]::new($pipe,[string]$Context.CurrentThreadId)
        $flags=[Reflection.BindingFlags]'Instance,NonPublic'
        $readMethod=$Context.Types.DesktopSessionMonitor.GetMethod('ReadAsync',$flags)
        $reader=$readMethod.Invoke($sampler,[object[]]@($tap,$cancel.Token))
        $initialize=[Collections.Generic.Dictionary[string,object]]::new();$initialize.Add('clientType','codex-account-desk')
        $null=Invoke-NativeBridgeMethod $Context.Types.DesktopSessionMonitor 'RequestAsync' $sampler @($tap,'initialize',$initialize,[int]0,$cancel.Token,$null,$null)
        $parameters=[Collections.Generic.Dictionary[string,object]]::new()
        $parameters.Add('hostId','local');$parameters.Add('conversationId',[string]$Context.CurrentThreadId)
        $ownerResponse=Invoke-NativeBridgeMethod $Context.Types.DesktopSessionMonitor 'RequestAsync' $sampler @($tap,'thread-owner-discovery',$parameters,[int]1,$cancel.Token,$null,$null)
        $ownerId=$ownerResponse.GetProperty('handledByClientId').GetString()
        if($ownerResponse.GetProperty('resultType').GetString() -cne 'success' -or [string]::IsNullOrWhiteSpace($ownerId)){throw 'Native owner unavailable.'}
        $tap.SetOwner($ownerId)
        $nativeLedger=$Context.Types.DesktopSessionMonitor.GetField('_ledger',$flags).GetValue($sampler)
        $null=Invoke-NativeBridgeMethod ($nativeLedger.GetType()) 'Discover' $nativeLedger @([string]$Context.CurrentThreadId,[string]$ownerId)
        $null=Invoke-NativeBridgeMethod $Context.Types.DesktopSessionMonitor 'FollowAsync' $sampler @($tap,[string]$Context.CurrentThreadId,[bool]$true,$cancel.Token)
        $result=$tap.Result.WaitAsync($cancel.Token).GetAwaiter().GetResult()
        return [pscustomobject]@{Observable=$result.Observable;RuntimeStatus=$result.RuntimeStatus;TurnId=$result.TurnId
            LastTurnStatus=$result.LastTurnStatus;UsageLimitErrorConfirmed=$result.UsageLimitErrorConfirmed;Source='owner_snapshot';SnapshotBytes=$tap.SnapshotBytes}
    } catch { throw [InvalidOperationException]::new('Native owner snapshot inspection unavailable.') }
    finally {
        $cancel.Cancel()
        if($null -ne $tap){$tap.Dispose()}elseif($null -ne $pipe){$pipe.Dispose()}
        if($null -ne $reader){try{$null=$reader.GetAwaiter().GetResult()}catch{}}
        if($null -ne $sampler){try{$null=Dispose-NativeAccountBridgeContext ([pscustomobject]@{Disposed=$false;Monitor=$sampler;Types=$Context.Types})}catch{}}
        $cancel.Dispose()
    }
}

function Get-NativeLatestTurnDisposition {
    param([Parameter(Mandatory)]$Context)
    # A separately launched app-server can normalize another process's running
    # turn as interrupted. Only the actual desktop owner proves live turn state.
    try {$latest=Get-NativeOwnerTurnDisposition $Context}
    catch {throw [InvalidOperationException]::new('Native latest-turn inspection unavailable.')}
    if (-not $latest.Observable) { throw [InvalidOperationException]::new('Native latest-turn inspection unavailable.') }
    return $latest
}

function Invoke-NativeThreadResume {
    param([Parameter(Mandatory)]$Context,
          [Parameter(Mandatory)][string]$TargetAccountKey,
          [Parameter(Mandatory)][string]$OriginalTurnId,
          [Parameter(Mandatory)][string]$ContinueMessageId,
          [Parameter(Mandatory)][string]$ExpectedSettingsHash,
          [Parameter(Mandatory)][bool]$ClaimRecorded)
    # Caller owns a durable, non-retryable claim BEFORE entering this function.
    # Once entered, any failure is uncertain; never repeat based on an exception.
    if(-not $ClaimRecorded -or $Context.Disposed){throw 'Native resume claim required.'}
    $messageGuid=[guid]::Empty
    if(-not [guid]::TryParse($ContinueMessageId,[ref]$messageGuid) -or
        $ExpectedSettingsHash -cnotmatch '^[a-f0-9]{64}$'){throw 'Native resume input rejected.'}
    $snapshot=Get-NativePrioritySnapshot $Context
    if($snapshot.CurrentKey -cne $TargetAccountKey -or $null -ne $snapshot.PendingSwitch){throw 'Native resume account changed.'}
    $state=Get-NativeThreadState $Context -IncludeSettings
    if(-not $state.Available -or -not $state.CurrentFound -or $state.CurrentStatus -cne 'idle' -or
        $state.Waiting -or $state.OtherActiveCount -ne 0 -or $state.Queued -ne 0 -or $state.QueueProblemPresent -or
        -not $state.SettingsVerified -or $state.SettingsHash -cne $ExpectedSettingsHash){throw 'Native resume state rejected.'}
    $latest=Get-NativeLatestTurnDisposition $Context
    if(-not $latest.UsageLimitErrorConfirmed -or $latest.TurnId -cne $OriginalTurnId){throw 'Native resume turn changed.'}
    $backend=$null;$service=$null
    try{
        $vault=New-NativeBridgeObject $Context.Types.AccountVault @([string]$Context.DataDirectory)
        $service=New-NativeBridgeObject $Context.Types.AccountService @($vault,[string]$Context.CodexHome,$null,$null,$null)
        $installation=Invoke-NativeBridgeMethod $Context.Types.RuntimeLocator 'FindAsync' $null @([Threading.CancellationToken]::None)
        # Build-pinned internal ABI: set ONLY in-memory state. InitializeAsync is
        # deliberately not called: it cleans runtime directories and saves vault.
        $Context.Types.AccountService.GetProperty('Installation').SetValue($service,$installation)
        $Context.Types.AccountService.GetProperty('CurrentKey').SetValue($service,[string]$TargetAccountKey)
        $backend=New-NativeBridgeObject $Context.Types.DesktopSwitchBackend @($service,$Context.Monitor,[string]$TargetAccountKey)
        $chat=New-NativeBridgeObject $Context.Types.SwitchChat
        $chat.Id=[string]$Context.CurrentThreadId;$chat.OriginalTurnId=[string]$OriginalTurnId
        $chat.OriginalGoal=[string]$state.Goal;$chat.ContinueMessageId=[string]$ContinueMessageId
        if(-not ('AgentFlowOps.NativeBridgeNoop' -as [type])){
            Add-Type -TypeDefinition 'namespace AgentFlowOps { public static class NativeBridgeNoop { public static void Sending() {} } }'
        }
        # Native CLR delegate works on original async thread-pool continuations;
        # a PowerShell scriptblock delegate would require a missing runspace.
        $callback=[Delegate]::CreateDelegate([Action],[AgentFlowOps.NativeBridgeNoop].GetMethod('Sending'))
        $lastAccountCheck=Get-NativePrioritySnapshot $Context
        if($lastAccountCheck.CurrentKey -cne $TargetAccountKey -or $null -ne $lastAccountCheck.PendingSwitch){throw 'Native resume account changed.'}
        $nativeResult=Invoke-NativeBridgeMethod $Context.Types.DesktopSwitchBackend 'ResumeAsync' $backend @($chat,$callback,[Threading.CancellationToken]::None)
        $after=Get-NativeThreadState $Context -IncludeSettings
        return [pscustomobject]@{ResumeState=[string]$nativeResult;SettingsPreserved=($after.SettingsVerified -and $after.SettingsHash -ceq $ExpectedSettingsHash)
            SameThread=$after.CurrentFound;LastTurnId=$after.LastTurnId;LastTurnStatus=$after.LastTurnStatus}
    }finally{
        if($null -ne $backend){$dispose=Invoke-NativeBridgeMethod $Context.Types.DesktopSwitchBackend 'DisposeAsync' $backend;$null=$dispose.AsTask().GetAwaiter().GetResult()}
        if($null -ne $service){$null=Invoke-NativeBridgeMethod $Context.Types.AccountService 'StopAsync' $service}
    }
}

function Dispose-NativeAccountBridgeContext {
    param([Parameter(Mandatory)]$Context)
    if($Context.Disposed){return}
    try{if($null -ne $Context.Monitor){$dispose=Invoke-NativeBridgeMethod $Context.Types.DesktopSessionMonitor 'DisposeAsync' $Context.Monitor;$null=$dispose.AsTask().GetAwaiter().GetResult()}}
    finally{$Context.Monitor=$null;$Context.Disposed=$true}
}
