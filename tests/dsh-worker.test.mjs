import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { credentialPresence, collectResult, validateTask } from '../scripts/dsh-worker.mjs';

test('a final event and exit 0 alone do not make a failed or incomplete turn successful', () => {
  const final = JSON.stringify({ type: 'final', text: 'partial answer' });
  for (const kind of ['error', 'aborted']) {
    const end = JSON.stringify({ type: 'status', phase: 'turn_end', reason: { kind, error: { message: 'private provider diagnostic' } } });
    const result = collectResult(`${end}\n${final}`, 0);
    assert.equal(result.status, 'error');
    assert.equal(result.turnReason, kind);
    assert.ok(!JSON.stringify(result).includes('private provider diagnostic'));
  }
  assert.equal(collectResult(final, 0).status, 'error');
  const completed = JSON.stringify({ type: 'status', phase: 'turn_end', reason: { kind: 'completed' } });
  assert.equal(collectResult(`${completed}\n${final}`, 0).status, 'completed');
  assert.equal(collectResult(`${completed}\n${final}`, 1).status, 'error');
});

test('credential checks expose only presence and honor an empty launch override', async () => {
  const home = await mkdtemp(path.join(os.tmpdir(), 'dsh-presence-'));
  try {
    await writeFile(path.join(home, '.env'), 'DEEPSEEK_API_KEY=""\n');
    assert.equal((await credentialPresence({}, home)).present, false);
    await writeFile(path.join(home, '.env'), 'DEEPSEEK_API_KEY=synthetic-secret-not-a-real-key\n');
    const present = await credentialPresence({}, home);
    assert.equal(present.present, true);
    assert.ok(!JSON.stringify(present).includes('synthetic-secret'));
    assert.equal((await credentialPresence({ DEEPSEEK_API_KEY: '' }, home)).present, false);
  } finally { await rm(home, { recursive: true, force: true }); }
});

test('accept only bounded text work with a purpose and completion criteria', () => {
  const task = { kind: 'classify', purpose: 'Assign narrow work', task: 'Classify supplied text', completionCriteria: 'Return three labels', input: 'a b c' };
  assert.match(validateTask(task), /classify/);
  assert.throws(() => validateTask({ ...task, kind: 'shell' }), /kind/);
  assert.throws(() => validateTask({ ...task, completionCriteria: '' }), /completionCriteria/);
  assert.throws(() => validateTask({ ...task, input: 'a'.repeat(25 * 1024) }), /24 KiB/);
  assert.throws(() => validateTask({ ...task, sessionId: '--other-option' }), /sessionId/);
});
