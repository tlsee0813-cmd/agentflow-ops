$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$runtimeRoot = Join-Path $taskRoot '.ops/dsh-runtime'
New-Item -ItemType Directory -Force $runtimeRoot | Out-Null
$manifestPath = Join-Path $runtimeRoot 'package.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    '{"name":"agentflow-dsh-local","private":true,"type":"module"}' | Set-Content -LiteralPath $manifestPath -Encoding utf8
}
# --ignore-workspace prevents pnpm from changing the parent project's lockfile.
if (Test-Path (Join-Path $runtimeRoot 'pnpm-lock.yaml')) {
    & pnpm --dir $runtimeRoot --ignore-workspace install --frozen-lockfile --ignore-scripts
} else {
    & pnpm --dir $runtimeRoot --ignore-workspace add --save-exact --ignore-scripts '@deepseek-ai/dsh@0.2.1-rc.2'
}
if ($LASTEXITCODE -ne 0) { throw 'DSH install failed; no model request was sent.' }
& node (Join-Path $PSScriptRoot 'dsh-worker.mjs') doctor
exit $LASTEXITCODE
