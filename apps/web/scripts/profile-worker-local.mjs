import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import WebSocket from "ws";
import {
  outputFile,
  checkGeneratedConfig,
  probeCases,
  validateResponse,
  canonicalizeRsc,
  distribution,
  summarizeProfile,
  sourceLocator,
  localOrigin,
} from "./worker-cpu-lib.mjs";
const require = createRequire(import.meta.url);
const wrangler = resolve(
  dirname(require.resolve("wrangler/package.json")),
  "bin/wrangler.js",
);
const label = process.argv[2] ?? "baseline";
outputFile(label, "local.json");
checkGeneratedConfig();
const locate = sourceLocator();
const origin = localOrigin;
const cases = probeCases("/_next/static/probe.js");
const all = [];
// Do not attach accidentally to another task's inspector.
try {
  await fetch("http://127.0.0.1:9229/json/list", {
    signal: AbortSignal.timeout(1000),
  });
  throw new Error("Stop the existing local preview before profiling.");
} catch (error) {
  if (error.message === "Stop the existing local preview before profiling.")
    throw error;
}
for (let isolate = 0; isolate < 3; isolate++) {
  const child = spawn(
    process.execPath,
    [
      wrangler,
      "dev",
      "--config",
      "dist/server/wrangler.json",
      "--local",
      "--port",
      "8796",
      "--inspector-port",
      "9229",
      "--log-level",
      "none",
    ],
    {
      stdio: "ignore",
      env: { ...process.env, WRANGLER_SEND_METRICS: "false" },
    },
  );
  let ws;
  try {
    let targets;
    for (let attempt = 0; attempt < 150; attempt++) {
      assert(child.exitCode === null, "Preview exited");
      try {
        targets = await (await fetch("http://127.0.0.1:9229/json/list")).json();
        if (targets[0]?.webSocketDebuggerUrl) break;
      } catch {}
      await new Promise((r) => setTimeout(r, 200));
    }
    assert(targets?.[0], "Inspector not ready");
    ws = new WebSocket(targets[0].webSocketDebuggerUrl);
    await new Promise((r, j) => {
      ws.on("open", r);
      ws.on("error", j);
    });
    let seq = 0;
    const pending = new Map();
    ws.on("message", (data) => {
      const m = JSON.parse(data);
      const p = pending.get(m.id);
      if (p) {
        pending.delete(m.id);
        m.error
          ? p.reject(new Error("CDP operation failed"))
          : p.resolve(m.result);
      }
    });
    const cdp = (method, params = {}) =>
      new Promise((resolve, reject) => {
        const id = ++seq;
        const timeout = setTimeout(() => {
          pending.delete(id);
          reject(new Error(`CDP ${method} timed out`));
        }, 30000);
        pending.set(id, {
          resolve: (value) => {
            clearTimeout(timeout);
            resolve(value);
          },
          reject: (error) => {
            clearTimeout(timeout);
            reject(error);
          },
        });
        ws.send(JSON.stringify({ id, method, params }));
      });
    await cdp("Profiler.enable");
    await cdp("Profiler.setSamplingInterval", { interval: 100 });
    async function sample(spec, phase) {
      await cdp("Profiler.start");
      let error = false,
        status,
        bytes,
        body;
      try {
        const response = await fetch(origin + spec.path, {
          headers: spec.headers,
          redirect: "manual",
          signal: AbortSignal.timeout(30000),
        });
        status = response.status;
        body = await response.text();
        bytes = body.length;
        validateResponse(spec, response, body);
      } catch {
        error = true;
      }
      const { profile } = await cdp("Profiler.stop");
      const row = {
        isolate,
        name: spec.name,
        phase,
        status,
        bytes,
        error,
        ...summarizeProfile(profile, locate),
      };
      all.push(row);
      if (phase === "first" || all.length % 30 === 0)
        console.log(
          JSON.stringify({
            name: row.name,
            phase: row.phase,
            isolate,
            error,
            activeMs: row.activeMs,
          }),
        );
      if (
        phase === "first" ||
        (phase === "warm" &&
          all.filter((r) => r.name === spec.name && r.phase === "warm")
            .length === 1)
      )
        writeFileSync(
          outputFile(label, `${isolate}-${spec.name}-${phase}.cpuprofile`),
          JSON.stringify(profile),
        );
      return body;
    }
    const first = cases[[0, 1, 3][isolate]];
    const html = await sample(first, "first");
    if (isolate === 0) {
      const asset = html.match(
        /(?:src|href)="(\/_next\/static\/[^"\s]+)"/,
      )?.[1];
      assert(asset, "No static control asset");
      cases.at(-1).path = probeCases(asset).at(-1).path;
      for (const spec of cases) {
        if (spec.name === "rsc") await canonicalizeRsc(origin, spec);
        await sample(spec, "prime");
        for (let n = 0; n < 30; n++) await sample(spec, "warm");
      }
    } else {
      for (let n = 0; n < 3; n++) await sample(first, "warm-extra");
    }
  } finally {
    ws?.close();
    if (process.platform === "win32")
      spawnSync("taskkill", ["/PID", String(child.pid), "/T", "/F"], {
        stdio: "ignore",
      });
    else child.kill();
    await new Promise((r) => setTimeout(r, 600));
  }
}
writeFileSync(
  outputFile(label, "local.json"),
  JSON.stringify({ label, intervalUs: 100, rows: all }, null, 2),
);
const summary = cases.map((c) => ({
  name: c.name,
  ...distribution(all.filter((r) => r.name === c.name && r.phase === "warm")),
}));
console.log(
  JSON.stringify(
    { label, summary, first: all.filter((r) => r.phase === "first") },
    null,
    2,
  ),
);
if (all.some((r) => r.error)) process.exitCode = 1;
