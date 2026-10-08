// Disposable loopback launcher. No session injection, request or capability logs.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import { readHostingBackend } from "../scripts/local-hosting-backend.mjs";

assert.equal(
  process.env.MODINT01_LOCAL_REHEARSAL,
  "1",
  "Explicit MODINT01_LOCAL_REHEARSAL=1 required.",
);
await readHostingBackend("modint01");
const fixture = JSON.parse(
  await readFile(
    new URL(
      "../../../supabase/.temp/modint01-browser-fixture.json",
      import.meta.url,
    ),
    "utf8",
  ),
);
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
assert.match(fixture.projectId, uuid);
assert.match(fixture.token, /^[A-Za-z0-9_-]{32,512}$/u);
const caseLinks = Object.entries(fixture.cases)
  .map(([kind, id]) => {
    assert.ok(
      [
        "profile",
        "project",
        "resource",
        "self",
        "received",
        "corroboration",
        "counterstatement",
      ].includes(kind),
    );
    assert.match(String(id), uuid);
    return `<li><a href="http://127.0.0.1:3119/admin/cases/${id}">${kind} case</a></li>`;
  })
  .join("");
const next = spawn(
  process.execPath,
  [
    fileURLToPath(
      new URL("../../../node_modules/next/dist/bin/next", import.meta.url),
    ),
    "start",
    "--hostname",
    "127.0.0.1",
    "--port",
    "3119",
  ],
  {
    cwd: fileURLToPath(new URL("../", import.meta.url)),
    env: process.env,
    stdio: "ignore",
    windowsHide: true,
  },
);
const launcher = createServer((request, response) => {
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Referrer-Policy", "no-referrer");
  if (request.headers.host !== "127.0.0.1:3118" || request.method !== "GET") {
    response.writeHead(400);
    response.end("Invalid disposable launcher request.");
  } else if (request.url === "/start") {
    response.writeHead(302, {
      Location: `http://127.0.0.1:3119/join/project/${fixture.token}`,
    });
    response.end();
  } else if (request.url === "/unknown") {
    response.writeHead(302, {
      Location: `http://127.0.0.1:3119/join/project/${"x".repeat(43)}`,
    });
    response.end();
  } else if (request.url === "/") {
    response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    response.end(
      `<main><h1>Disposable MODINT01 browser rehearsal</h1><p>Use normal email/code sign-in. This launcher creates no session or admission.</p><a href="/start">Participant preview</a><br><a href="/unknown">Unknown participant link</a><br><a href="http://127.0.0.1:3119/auth">Normal sign-in</a><ul>${caseLinks}</ul></main>`,
    );
  } else {
    response.writeHead(404);
    response.end("Disposable launcher page unavailable.");
  }
}).listen(3118, "127.0.0.1");
function close() {
  launcher.close();
  next.kill();
}
process.once("SIGINT", close);
process.once("SIGTERM", close);
next.once("error", () => {
  close();
  process.exitCode = 1;
});
launcher.once("error", () => {
  close();
  process.exitCode = 1;
});
next.once("exit", (code) => {
  close();
  if (code && code !== 0) process.exitCode = 1;
});
console.log(
  "MODINT01 loopback launcher 3118 and matching production Next 3119 started; request logging disabled.",
);
