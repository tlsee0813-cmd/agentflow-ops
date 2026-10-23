#!/usr/bin/env node
// Read-only Oracle prerequisites. Never opens Chrome, probes CDP, or sends a prompt.
import { readFile, access, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('../', import.meta.url));
const args = process.argv.slice(2);
if (args.includes('--help')) {
  console.log('Usage: node scripts/pro-doctor.mjs [--json] [--dry-run]\n' +
    'Checks local installation/configuration only; does not inspect browser profiles or sessions.\n' +
    '--dry-run additionally validates requests/pro-review.json through Oracle MCP, forcing dryRun=true.\n' +
    'Exit 0: requested local checks passed; 1: configuration/check failed. Login/completion require actual session evidence.');
  process.exit(0);
}
if (args.some((arg) => !['--json', '--dry-run'].includes(arg))) {
  console.error('Unknown option. Use --help.');
  process.exit(1);
}
const checks = [];
const check = (name, ok, detail) => checks.push({ name, status: ok ? 'pass' : 'fail', detail });
const readJson = async (relative) => JSON.parse(await readFile(path.join(root, relative), 'utf8'));
const exists = async (file) => access(file).then(() => true, () => false);
const isFile = async (file) => stat(file).then((info) => info.isFile(), () => false);
const report = {
  channel: 'oracle',
  liveReady: null,
  liveAssessment: 'not-assessed; use actual Oracle session results',
  checks,
  browser: { inspected: false, connectionAttempted: false },
  commands: {
    diagnose: 'node scripts/pro-doctor.mjs --json --dry-run',
    renderForCua: 'pnpm exec oracle --engine browser --model gpt-6-pro --render-plain --render -p "YOUR_WORK_ORDER" --file prompts/WORK_ORDER.md',
    listSessions: 'pnpm exec oracle status --hours 72 --limit 20',
    inspectSession: 'pnpm exec mcporter call oracle.sessions id=ACTUAL_SESSION_ID detail=true --output json --config config/mcporter.json',
    wait: 'pnpm exec mcporter call oracle.wait id=ACTUAL_SESSION_ID timeoutMs=60000 --timeout 75000 --output json --config config/mcporter.json',
    harvest: 'pnpm exec oracle session ACTUAL_SESSION_ID --harvest',
  },
  notes: [
    'Render produces a local context bundle for the existing CUA browser workflow. It does not submit a question.',
    'Use the actual sessionId recorded by the native Oracle CLI; wait timeout does not authorize resubmission.',
    'Session detail can contain private prompts/answers. Keep raw output local.',
    'Harvest may reconnect to the same signed-in Oracle browser. It is recovery, not a new question.',
    'This diagnostic does not determine login success or answer completion; use the actual Oracle session result.',
    'Submit uses the native Oracle foreground CLI with its parent kept alive. Status/result use MCP read-only tools; no daemon is required.',
    'Installed Oracle doctor diagnoses API providers; it does not certify this browser connection.',
  ],
};

try {
  check('node', Number(process.versions.node.split('.')[0]) >= 24, process.versions.node);
  const packageInfo = await readJson('package.json');
  for (const name of ['@steipete/oracle', 'mcporter']) {
    const installed = await readJson(`node_modules/${name}/package.json`);
    check(name, installed.version === packageInfo.dependencies[name], installed.version);
  }
  const oracle = await readJson('.oracle/config.json');
  const browser = oracle.browser ?? {};
  check('project-oracle-config', oracle.engine === 'browser' && oracle.model === 'gpt-6-pro' &&
    browser.attachRunning === false && browser.manualLogin === true && browser.cookieSync === false &&
    browser.archiveConversations === 'never', {
    engine: oracle.engine, model: oracle.model, attachRunning: browser.attachRunning,
    manualLogin: browser.manualLogin, cookieSync: browser.cookieSync,
    archiveConversations: browser.archiveConversations,
  });
  const configuredProfile = browser.manualLoginProfileDir;
  const mcpPath = path.join(root, 'config/mcporter.json');
  const mcp = await readJson('config/mcporter.json');
  const server = mcp.mcpServers?.oracle;
  const serverCwd = server ? path.resolve(path.dirname(mcpPath), server.cwd ?? '.') : '';
  const entry = server?.args?.[0];
  check('oracle-mcp-config', server?.command === 'node' && serverCwd === path.resolve(root) &&
    entry === 'node_modules/@steipete/oracle/dist/bin/oracle-mcp.js' &&
    await exists(path.join(serverCwd, entry ?? 'missing')), {
    repositoryCwd: serverCwd === path.resolve(root), entrypointExists: !!entry && await exists(path.join(serverCwd, entry)),
    oracleOnly: Object.keys(mcp.mcpServers ?? {}).every((name) => name === 'oracle'),
  });
  // Oracle 0.22 sanitizes project configuration: manualLoginProfileDir is NOT
  // allowed there. Use its supported process/server env or an explicit CLI flag.
  const effectiveMcpProfile = server?.env?.ORACLE_BROWSER_PROFILE_DIR ?? process.env.ORACLE_BROWSER_PROFILE_DIR;
  const expectedProfile = configuredProfile || '.ops/oracle-browser-profile';
  const profileMatches = typeof effectiveMcpProfile === 'string' && effectiveMcpProfile.trim().length > 0 &&
    path.resolve(serverCwd, effectiveMcpProfile) === path.resolve(root, expectedProfile);
  check('persistent-manual-login-profile', profileMatches, {
    projectProfileKeyIgnoredByOracle022: Boolean(configuredProfile),
    mcpEnvironmentProfilePresent: Boolean(effectiveMcpProfile),
    matchesRequestedProjectProfile: Boolean(profileMatches),
    note: 'Oracle 0.22 ignores project browser.manualLoginProfileDir. Set oracle MCP server env.ORACLE_BROWSER_PROFILE_DIR to the first-login profile, or use that env/explicit profile flag with CLI. Relative values resolve against process cwd.',
  });
  const chromeBinary = server?.env?.CHROME_PATH ?? process.env.CHROME_PATH;
  check('mcp-explicit-chrome-binary', typeof chromeBinary === 'string' && chromeBinary.trim().length > 0 &&
    await isFile(path.resolve(serverCwd, chromeBinary)), {
    environmentConfigured: Boolean(chromeBinary),
    note: 'MCP preflight lacks the direct CLI Windows binary fallback. Set server env.CHROME_PATH to the installed Chrome executable. Only regular-file metadata is checked; Chrome is not launched.',
  });
  const overrides = ['ORACLE_ENGINE', 'ORACLE_MODEL', 'ORACLE_BROWSER_PROFILE_DIR', 'ORACLE_REMOTE_CHROME']
    .filter((name) => Boolean(process.env[name]));
  report.environmentOverridesPresent = overrides; // Names only; no keys, cookies, paths or values.

  if (args.includes('--dry-run')) {
    const request = await readJson('requests/pro-review.json');
    const result = spawnSync(process.execPath, [
      path.join(root, 'node_modules/mcporter/dist/cli.js'), 'call', 'oracle.consult',
      '--args', '-', '--output', 'json', '--config', mcpPath, '--timeout', '60000',
    ], {
      cwd: root, input: JSON.stringify({ ...request, dryRun: true }), encoding: 'utf8',
      windowsHide: true, timeout: 75000, maxBuffer: 2 * 1024 * 1024,
    });
    // Raw MCP output may include prompts or profile paths; keep only the outcome.
    let parsed;
    try { parsed = JSON.parse(result.stdout); } catch { /* handled below */ }
    const dryRunOk = result.status === 0 && parsed && !parsed.isError &&
      !parsed.error && (parsed.structuredContent?.dryRun === true || parsed.dryRun === true);
    check('native-mcp-dry-run', Boolean(dryRunOk), dryRunOk ? 'Oracle accepted dryRun=true; no browser or model contacted.' :
      'Native MCP dry-run failed or returned an unrecognized result. Inspect the native dry-run locally.');
    if (dryRunOk) {
      const returnedProfile = (parsed.resolved ?? parsed.structuredContent?.resolved)?.browser?.profileDir;
      check('native-mcp-profile-reuse', typeof returnedProfile === 'string' && typeof effectiveMcpProfile === 'string' &&
        path.resolve(serverCwd, returnedProfile) === path.resolve(serverCwd, effectiveMcpProfile),
      'Compares native dry-run resolved.browser.profileDir with the configured MCP profile; does not inspect profile contents.');
    }
  }
} catch (error) {
  check('configuration-readable', false, error.code ?? 'Invalid local JSON/configuration');
}

const failed = checks.some((item) => item.status === 'fail');
report.nextAction = failed ? 'Fix the reported local configuration issue while preserving the signed-in Oracle profile.' :
  'Reuse the configured Oracle manual-login profile. For pending work use the actual existing sessionId and native wait/harvest; determine success from that session result.';
report.exitCode = failed ? 1 : 0;
if (args.includes('--json')) {
  console.log(JSON.stringify(report, null, 2));
} else {
  for (const item of checks) console.log(`${item.status.toUpperCase()} ${item.name}: ${typeof item.detail === 'string' ? item.detail : JSON.stringify(item.detail)}`);
  console.log(`LIVE NOT ASSESSED: ${report.liveAssessment}\n${report.nextAction}`);
  for (const [name, command] of Object.entries(report.commands)) console.log(`${name}: ${command}`);
  console.log('Exit 0 means local checks passed. Login and completion are determined by actual Oracle session results.');
}
process.exitCode = report.exitCode;
