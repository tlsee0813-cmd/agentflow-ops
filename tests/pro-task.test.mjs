// node --test tests/pro-task.test.mjs
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";
import { EXIT, main, runChild } from "../scripts/pro-task.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SCRIPT = path.join(ROOT, "scripts", "pro-task.mjs");
const TMP = mkdtempSync(path.join(tmpdir(), "pro task 한글 "));
after(() => rmSync(TMP, { recursive: true, force: true }));

const LONG_LOG = `HEAD-MARKER\n${"x".repeat(9000)}\nTAIL-MARKER\n`;

function fake(responses) {
  const calls = [];
  const out = [];
  const err = [];
  const deps = {
    env: {},
    cwd: TMP,
    stdout: (text) => out.push(text),
    stderr: (text) => err.push(text),
    readFile: async (file) => readFileSync(file, "utf8"),
    run: async (command, args, input, options) => {
      calls.push({ command, args, input: input ? JSON.parse(input) : input, options });
      const next = responses.shift() ?? { code: 1, stdout: "", stderr: "unexpected call" };
      return { stderr: "", ...next, stdout: typeof next.json === "undefined" ? (next.stdout ?? "") : JSON.stringify(next.json) };
    },
  };
  return { deps, calls, out, err };
}

function request(name, body) {
  const file = path.join(TMP, name);
  writeFileSync(file, body);
  return file;
}

const tool = (call) => call.args[call.args.indexOf("call") + 1];

test("submit uses one foreground native CLI and streams progress", async () => {
  const file = request("요청 파일.json", JSON.stringify({ prompt: "검토", model: "gpt-6-pro", files: ["한글 file.md"], browserKeepBrowser: true }));
  const f = fake([]);
  f.deps.run = async (command, args, input, options) => {
    f.calls.push({ command, args, input, options });
    options.stdout("Session: real-id\n");
    options.stderr("progress\n");
    assert.equal(f.out[0], "Session: real-id\n");
    return { code: 0 };
  };
  assert.equal(await main(["submit", file], f.deps), EXIT.ok);
  assert.equal(f.calls.length, 1);
  const call = f.calls[0];
  assert.equal(call.command, process.execPath);
  assert.equal(call.options.env.ORACLE_NO_DETACH, "1");
  assert.equal(call.input, "");
  assert.deepEqual(call.args.slice(1), ["--engine", "browser", "--wait", "--prompt", "검토", "--model", "gpt-6-pro", "--browser-manual-login-profile-dir", path.join(ROOT, ".ops", "oracle-browser-profile"), "--file", "한글 file.md", "--browser-keep-browser"]);
});

test("submit fails once without retry and validates unsupported fields before calling", async () => {
  const file = request("req.json", JSON.stringify({ prompt: "p" }));
  const f = fake([{ code: 9, stderr: "timeout" }]);
  assert.equal(await main(["submit", file], f.deps), EXIT.failure);
  assert.equal(f.calls.length, 1);
  assert.match(f.err.join("\n"), /do not resend/);
  for (const extra of [{ waitForCompletion: false }, { engine: "api" }, { unknown: true }, { files: [3] }, { browserKeepBrowser: "yes" }]) {
    const invalid = fake([]);
    const bad = request("bad.json", JSON.stringify({ prompt: "p", ...extra }));
    assert.equal(await main(["submit", bad], invalid.deps), EXIT.usage);
    assert.equal(invalid.calls.length, 0);
  }
});

test("submit dry-run maps directly to native preview", async () => {
  const file = request("dry.json", JSON.stringify({ prompt: "p" }));
  const f = fake([{ code: 0 }]);
  assert.equal(await main(["submit", file, "--dry-run"], f.deps), EXIT.ok);
  assert.ok(f.calls[0].args.includes("--dry-run"));
  const blocked = fake([]);
  assert.equal(await main(["submit", path.join(TMP, "missing.json")], blocked.deps), EXIT.usage);
  assert.equal(blocked.calls.length, 0);
});

test("status reads sessions metadata only and maps terminal states to distinct exits", async () => {
  const cases = { completed: EXIT.ok, running: EXIT.running, partial: EXIT.partial, error: EXIT.error, cancelled: EXIT.cancelled, odd: EXIT.unknown };
  for (const [state, code] of Object.entries(cases)) {
    const f = fake([{ code: 0, json: { entries: [{ id: "s 1", status: state, createdAt: "t" }], total: 1 } }]);
    assert.equal(await main(["status", "s 1"], f.deps), code, state);
    assert.equal(tool(f.calls[0]), "oracle.sessions");
    assert.deepEqual(f.calls[0].input, { id: "s 1" });
    assert.equal(JSON.parse(f.out[0]).status, state);
  }
  const missing = fake([{ code: 1, json: { content: [{ type: "text", text: 'Session "x" not found.' }], isError: true } }]);
  assert.equal(await main(["status", "x"], missing.deps), EXIT.failure);
  assert.match(missing.err[0], /not found/);
});

test("result prints the whole stored log, not a 4,000-char tail, and keeps partial non-zero", async () => {
  for (const [state, code] of [["completed", EXIT.ok], ["partial", EXIT.partial], ["error", EXIT.error], ["cancelled", EXIT.cancelled]]) {
    const f = fake([{ code: 0, json: { session: { metadata: { id: "s", status: state }, log: LONG_LOG } } }]);
    assert.equal(await main(["result", "s"], f.deps), code, state);
    assert.deepEqual(f.calls.map((call) => [tool(call), call.input]), [["oracle.sessions", { id: "s", detail: true }]]);
    assert.equal(f.out.join(""), LONG_LOG);
    assert.equal(JSON.parse(f.err[0]).status, state);
  }
  const running = fake([{ code: 0, json: { session: { metadata: { id: "s", status: "running" }, log: "partial text" } } }]);
  assert.equal(await main(["result", "s"], running.deps), EXIT.running);
  assert.deepEqual(running.out, []);
});

test("status/result never call consult and reject option-like ids", async () => {
  const f = fake([]);
  assert.equal(await main(["status", "--restart"], f.deps), EXIT.usage);
  assert.equal(await main(["result"], f.deps), EXIT.usage);
  assert.equal(await main(["bogus"], f.deps), EXIT.usage);
  assert.equal(f.calls.length, 0);
});

// End-to-end through a real child process with a fake mcporter in a path with spaces and Hangul.
const fakeDir = path.join(TMP, "가짜 mcporter");
mkdirSync(fakeDir);
const fakeCli = path.join(fakeDir, "cli 가짜.mjs");
writeFileSync(
  fakeCli,
  `import { appendFileSync } from "node:fs";
let input = "";
process.stdin.on("data", (c) => (input += c)).on("end", () => {
  appendFileSync(process.env.FAKE_LOG, JSON.stringify({ argv: process.argv.slice(2), input }) + "\\n");
  process.stdout.write(process.env.FAKE_STDOUT ?? "");
  process.stderr.write(process.env.FAKE_STDERR ?? "");
  setTimeout(() => process.exit(Number(process.env.FAKE_EXIT ?? 0)), Number(process.env.FAKE_DELAY ?? 0));
});
`,
);

function runScript(args, fakeEnv) {
  const log = path.join(TMP, `calls-${Math.random().toString(36).slice(2)}.ndjson`);
  const res = spawnSync(process.execPath, [SCRIPT, ...args], {
    cwd: TMP,
    encoding: "utf8",
    env: { ...process.env, PRO_TASK_MCPORTER: fakeCli, PRO_TASK_ORACLE: fakeCli, FAKE_LOG: log, ...fakeEnv },
  });
  const calls = existsSync(log) ? readFileSync(log, "utf8").trim().split("\n").map((line) => JSON.parse(line)) : [];
  return { ...res, calls };
}

test("child process: argv survives spaces/Hangul and child exit codes reach our exit code", () => {
  const file = request("실제 요청 파일.json", JSON.stringify({ prompt: "공백 있는 질문 \"따옴표\" & | ;" }));
  const ok = runScript(["submit", file], { FAKE_STDOUT: JSON.stringify({ sessionId: "id-ok", status: "running" }) });
  assert.equal(ok.status, EXIT.ok, ok.stderr);
  assert.equal(ok.calls.length, 1);
  assert.equal(ok.calls[0].argv[0], "--engine");
  assert.equal(ok.calls[0].argv[1], "browser");
  assert.equal(ok.calls[0].argv[ok.calls[0].argv.indexOf("--prompt") + 1], "공백 있는 질문 \"따옴표\" & | ;");
  assert.equal(JSON.parse(ok.stdout).sessionId, "id-ok");

  const failed = runScript(["submit", file], { FAKE_EXIT: "9", FAKE_STDERR: "boom" });
  assert.equal(failed.status, EXIT.failure);
  assert.equal(failed.calls.length, 1);
  assert.match(failed.stderr, /boom/);
  assert.match(failed.stderr, /exit 9/);

  const partial = runScript(["result", "id 한글"], {
    FAKE_STDOUT: JSON.stringify({ session: { metadata: { id: "id 한글", status: "partial" }, log: LONG_LOG } }),
  });
  assert.equal(partial.status, EXIT.partial);
  assert.equal(partial.stdout, `${LONG_LOG}`);
  assert.equal(JSON.parse(partial.calls[0].input).id, "id 한글");

  for (const log of ["no trailing newline", ""]) {
    const exact = runScript(["result", "id-exact"], {
      FAKE_STDOUT: JSON.stringify({ session: { metadata: { id: "id-exact", status: "completed" }, log } }),
    });
    assert.equal(exact.status, EXIT.ok, exact.stderr);
    assert.equal(exact.stdout, log);
  }
});

test("real child streams output before it exits", async () => {
  let output;
  let finished = false;
  const firstChunk = new Promise((resolve) => { output = resolve; });
  const run = runChild(process.execPath, [fakeCli], "", {
    env: { ...process.env, FAKE_LOG: path.join(TMP, "stream.ndjson"), FAKE_STDOUT: "진행 중", FAKE_DELAY: "500" },
    stdout: (chunk) => output(chunk),
  }).then((res) => { finished = true; return res; });
  assert.equal(await firstChunk, "진행 중");
  assert.equal(finished, false);
  assert.equal((await run).code, 0);
});

// Native fixture: real mcporter + installed Oracle reading a stored session; no network or login.
const installed = existsSync(path.join(ROOT, "node_modules", "mcporter", "dist", "cli.js")) &&
  existsSync(path.join(ROOT, "node_modules", "@steipete", "oracle", "dist", "bin", "oracle-mcp.js"));

test("native Oracle sessions fixture: full log and partial exit", { skip: !installed && "node_modules not installed" }, () => {
  const home = path.join(TMP, "oracle 홈");
  const dir = path.join(home, "sessions", "fixture-partial");
  mkdirSync(dir, { recursive: true });
  writeFileSync(path.join(dir, "meta.json"), JSON.stringify({ id: "fixture-partial", createdAt: "2026-10-23T00:00:00.000Z", status: "partial", model: "gpt-6-pro", mode: "browser" }));
  writeFileSync(path.join(dir, "output.log"), LONG_LOG);
  const env = { ...process.env, ORACLE_HOME_DIR: home };
  delete env.PRO_TASK_MCPORTER;
  const run = (args) => spawnSync(process.execPath, [SCRIPT, ...args], { cwd: TMP, encoding: "utf8", env });

  const status = run(["status", "fixture-partial"]);
  assert.equal(status.status, EXIT.partial, status.stderr);
  assert.equal(JSON.parse(status.stdout).status, "partial");

  const result = run(["result", "fixture-partial"]);
  assert.equal(result.status, EXIT.partial, result.stderr);
  assert.equal(result.stdout, LONG_LOG);

  const missing = run(["status", "no-such-session"]);
  assert.equal(missing.status, EXIT.failure);

  const dryFile = request("native-dry.json", JSON.stringify({ prompt: "Review assembly choices", files: ["docs/DESIGN_KO.md"] }));
  const dry = run(["submit", dryFile, "--dry-run"]);
  assert.equal(dry.status, EXIT.ok, dry.stderr);
  assert.match(dry.stdout, /\[preview\]/i);
  assert.deepEqual(readdirSync(path.join(home, "sessions")), ["fixture-partial"]);
});
