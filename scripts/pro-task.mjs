#!/usr/bin/env node
// Thin glue over installed Oracle 0.22.0 MCP tools via mcporter 0.16.0.
// submit -> oracle.consult (waitForCompletion:false), status -> oracle.sessions {id},
// result -> oracle.sessions {id, detail:true} (full stored log, not wait's 4,000-char tail).
// Each invocation makes exactly one child call and never retries, so a failed or slow
// submit is never resent; status/result never send a prompt or restart a session.
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export const EXIT = {
  ok: 0,
  failure: 1,
  usage: 2,
  running: 3,
  partial: 4,
  error: 5,
  cancelled: 6,
  unknown: 7,
};

const STATUS_EXIT = {
  completed: EXIT.ok,
  pending: EXIT.running,
  queued: EXIT.running,
  running: EXIT.running,
  partial: EXIT.partial,
  error: EXIT.error,
  failed: EXIT.error,
  cancelled: EXIT.cancelled,
};

const USAGE = `usage:
  node scripts/pro-task.mjs submit REQUEST.json [--dry-run]
  node scripts/pro-task.mjs status SESSION_ID
  node scripts/pro-task.mjs result SESSION_ID
exit: 0 completed/accepted, 3 running, 4 partial, 5 error, 6 cancelled, 7 unknown, 1 call failed, 2 usage`;

export function exitForStatus(status) {
  return STATUS_EXIT[status] ?? EXIT.unknown;
}

export function mcporterCommand(tool, env = process.env) {
  const cli = env.PRO_TASK_MCPORTER || path.join(ROOT, "node_modules", "mcporter", "dist", "cli.js");
  const config = path.join(ROOT, "config", "mcporter.json");
  // Run the package entry with the current node binary: no shell, no .cmd shim, no pnpm.
  return {
    command: process.execPath,
    args: [cli, "call", `oracle.${tool}`, "--args", "-", "--output", "json", "--config", config],
  };
}

export function runChild(command, args, input) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { cwd: ROOT, shell: false, windowsHide: true });
    const out = [];
    const err = [];
    child.stdout.on("data", (chunk) => out.push(chunk));
    child.stderr.on("data", (chunk) => err.push(chunk));
    child.on("error", (error) => resolve({ code: null, stdout: "", stderr: error.message }));
    child.on("close", (code, signal) =>
      resolve({
        code: signal ? null : code,
        stdout: Buffer.concat(out).toString("utf8"),
        stderr: Buffer.concat(err).toString("utf8") || (signal ? `terminated by ${signal}` : ""),
      }),
    );
    child.stdin.on("error", () => {});
    child.stdin.end(input, "utf8");
  });
}

async function callTool(tool, payload, deps) {
  const { command, args } = mcporterCommand(tool, deps.env);
  const res = await deps.run(command, args, JSON.stringify(payload));
  let json;
  try {
    json = JSON.parse(res.stdout);
  } catch {
    json = undefined;
  }
  if (res.code !== 0 || !json || typeof json !== "object" || json.isError) {
    const text = json?.content?.map((part) => part.text).filter(Boolean).join(" ");
    const detail = (text || res.stderr || res.stdout || "no output").trim().split("\n").slice(-3).join(" | ");
    return { ok: false, message: `oracle.${tool} failed (exit ${res.code ?? "signal"}): ${detail}` };
  }
  return { ok: true, json };
}

function validId(id) {
  return typeof id === "string" && id.trim().length > 0 && !id.startsWith("-");
}

async function submit(args, deps) {
  const dryRun = args.includes("--dry-run");
  const rest = args.filter((arg) => arg !== "--dry-run");
  if (rest.length !== 1) return usage(deps);
  let request;
  try {
    const raw = await deps.readFile(path.resolve(deps.cwd, rest[0]), "utf8");
    request = JSON.parse(raw.replace(/^﻿/, ""));
  } catch (error) {
    deps.stderr(`request read failed: ${error.message}`);
    return EXIT.usage;
  }
  if (!request || typeof request !== "object" || Array.isArray(request) || typeof request.prompt !== "string") {
    deps.stderr("request must be a JSON object with a string prompt");
    return EXIT.usage;
  }
  if (request.waitForCompletion === true) {
    deps.stderr("waitForCompletion:true is not allowed; submit returns a sessionId and does not wait");
    return EXIT.usage;
  }
  const payload = { ...request, waitForCompletion: false, ...(dryRun ? { dryRun: true } : {}) };
  const res = await callTool("consult", payload, deps);
  if (!res.ok) {
    deps.stderr(res.message);
    deps.stderr("do not resend; check `node scripts/pro-task.mjs status <id>` or oracle.sessions first");
    return EXIT.failure;
  }
  const { sessionId, status, output } = res.json;
  if (payload.dryRun) {
    deps.stdout(JSON.stringify({ status: status ?? "dry-run", dryRun: true }));
    if (output) deps.stdout(output);
    return status === "dry-run" ? EXIT.ok : EXIT.unknown;
  }
  if (!validId(sessionId)) {
    deps.stderr("consult returned no sessionId; do not resend, inspect oracle.sessions first");
    return EXIT.failure;
  }
  deps.stdout(JSON.stringify({ sessionId, status }));
  return status === "error" || status === "cancelled" ? exitForStatus(status) : EXIT.ok;
}

async function status(args, deps) {
  if (args.length !== 1 || !validId(args[0])) return usage(deps);
  const res = await callTool("sessions", { id: args[0] }, deps);
  if (!res.ok) {
    deps.stderr(res.message);
    return EXIT.failure;
  }
  const entry = res.json.entries?.[0];
  if (!entry?.status) {
    deps.stderr("oracle.sessions returned no status");
    return EXIT.failure;
  }
  deps.stdout(JSON.stringify({ sessionId: entry.id, status: entry.status, model: entry.model, createdAt: entry.createdAt }));
  return exitForStatus(entry.status);
}

async function result(args, deps) {
  if (args.length !== 1 || !validId(args[0])) return usage(deps);
  const res = await callTool("sessions", { id: args[0], detail: true }, deps);
  if (!res.ok) {
    deps.stderr(res.message);
    return EXIT.failure;
  }
  const session = res.json.session;
  const state = session?.metadata?.status;
  if (!state || typeof session.log !== "string") {
    deps.stderr("oracle.sessions detail returned no metadata/log");
    return EXIT.failure;
  }
  const code = exitForStatus(state);
  // Metadata goes to stderr so stdout is exactly the stored session log.
  deps.stderr(JSON.stringify({ sessionId: session.metadata.id ?? args[0], status: state, chars: session.log.length }));
  if (code === EXIT.running) {
    deps.stderr("not finished; no result printed (rerun result later, do not resubmit)");
    return code;
  }
  deps.stdout(session.log);
  return code;
}

function usage(deps) {
  deps.stderr(USAGE);
  return EXIT.usage;
}

export async function main(argv, overrides = {}) {
  const deps = {
    run: runChild,
    readFile,
    env: process.env,
    cwd: process.cwd(),
    stdout: (text) => process.stdout.write(text.endsWith("\n") ? text : `${text}\n`),
    stderr: (text) => process.stderr.write(`${text}\n`),
    ...overrides,
  };
  const [command, ...args] = argv;
  if (command === "submit") return submit(args, deps);
  if (command === "status") return status(args, deps);
  if (command === "result") return result(args, deps);
  return usage(deps);
}

const samePath = (a, b) => (process.platform === "win32" ? a.toLowerCase() === b.toLowerCase() : a === b);
if (process.argv[1] && samePath(path.resolve(process.argv[1]), fileURLToPath(import.meta.url))) {
  process.exitCode = await main(process.argv.slice(2));
}
