import { mkdir, readFile, writeFile, access } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

// Install only this named skill; never modify global config, AGENTS or credentials.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const target = join(process.env.CODEX_HOME || join(homedir(), '.codex'), 'skills', 'agentflow-coordinator');
const marker = 'agentflow-ops/coordinator-skill-v1';
await access(join(root, 'scripts', 'pro-task.mjs'));
await access(join(root, 'docs', 'STATUS.md'));
let exists = false;
try { await access(target); exists = true; } catch (error) { if (error.code !== 'ENOENT') throw error; }
if (exists) {
  let previous;
  try { previous = JSON.parse(await readFile(join(target, 'runtime.json'), 'utf8')); }
  catch { throw new Error('Existing skill has no AgentFlow installer marker; refusing to overwrite.'); }
  if (previous.installedBy !== marker || resolve(previous.opsRoot) !== root) {
    throw new Error('Existing skill belongs to another installation; refusing to replace its runtime.');
  }
}
const source = await readFile(join(root, 'skills', 'agentflow-coordinator', 'SKILL.md'), 'utf8');
await mkdir(target, { recursive: true });
await writeFile(join(target, 'SKILL.md'), source, 'utf8');
await writeFile(join(target, 'runtime.json'), JSON.stringify({ installedBy: marker, opsRoot: root, nodePath: process.execPath }, null, 2) + '\n', 'utf8');
console.log(JSON.stringify({ installed: true, skill: 'agentflow-coordinator', path: target, opsRoot: root }));
