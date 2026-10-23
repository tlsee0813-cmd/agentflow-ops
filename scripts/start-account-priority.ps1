# Explicit launcher for the existing boundary supervisor. No logon trigger.
# Task Scheduler keeps it independent of a Codex app restart; one task per user.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath)
$ErrorActionPreference = 'Stop'
$taskConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$taskRunner = Join-Path $PSScriptRoot 'run-account-priority.ps1'
$taskShell = (Get-Process -Id $PID).Path
foreach ($taskPath in @($taskConfigPath,$taskRunner,$taskShell)) {
    if ($taskPath -match '["\r\n]') { throw 'Unsupported path characters.' }
}
$taskConfig = Get-Content -LiteralPath $taskConfigPath -Raw | ConvertFrom-Json
if ($taskConfig.enabled -isnot [bool] -or -not $taskConfig.enabled) { throw 'Config must be explicitly enabled.' }
if ([Environment]::Version.Major -ne 10) { throw 'Use the verified PowerShell/.NET runtime.' }
$taskArguments = '-NoProfile -WindowStyle Hidden -File "{0}" -ConfigPath "{1}"' -f $taskRunner,$taskConfigPath
$taskIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$taskName = 'AgentFlow-AccountPriority-' + $taskIdentity.Replace('-','_')
$taskExisting = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $taskExisting) {
    $taskActions = @($taskExisting.Actions)
    if ($taskActions.Count -ne 1 -or $taskActions[0].Execute -ine $taskShell -or $taskActions[0].Arguments -cne $taskArguments) {
        throw 'Another configuration owns this task. Stop and inspect it before retargeting.'
    }
} else {
    $taskAction = New-ScheduledTaskAction -Execute $taskShell -Argument $taskArguments -WorkingDirectory (Split-Path $PSScriptRoot -Parent)
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId $taskIdentity -LogonType Interactive -RunLevel Limited
    $taskSettings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Principal $taskPrincipal -Settings $taskSettings -Description 'AgentFlow explicit account-priority supervisor; no automatic logon start.' | Out-Null
}
if ($null -eq $taskExisting -or $taskExisting.State -ne 'Running') { Start-ScheduledTask -TaskName $taskName }
@{taskName=$taskName; startedOrAlreadyRunning=$true; threadId=$taskConfig.threadId; stateFileDirectory=(Split-Path $taskConfigPath -Parent); rotationVerified=$false} | ConvertTo-Json -Compress
