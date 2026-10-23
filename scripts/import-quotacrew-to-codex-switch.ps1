# Explicit one-time migration. Do not invoke for tests; use the synthetic test.
[CmdletBinding()]
param(
    [string]$ToolDirectory = (Join-Path $env:LOCALAPPDATA 'AgentFlowOps/tools/CodexSwitch-1.41.1'),
    [string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'AgentFlowOps/data/CodexSwitch'),
    [string]$PythonExecutable = (Join-Path $env:LOCALAPPDATA 'AgentFlowOps/tools/QuotaCrew-0.3.0/venv/Scripts/python.exe'),
    [string]$CanonicalAuthPath = (Join-Path $env:USERPROFILE '.codex/auth.json')
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'codex-switch-import-core.ps1')
$context = $null; $process = $null; $memory = $null
$buffer = $null; $payloadBytes = $null; $canonicalBytes = $null
$payloadText = $null; $payload = $null; $canonicalText = $null
$result = [pscustomobject]@{ ok = $false; importedCount = 0; accountCount = 0 }
$exitCode = 1
$stage = 'context'
try {
    # This is a one-time offline import. Refuse any running manager before
    # credentials, including logical/physical MSIX path aliases with different
    # mutex spellings. Normal live management remains in the upstream app.
    $managers = [Diagnostics.Process]::GetProcessesByName('CodexSwitch')
    try { if ($managers.Length -gt 0) { throw 'Import target is busy.' } }
    finally { foreach ($manager in $managers) { $manager.Dispose() } }
    # Hash/ABI and exact original named mutex checks happen before credentials.
    $context = Open-CodexSwitchImportContext -ToolDirectory $ToolDirectory -DataDirectory $DataDirectory
    if (-not [IO.File]::Exists($PythonExecutable)) { throw 'Import prerequisite failed.' }
    $stage = 'reader-build'
    $reader = @'
import sys, os, json, asyncio, logging
sys.stderr = open(os.devnull, 'w')
logging.disable(logging.CRITICAL)

async def main():
    from codex_account_manager.storage.repositories import ProfileRepository
    from codex_account_manager.adapters.credential_store import FileCredentialStore
    profiles = await ProfileRepository().list()
    chosen = []
    for source_alias, target_alias in (('agentflow-primary', 'primary'),
                                       ('agentflow-secondary', 'secondary')):
        matches = [p for p in profiles if p.alias == source_alias]
        if len(matches) != 1:
            raise RuntimeError('profile selection failed')
        chosen.append((target_alias, matches[0].codex_home))
    store = FileCredentialStore()
    records = []
    for alias, home in chosen:
        raw = bytearray(store.read_profile(home))
        try:
            if not raw or len(raw) > 1048576:
                raise RuntimeError('profile size rejected')
            records.append({'alias': alias, 'authJson': raw.decode('utf-8')})
        finally:
            raw[:] = bytes(len(raw))
    output = bytearray(json.dumps({'formatVersion': 1, 'records': records},
                                 ensure_ascii=False, separators=(',', ':')).encode('utf-8'))
    try:
        if len(output) > 2097152:
            raise RuntimeError('payload size rejected')
        sys.stdout.buffer.write(output)
        sys.stdout.buffer.flush()
    finally:
        output[:] = bytes(len(output))
        records.clear()

try:
    asyncio.run(main())
except BaseException:
    sys.exit(1)
'@
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = [IO.Path]::GetFullPath($PythonExecutable)
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    # Only fixed reader source is in argv. Credential bytes travel solely over
    # the private redirected stdout pipe, never argv/env/files/logs.
    foreach ($argument in @('-I', '-B', '-c', $reader)) { $start.ArgumentList.Add($argument) }
    $stage = 'reader-run'
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    if (-not $process.Start()) { throw 'Import reader failed.' }
    $stderrDrain = $process.StandardError.BaseStream.CopyToAsync([IO.Stream]::Null)
    $memory = [IO.MemoryStream]::new(); $buffer = [byte[]]::new(4096)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $remaining = 30000 - [int]$watch.ElapsedMilliseconds
        if ($remaining -le 0) { throw 'Import reader timed out.' }
        $readTask = $process.StandardOutput.BaseStream.ReadAsync($buffer, 0, $buffer.Length)
        if (-not $readTask.Wait($remaining)) { throw 'Import reader timed out.' }
        $count = $readTask.GetAwaiter().GetResult()
        if ($count -eq 0) { break }
        if ($memory.Length + $count -gt 2097152) { throw 'Import reader size rejected.' }
        $memory.Write($buffer, 0, $count)
    }
    $remaining = [Math]::Max(0, 30000 - [int]$watch.ElapsedMilliseconds)
    if (-not $process.WaitForExit($remaining) -or $process.ExitCode -ne 0) { throw 'Import reader failed.' }
    $stage = 'payload-parse'
    $payloadBytes = $memory.ToArray()
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $payloadText = $utf8.GetString($payloadBytes)
    $payload = ConvertFrom-Json -InputObject $payloadText -AsHashtable -Depth 8
    if ($payload.Count -ne 2 -or $payload.formatVersion -ne 1 -or $payload.records.Count -ne 2) { throw 'Import input rejected.' }
    $stage = 'canonical-read'
    # The original method performs the canonical read. It is never written.
    if ((Get-Item -LiteralPath $CanonicalAuthPath).Length -gt 1048576) { throw 'Import input rejected.' }
    $readArguments = [object[]]::new(1)
    $readArguments[0] = [string][IO.Path]::GetFullPath($CanonicalAuthPath)
    [byte[]]$canonicalBytes = $context.ReadPrivateBytes.Invoke($null, $readArguments)
    $canonicalText = $utf8.GetString($canonicalBytes)
    $stage = 'vault-import'
    $result = Invoke-CodexSwitchVaultImport -Context $context -Records @($payload.records) -CanonicalAuthJson $canonicalText
    $exitCode = 0
} catch {
    # Never stringify a reflection/Python/JSON exception: it may retain tokens.
    $known = @('Import prerequisite failed.', 'Import dependency verification failed.', 'Import target is busy.', 'Import reader failed.', 'Import reader timed out.', 'Import reader size rejected.', 'Import input rejected.', 'Import identities rejected.', 'Import canonical identity rejected.', 'Import target is not idle.', 'Import target rejected.', 'Import existing credentials differ.')
    $cause = $_.Exception.GetBaseException()
    $reason = 'upstream-or-runtime-error'
    for ($i = 0; $i -lt $known.Count; $i++) { if ($cause.Message -ceq $known[$i]) { $reason = 'guard-' + $i; break } }
    $result = [pscustomobject]@{ ok = $false; importedCount = 0; accountCount = 0; failureStage = $stage; failureCode = $reason }
    if ($reason -eq 'guard-8') {
        foreach ($name in @('canonicalWorkspaceMatches','canonicalEmailMatchesPrimary','canonicalEmailMatchesSecondary')) {
            if ($cause.Data.Contains($name) -and $cause.Data[$name] -is [bool]) {
                $result | Add-Member -NotePropertyName $name -NotePropertyValue $cause.Data[$name]
            }
        }
    }
    [Console]::Error.WriteLine('Import failed.')
    $Error.Clear()
} finally {
    if ($null -ne $process) {
        try { if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit(5000) | Out-Null } } catch { $Error.Clear() }
        $process.Dispose()
    }
    foreach ($bytes in @($buffer, $payloadBytes, $canonicalBytes)) {
        if ($null -ne $bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
    }
    if ($null -ne $memory) { [Array]::Clear($memory.GetBuffer(), 0, [int]$memory.Length); $memory.Dispose() }
    # Strings are required by the original APIs and cannot be reliably zeroed.
    $payloadText = $null; $payload = $null; $canonicalText = $null; $reader = $null
    Close-CodexSwitchImportContext $context
}
$result | ConvertTo-Json -Compress
exit $exitCode
