# Synthetic fixtures only. Never dot-source or invoke the live reader script.
[CmdletBinding()]
param([string]$ToolDirectory = (Join-Path $env:LOCALAPPDATA 'AgentFlowOps/tools/CodexSwitch-1.41.1'))
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'codex-switch-import-core.ps1')
$testRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('AgentFlowOps-CodexSwitchImport-Test-' + [guid]::NewGuid().ToString('N'))))
$context = $null; $separateContext = $null; $secondaryContext = $null; $testCount = 0; $passed = $false
function New-SyntheticAuth([string]$Subject, [string]$Refresh, [string]$Workspace = 'fixture-workspace') {
    # Fixture construction, not credential/JWT parsing. All parsing is upstream.
    $claims = @{ sub = $Subject; email = ($Subject + '@example.invalid') } | ConvertTo-Json -Compress
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($claims)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    return (@{ auth_mode = 'chatgpt'; tokens = @{ account_id = $Workspace; id_token = ('e30.' + $encoded + '.fixture'); access_token = 'fixture-access'; refresh_token = $Refresh } } | ConvertTo-Json -Compress -Depth 5)
}
function Assert-Test([bool]$Condition) { if (-not $Condition) { throw 'Synthetic assertion failed.' } }
try {
    $context = Open-CodexSwitchImportContext -ToolDirectory $ToolDirectory -DataDirectory $testRoot
    $primary = New-SyntheticAuth 'fixture-primary' 'fixture-old'
    $canonical = New-SyntheticAuth 'fixture-primary' 'fixture-current'
    $secondary = New-SyntheticAuth 'fixture-secondary' 'fixture-secondary-refresh'
    $records = @(@{ alias = 'primary'; authJson = $primary }, @{ alias = 'secondary'; authJson = $secondary })
    $outcome = Invoke-CodexSwitchVaultImport $context $records $canonical
    Assert-Test ($outcome.ok -and $outcome.importedCount -eq 2 -and $outcome.accountCount -eq 2 -and
        $outcome.sourceProfileCount -eq 2 -and -not $outcome.separateCurrentPreserved); $testCount++
    $vaultPath = Join-Path $testRoot 'accounts.vault'
    $vault = [Activator]::CreateInstance($context.VaultType, $context.Flags, $null, [object[]]@($testRoot), $null)
    $rows = @($vault.Data.Accounts)
    Assert-Test (@($rows | Where-Object { $_.Alias -ceq 'primary' -and $_.AuthJson -ceq $canonical }).Count -eq 1)
    Assert-Test (@($rows | Where-Object { $_.Alias -ceq 'secondary' -and $_.AuthJson -ceq $secondary }).Count -eq 1); $testCount++
    # Round trip above invokes the original DPAPI Protect/Unprotect via Save/ctor.
    $sealed = [IO.File]::ReadAllBytes($vaultPath)
    try { Assert-Test (-not [Text.Encoding]::UTF8.GetString($sealed).Contains('fixture-current')) } finally { [Array]::Clear($sealed, 0, $sealed.Length) }; $testCount++
    $readArguments = [object[]]::new(1)
    $readArguments[0] = [string]$vaultPath
    [byte[]]$originalRead = $context.ReadPrivateBytes.Invoke($null, $readArguments)
    try { Assert-Test ($originalRead.Length -eq (Get-Item -LiteralPath $vaultPath).Length) } finally { [Array]::Clear($originalRead, 0, $originalRead.Length) }; $testCount++
    $rows[0].RequiresApply = $true
    $null = $context.VaultType.GetMethod('Save', $context.Flags).Invoke($vault, $null)
    $before = (Get-FileHash -LiteralPath $vaultPath -Algorithm SHA256).Hash
    $outcome = Invoke-CodexSwitchVaultImport $context $records $canonical
    Assert-Test ($outcome.importedCount -eq 0 -and (Get-FileHash -LiteralPath $vaultPath -Algorithm SHA256).Hash -ceq $before)
    $again = [Activator]::CreateInstance($context.VaultType, $context.Flags, $null, [object[]]@($testRoot), $null)
    Assert-Test ($again.Data.Accounts[0].RequiresApply); $testCount++
    foreach ($badCase in @(
        @{ records = @(@{alias='primary';authJson=$primary}, @{alias='secondary';authJson=$primary}); canonical=$canonical },
        @{ records = @(@{alias='primary';authJson=$primary}, @{alias='secondary';authJson=(New-SyntheticAuth 'fixture-secondary' 'fixture-other' 'other-workspace')}); canonical=$canonical },
        @{ records = @(@{alias='primary';authJson=$primary}, @{alias='secondary';authJson=(New-SyntheticAuth 'fixture-secondary' 'fixture-different')}); canonical=$canonical },
        @{ records = @(@{alias='primary';authJson=''}, @{alias='secondary';authJson=$secondary}); canonical=$canonical },
        @{ records = @(@{alias='primary';authJson=(New-SyntheticAuth '' 'fixture-invalid')}, @{alias='secondary';authJson=$secondary}); canonical=$canonical },
        @{ records = @(@{alias='primary';authJson=('x' * 1048577)}, @{alias='secondary';authJson=$secondary}); canonical=$canonical },
        @{ records = @(@{alias='primary';authJson=$primary}, @{alias='primary';authJson=$secondary}); canonical=$canonical }
    )) {
        $rejected = $false
        try { $null = Invoke-CodexSwitchVaultImport $context $badCase.records $badCase.canonical } catch { $rejected = $true; $Error.Clear() }
        Assert-Test ($rejected -and (Get-FileHash -LiteralPath $vaultPath -Algorithm SHA256).Hash -ceq $before); $testCount++
    }
    $pendingType = $again.Data.GetType().GetProperty('PendingSwitch').PropertyType
    $again.Data.PendingSwitch = [Activator]::CreateInstance($pendingType, $true)
    $null = $context.VaultType.GetMethod('Save', $context.Flags).Invoke($again, $null)
    $pendingBefore = (Get-FileHash -LiteralPath $vaultPath -Algorithm SHA256).Hash
    $pendingRejected = $false
    try { $null = Invoke-CodexSwitchVaultImport $context $records $canonical } catch { $pendingRejected = $true; $Error.Clear() }
    Assert-Test ($pendingRejected -and (Get-FileHash -LiteralPath $vaultPath -Algorithm SHA256).Hash -ceq $pendingBefore); $testCount++
    $busy = $false
    try { $other = Open-CodexSwitchImportContext -ToolDirectory $ToolDirectory -DataDirectory $testRoot; Close-CodexSwitchImportContext $other } catch { $busy = $true; $Error.Clear() }
    Assert-Test $busy; $testCount++
    # A different canonical user/workspace is preserved, not applied/replaced.
    $separateDirectory = Join-Path $testRoot 'separate-current-vault'
    $separateContext = Open-CodexSwitchImportContext -ToolDirectory $ToolDirectory -DataDirectory $separateDirectory
    $outsideCanonical = New-SyntheticAuth 'fixture-outside' 'fixture-outside-current' 'fixture-outside-workspace'
    # These are synthetic local files, never the real shared Codex home.
    $fakeAuthPath = Join-Path $testRoot 'canonical-fixture-auth.json'
    $fakeConfigPath = Join-Path $testRoot 'canonical-fixture-config.toml'
    [IO.File]::WriteAllText($fakeAuthPath, $outsideCanonical)
    [IO.File]::WriteAllText($fakeConfigPath, '# synthetic fixture config')
    $fakeAuthBefore = (Get-FileHash -LiteralPath $fakeAuthPath -Algorithm SHA256).Hash
    $fakeConfigBefore = (Get-FileHash -LiteralPath $fakeConfigPath -Algorithm SHA256).Hash
    $outcome = Invoke-CodexSwitchVaultImport $separateContext $records $outsideCanonical
    Assert-Test ($outcome.ok -and $outcome.importedCount -eq 3 -and $outcome.accountCount -eq 3 -and
        $outcome.sourceProfileCount -eq 2 -and $outcome.separateCurrentPreserved); $testCount++
    $fixtureArguments = [object[]]::new(1); $fixtureArguments[0] = [string]$separateDirectory
    $separateVault = [Activator]::CreateInstance($separateContext.VaultType, $separateContext.Flags, $null, $fixtureArguments, $null)
    $separateRows = @($separateVault.Data.Accounts)
    Assert-Test ($separateRows.Count -eq 3 -and
        @($separateRows | Where-Object { $_.Alias -ceq 'current' -and $_.AuthJson -ceq $outsideCanonical }).Count -eq 1 -and
        @($separateRows | Where-Object { $_.Alias -ceq 'primary' -and $_.AuthJson -ceq $primary }).Count -eq 1 -and
        @($separateRows | Where-Object { $_.Alias -ceq 'secondary' -and $_.AuthJson -ceq $secondary }).Count -eq 1); $testCount++
    Assert-Test ((Get-FileHash -LiteralPath $fakeAuthPath -Algorithm SHA256).Hash -ceq $fakeAuthBefore -and
        (Get-FileHash -LiteralPath $fakeConfigPath -Algorithm SHA256).Hash -ceq $fakeConfigBefore); $testCount++
    $separateVaultPath = Join-Path $separateDirectory 'accounts.vault'
    $separateBefore = (Get-FileHash -LiteralPath $separateVaultPath -Algorithm SHA256).Hash
    $outcome = Invoke-CodexSwitchVaultImport $separateContext $records $outsideCanonical
    Assert-Test ($outcome.importedCount -eq 0 -and $outcome.separateCurrentPreserved -and
        (Get-FileHash -LiteralPath $separateVaultPath -Algorithm SHA256).Hash -ceq $separateBefore); $testCount++
    $thirdConflictRejected = $false
    try { $null = Invoke-CodexSwitchVaultImport $separateContext $records (New-SyntheticAuth 'fixture-outside' 'fixture-outside-changed' 'fixture-outside-workspace') }
    catch { $thirdConflictRejected = $true; $Error.Clear() }
    Assert-Test ($thirdConflictRejected -and (Get-FileHash -LiteralPath $separateVaultPath -Algorithm SHA256).Hash -ceq $separateBefore); $testCount++
    # The other matching-Q case also keeps exactly two rows with current bytes.
    $secondaryDirectory = Join-Path $testRoot 'secondary-current-vault'
    $secondaryContext = Open-CodexSwitchImportContext -ToolDirectory $ToolDirectory -DataDirectory $secondaryDirectory
    $secondaryCanonical = New-SyntheticAuth 'fixture-secondary' 'fixture-secondary-current'
    $outcome = Invoke-CodexSwitchVaultImport $secondaryContext $records $secondaryCanonical
    $fixtureArguments = [object[]]::new(1); $fixtureArguments[0] = [string]$secondaryDirectory
    $secondaryVault = [Activator]::CreateInstance($secondaryContext.VaultType, $secondaryContext.Flags, $null, $fixtureArguments, $null)
    Assert-Test ($outcome.accountCount -eq 2 -and -not $outcome.separateCurrentPreserved -and
        @($secondaryVault.Data.Accounts | Where-Object { $_.Alias -ceq 'secondary' -and $_.AuthJson -ceq $secondaryCanonical }).Count -eq 1); $testCount++
    $passed = $true
} catch {
    [Console]::Error.WriteLine('Synthetic import test failed.')
    $Error.Clear()
} finally {
    Close-CodexSwitchImportContext $context
    Close-CodexSwitchImportContext $separateContext
    Close-CodexSwitchImportContext $secondaryContext
    # Retain the small synthetic encrypted fixtures; no cleanup/delete action.
}
@{ ok = $passed; testCount = $testCount } | ConvertTo-Json -Compress
if (-not $passed) { exit 1 }
