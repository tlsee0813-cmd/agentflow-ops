# One-time adapter only. All credential identity, protection and vault writes use
# unmodified CodexSwitch 1.41.1 (build 98af9e4) methods. No live auth writer here.
Set-StrictMode -Version Latest

function Open-CodexSwitchImportContext {
    param([Parameter(Mandatory)][string]$ToolDirectory,
          [Parameter(Mandatory)][string]$DataDirectory)
    if (-not $IsWindows -or [Environment]::Version.Major -ne 10) { throw 'Import prerequisite failed.' }
    $hashes = [ordered]@{
        'CodexSwitch.PlatformSecurity.dll' = 'c51ef9eaae7e7723af03c297e120f4f901f67559977b7c6166c658cb30d516a1'
        'CodexSwitch.Core.dll' = 'a5094dd749fc533581257eaeea854f69c20ae59a480056032624523086f4d9c3'
        'CodexSwitch.Application.dll' = 'a8b50f87cffaf7e18b27656f012f469a92b05b35526e5ff8b6b06561be50793b'
        'CodexSwitch.DesktopClient.dll' = 'b43caa1cfd9890f2514d1c0f526e9ecbd7c630d0920b417d8beac146d338e0da'
        'CodexSwitch.Protocol.dll' = 'b711e8f27182fa89d003c25cfaccd8c57ab33257b654b1c14fd61eaa760047d1'
        'CodexSwitch.Sqlite.dll' = 'ad7d6392360b3f05276ea7210c37af333d80a45d9bee540e1b9ea357d39205e3'
    }
    $tool = [IO.Path]::GetFullPath($ToolDirectory)
    $data = [IO.Path]::GetFullPath($DataDirectory)
    foreach ($entry in $hashes.GetEnumerator()) {
        $file = Join-Path $tool $entry.Key
        if (-not [IO.File]::Exists($file) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.Value) {
            throw 'Import dependency verification failed.'
        }
    }
    # Only these three assemblies are needed by the original vault/parser.
    $security = [Reflection.Assembly]::LoadFrom((Join-Path $tool 'CodexSwitch.PlatformSecurity.dll'))
    $core = [Reflection.Assembly]::LoadFrom((Join-Path $tool 'CodexSwitch.Core.dll'))
    $application = [Reflection.Assembly]::LoadFrom((Join-Path $tool 'CodexSwitch.Application.dll'))
    $secureFiles = $security.GetType('CodexAccountDesk.SecureFiles', $true)
    $authDocument = $core.GetType('CodexAccountDesk.AuthDocument', $true)
    $vaultType = $application.GetType('CodexAccountDesk.AccountVault', $true)
    $flags = [Reflection.BindingFlags]'Public,NonPublic,Static,Instance'
    $hashMethod = $secureFiles.GetMethod('Hash', $flags)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    # Exactly Program.cs's SID + full data-directory namespace, not a new lock.
    $namespace = $hashMethod.Invoke($null, [object[]]@($sid + "`n" + $data)).Substring(0, 24)
    $created = $false
    $mutex = [Threading.Mutex]::new($true, ('Local\CodexAccountDesk-' + $namespace), [ref]$created)
    if (-not $created) { $mutex.Dispose(); throw 'Import target is busy.' }
    return [pscustomobject]@{
        DataDirectory = $data; Mutex = $mutex; VaultType = $vaultType
        Parse = $authDocument.GetMethod('Parse', $flags)
        ReadPrivateBytes = $secureFiles.GetMethod('ReadPrivateBytes', $flags)
        Flags = $flags
    }
}

function Close-CodexSwitchImportContext {
    param($Context)
    if ($null -ne $Context -and $null -ne $Context.Mutex) {
        try { $Context.Mutex.ReleaseMutex() } finally { $Context.Mutex.Dispose() }
    }
}

function Invoke-CodexSwitchVaultImport {
    param([Parameter(Mandatory)]$Context,
          [Parameter(Mandatory)][object[]]$Records,
          [Parameter(Mandatory)][string]$CanonicalAuthJson)
    if ($Records.Count -ne 2) { throw 'Import input rejected.' }
    $parsed = @()
    $aliases = @('primary', 'secondary')
    foreach ($alias in $aliases) {
        $matches = @($Records | Where-Object { $_.alias -ceq $alias })
        if ($matches.Count -ne 1 -or $matches[0].authJson -isnot [string] -or
            [Text.Encoding]::UTF8.GetByteCount($matches[0].authJson) -gt 1048576) { throw 'Import input rejected.' }
        $arguments = [object[]]::new(1)
        $arguments[0] = [string]$matches[0].authJson
        $profile = $Context.Parse.Invoke($null, $arguments)
        $parsed += [pscustomobject]@{ Alias = $alias; Profile = $profile; AuthJson = $matches[0].authJson }
    }
    # The original key hashes workspace + sub. At the same workspace, different
    # original keys therefore distinguish users without adding a JWT parser.
    if ($parsed[0].Profile.Key -ceq $parsed[1].Profile.Key -or
        $parsed[0].Profile.AccountId -cne $parsed[1].Profile.AccountId) { throw 'Import identities rejected.' }
    if ([Text.Encoding]::UTF8.GetByteCount($CanonicalAuthJson) -gt 1048576) { throw 'Import input rejected.' }
    $arguments = [object[]]::new(1)
    $arguments[0] = [string]$CanonicalAuthJson
    $canonical = $Context.Parse.Invoke($null, $arguments)
    $current = @($parsed | Where-Object { $_.Profile.Key -ceq $canonical.Key })
    if ($current.Count -gt 1) {
        $rejected = [InvalidOperationException]::new('Import canonical identity rejected.')
        $rejected.Data['canonicalWorkspaceMatches'] = [bool]($canonical.AccountId -ceq $parsed[0].Profile.AccountId)
        $rejected.Data['canonicalEmailMatchesPrimary'] = [bool]($canonical.Email -and $canonical.Email -ieq $parsed[0].Profile.Email)
        $rejected.Data['canonicalEmailMatchesSecondary'] = [bool]($canonical.Email -and $canonical.Email -ieq $parsed[1].Profile.Email)
        throw $rejected
    }
    $separateCurrentPreserved = $current.Count -eq 0
    if ($separateCurrentPreserved) {
        # As in native current-account import, preserve an unrelated current
        # login as a third vault row. Nothing is applied to the live Codex home.
        $parsed += [pscustomobject]@{ Alias = 'current'; Profile = $canonical; AuthJson = $CanonicalAuthJson }
    } else {
        # Prefer exact current credentials over an older QuotaCrew snapshot.
        $current[0].AuthJson = $CanonicalAuthJson
    }
    $arguments = [object[]]::new(1)
    $arguments[0] = [string]$Context.DataDirectory
    $vault = [Activator]::CreateInstance($Context.VaultType, $Context.Flags, $null, $arguments, $null)
    if ($null -ne $vault.Data.PendingSwitch) { throw 'Import target is not idle.' }
    $pending = @()
    foreach ($item in $parsed) {
        $existing = @($vault.Data.Accounts | Where-Object { $_.Key -ceq $item.Profile.Key })
        if ($existing.Count -gt 1) { throw 'Import target rejected.' }
        if ($existing.Count -eq 1) {
            if ($existing[0].AuthJson -cne $item.AuthJson) { throw 'Import existing credentials differ.' }
            # An existing row is a complete no-op, including Alias/RequiresApply.
        } else { $pending += $item }
    }
    # No mutation until *all* input and existing rows have passed validation.
    foreach ($item in $pending) {
        $arguments = [object[]]::new(1)
        $arguments[0] = [string]$item.AuthJson
        $added = $Context.VaultType.GetMethod('Upsert', $Context.Flags).Invoke($vault, $arguments)
        $added.Alias = $item.Alias
    }
    if ($pending.Count -gt 0) { $null = $Context.VaultType.GetMethod('Save', $Context.Flags).Invoke($vault, $null) }
    return [pscustomobject]@{
        ok = $true; importedCount = $pending.Count; accountCount = $vault.Data.Accounts.Count
        sourceProfileCount = 2; separateCurrentPreserved = $separateCurrentPreserved
    }
}
