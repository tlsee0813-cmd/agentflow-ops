# Run in a local interactive PowerShell; never paste a key into the Codex chat.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This secret-input helper uses Windows file ACLs.' }
$taskRoot = Split-Path $PSScriptRoot -Parent
$authRoot = Join-Path $taskRoot '.ops/dsh-home'
New-Item -ItemType Directory -Force $authRoot | Out-Null
$taskIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$taskAcl = [System.Security.AccessControl.DirectorySecurity]::new()
$taskAcl.SetAccessRuleProtection($true, $false)
$taskAcl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($taskIdentity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
Set-Acl -LiteralPath $authRoot -AclObject $taskAcl
$taskSecret = Read-Host 'DeepSeek API key (hidden local input)' -AsSecureString
$taskPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecret)
try {
    $taskPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPointer)
    if ([string]::IsNullOrWhiteSpace($taskPlain) -or $taskPlain -match '[\r\n"''\s]') { throw 'Empty keys or keys containing whitespace/quotes are rejected.' }
    $taskPath = Join-Path $authRoot '.env'
    [System.IO.File]::WriteAllText($taskPath, "DEEPSEEK_API_KEY=$taskPlain`n", [System.Text.UTF8Encoding]::new($false))
    $taskFileAcl = [System.Security.AccessControl.FileSecurity]::new()
    $taskFileAcl.SetAccessRuleProtection($true, $false)
    $taskFileAcl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($taskIdentity, 'FullControl', 'Allow'))
    Set-Acl -LiteralPath $taskPath -AclObject $taskFileAcl
    Write-Host 'DeepSeek key saved locally with a user-only ACL. No API request sent.'
} finally {
    $taskPlain = $null
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPointer)
    $taskSecret.Dispose()
}
