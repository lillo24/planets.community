// CI-owned loopback transport only. No hosted target, operator endpoint, token
// dump or product success stub. Auth/RPC/Storage/WebSockets reach the two real
// disposable stacks; the broker is the reviewed runtime with fixed origins.
import assert from "node:assert/strict";
import http from "node:http";
import { pipeline } from "node:stream";
import { randomBytes, createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { execFileSync } from "node:child_process";
import { createRuntime } from "../../supabase/functions/mock-personas/runtime.mjs";
import { NORMAL_ORIGIN, MOCK_ORIGIN, GENERATION } from "./target.mjs";
import { PERSONAS } from "./world.mjs";

export async function nativeBridge({ directory, normal, mock, sql, first, normalSentinel }) {
  assert.equal(process.env.GITHUB_ACTIONS, "true");
  assert.equal(process.env.RUNNER_ENVIRONMENT, "github-hosted");
  assert.equal(process.platform, "linux");
  const relative = path.relative(os.tmpdir(), path.resolve(directory));
  assert.ok(relative && !relative.startsWith("..") && !path.isAbsolute(relative));
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const output = path.resolve("mock-native-evidence");
  await mkdir(output, { recursive: true });
  const source = execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  const [dirty] = [execFileSync("git", ["status", "--porcelain", "--untracked-files=no"], { encoding: "utf8" })];
  assert.equal(dirty, "", "Native source must be a committed checkout");
  const email = "normal-sentinel@planets.invalid";
  const accepted = await normalSentinel.client.rpc("accept_policy_bundle", {
    p_expected_account_id: normalSentinel.id, p_bundle_version: "POLICY01-2026-10-08-v1",
  });
  assert.equal(accepted.error, null);
  await sql`insert into mock_control.testers(issuer,user_id) values(${NORMAL_ORIGIN + "/auth/v1"},${normalSentinel.id}::uuid)`;
  const receipts = await sql`select fixture_key,receipt from mock_control.fixtures where fixture_key in ('group:garden','group:workshop','idea:garden')`;
  const receipt = Object.fromEntries(receipts.map((r) => [r.fixture_key, r.receipt]));
  const [chat] = await sql`select id from public.project_group_chats where project_id=${first.project}::uuid`;
  assert.ok(chat?.id);
  const defines = {
    APP_ENV: "local", ENABLE_DEMO_TOOLS: "false", ENABLE_CLOSED_TEST_MOCK: "true",
    SUPABASE_URL: "http://127.0.0.1:57421", SUPABASE_PUBLISHABLE_KEY: normal.publishableKey,
    MOCK_SUPABASE_URL: "http://127.0.0.1:57422", MOCK_SUPABASE_PUBLISHABLE_KEY: mock.publishableKey,
    MOCK_PERSONA_BROKER_URL: "http://127.0.0.1:57422/functions/v1/mock-personas", MOCK_FIXTURE_GENERATION: GENERATION,
    MOCK_QA_CONTROL_ID: normalSentinel.id, MOCK_QA_PROJECT: first.project,
    MOCK_QA_TAVOLO: first.tavolo, MOCK_QA_CHAT: chat.id,
    MOCK_QA_GARDEN: receipt["group:garden"], MOCK_QA_WORKSHOP: receipt["group:workshop"],
  };
  assert.ok(Object.values(defines).every((v) => typeof v === "string" && v.length));
  assert.ok(Object.keys(defines).every((k) => !/token|password|secret/i.test(k)));
  const sentinels = [normal.serviceRoleKey, mock.serviceRoleKey];
  // Private scanner input never becomes an artifact or a Dart define.
  await writeFile(path.join(directory, "scan-secrets.json"), JSON.stringify(sentinels), { mode: 0o600 });
  let stage = "first", mode = "normal", completed = false;
  const calls = [], screenshots = [], steps = [];
  const sockets = new Set(), servers = [];
  let resolveDone, rejectDone;
  const done = new Promise((resolve, reject) => { resolveDone = resolve; rejectDone = reject; });
  const cancelled = () => rejectDone(new Error("Owned native run interrupted"));
  process.once("SIGTERM", cancelled);
  const timer = setTimeout(() => rejectDone(new Error("Native journey deadline exceeded")), 18 * 60_000);
  const handler = createRuntime({ enabled: true, normalOrigin: NORMAL_ORIGIN, mockOrigin: MOCK_ORIGIN,
    normalKey: normal.publishableKey, service: mock.serviceRoleKey, deliveryKey: randomBytes(32).toString("base64"),
    fetcher: (url, init) => {
      const u = new URL(url);
      if (u.origin === NORMAL_ORIGIN) {
        assert.equal(u.pathname, "/auth/v1/user");
        return fetch(url.replace(NORMAL_ORIGIN, normal.apiUrl), init);
      }
      assert.equal(u.origin, MOCK_ORIGIN);
      return fetch(url.replace(MOCK_ORIGIN, mock.apiUrl), init);
    },
  });
  async function body(req, max = 65536) {
    const chunks = []; let size = 0;
    for await (const chunk of req) { size += chunk.length; assert.ok(size <= max); chunks.push(chunk); }
    return Buffer.concat(chunks);
  }
  function json(res, value, status = 200) {
    res.writeHead(status, { "content-type": "application/json", "cache-control": "no-store" });
    res.end(JSON.stringify(value));
  }
  function watch(server) {
    servers.push(server);
    server.on("connection", (socket) => { sockets.add(socket); socket.on("close", () => sockets.delete(socket)); });
  }
  async function listen(server, port) {
    watch(server); await new Promise((resolve, reject) => { server.once("error", reject); server.listen(port, "127.0.0.1", resolve); });
  }
  async function proxy(realm, endpoint, port) {
    const target = new URL(endpoint);
    assert.ok(["127.0.0.1", "localhost"].includes(target.hostname));
    const server = http.createServer(async (req, res) => {
      const url = new URL(req.url, `http://127.0.0.1:${port}`);
      if (realm === "mock" && url.pathname === "/functions/v1/mock-personas") {
        try {
          const response = await handler(new Request(url, { method: req.method, headers: req.headers, body: await body(req) }));
          res.writeHead(response.status, Object.fromEntries(response.headers)); res.end(Buffer.from(await response.arrayBuffer()));
        } catch { json(res, { error: "unavailable" }, 503); }
        return;
      }
      const family = url.pathname.split("/").slice(0, 3).join("/");
      const maintenance = (req.method === "GET" && url.pathname === "/auth/v1/user") ||
        (req.method === "POST" && url.pathname === "/auth/v1/token" && url.searchParams.get("grant_type") === "refresh_token") ||
        (req.method === "POST" && url.pathname === "/auth/v1/logout");
      const operation = url.pathname.startsWith("/rest/v1/rpc/") ? url.pathname.slice(13) : null;
      const record = { realm, mode, method: req.method, family, operation, maintenance, status: null };
      calls.push(record); assert.ok(calls.length < 5000);
      const upstream = http.request(new URL(req.url, target), {
        method: req.method, headers: { ...req.headers, host: target.host },
      }, (response) => {
        record.status = response.statusCode; res.writeHead(response.statusCode, response.headers); pipeline(response, res, () => {});
      });
      upstream.on("error", () => { if (!res.headersSent) json(res, { error: "upstream_unavailable" }, 502); else res.destroy(); });
      pipeline(req, upstream, () => {});
    });
    server.on("upgrade", (req, socket, head) => {
      const upstream = http.request(new URL(req.url, target), { headers: { ...req.headers, host: target.host } });
      upstream.on("upgrade", (response, remote, remoteHead) => {
        sockets.add(remote); remote.on("close", () => sockets.delete(remote));
        socket.write(`HTTP/1.1 101 Switching Protocols\r\n${Object.entries(response.headers).map(([k,v]) => `${k}: ${v}`).join("\r\n")}\r\n\r\n`);
        if (head.length) remote.write(head); if (remoteHead.length) socket.write(remoteHead);
        socket.pipe(remote).pipe(socket);
      });
      upstream.on("error", () => socket.destroy()); upstream.end();
    });
    await listen(server, port);
  }
  try {
    await proxy("normal", normal.apiUrl, 57421); await proxy("mock", mock.apiUrl, 57422);
    await listen(http.createServer(async (req, res) => {
      try {
        const url = new URL(req.url, "http://127.0.0.1:57420");
        if (req.method === "GET" && url.pathname === "/qa/stage") return json(res, { stage });
        if (req.method === "GET" && url.pathname === "/qa/otp") {
          const mailbox = `http://127.0.0.1:55324`;
          const found = await (await fetch(`${mailbox}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=10`)).json();
          for (const message of found.messages ?? []) {
            const full = await (await fetch(`${mailbox}/api/v1/message/${encodeURIComponent(message.ID)}`)).json();
            const code = `${full.Text ?? ""} ${full.HTML ?? ""}`.match(/(?:^|\D)(\d{6})(?:\D|$)/)?.[1];
            if (code) return json(res, { code });
          }
          return json(res, { error: "not_ready" }, 404);
        }
        if (req.method === "POST" && url.pathname === "/qa/mode") {
          const value = JSON.parse(await body(req)); assert.ok(["normal", "mock"].includes(value.mode));
          mode = value.mode; return json(res, { accepted: true });
        }
        if (req.method === "POST" && url.pathname.startsWith("/qa/png/")) {
          const name = url.pathname.substring(8);
          assert.match(name, /^[a-z][a-z0-9-]{3,90}\.png$/); assert.ok(screenshots.length < 32);
          assert.ok(!screenshots.some((s) => s.name === name));
          const bytes = await body(req, 8 * 1024 * 1024);
          assert.equal(bytes.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
          await writeFile(path.join(output, name), bytes);
          screenshots.push({ name, sha256: createHash("sha256").update(bytes).digest("hex") });
          return json(res, { accepted: true });
        }
        if (req.method === "POST" && url.pathname === "/qa/result") {
          const value = JSON.parse(await body(req));
          assert.ok(Array.isArray(value.steps) && value.steps.length < 64);
          assert.ok(value.steps.every((s) => typeof s === "string" && /^[a-z0-9-]{2,70}$/.test(s)));
          if (value.passed !== true) {
            assert.ok(Array.isArray(value.failures) && value.failures.length < 10);
            assert.ok(value.failures.every((s) => typeof s === "string" && /^[a-zA-Z0-9 _-]{2,70}$/.test(s)));
            await writeFile(path.join(directory, "native-failure.json"), JSON.stringify({ stage, steps: value.steps, failures: value.failures }));
          }
          assert.equal(value.passed, true, "Native integration assertions failed");
          assert.equal(value.stage, stage); assert.ok(Array.isArray(value.steps) && value.steps.length < 64);
          assert.ok(value.steps.every((s) => typeof s === "string" && /^[a-z0-9-]{2,70}$/.test(s)));
          steps.push(...value.steps);
          json(res, { accepted: true });
          if (stage === "first") {
            stage = "restart";
            await writeFile(path.join(directory, "native-restart.json"), JSON.stringify({ source, stage }));
          } else { completed = true; resolveDone(); }
          return;
        }
        return json(res, { error: "unknown_qa_path" }, 404);
      } catch {
        json(res, { error: "native_verification_failed" }, 500);
        rejectDone(new Error("Native bridge rejected result or evidence"));
      }
    }), 57420);
    await writeFile(path.join(directory, "native-defines.json"), JSON.stringify(defines), { mode: 0o600 });
    await writeFile(path.join(directory, "native-ready.json"), JSON.stringify({ source }));
    console.log("Native loopback bridge ready; no session tokens compiled into the app.");
    await done; assert.equal(completed, true);
    const forbidden = calls.filter((r) => r.realm === "normal" && r.mode === "mock" && !r.maintenance);
    assert.deepEqual(forbidden, [], "No normal product call while mock is active");
    const messages = await sql`select body,sender_profile_id from public.project_chat_messages where chat_id=${chat.id}::uuid and body in ('Native mock hello from Giulia','Native mock reply from Sara')`;
    assert.equal(messages.length, 2);
    assert.equal(messages.find((m) => m.body.includes("Giulia"))?.sender_profile_id, PERSONAS[0].id);
    assert.equal(messages.find((m) => m.body.includes("Sara"))?.sender_profile_id, PERSONAS[2].id);
    const evidence = { source, mode: "release", signer: "ephemeral-ci-fixture-key", uploadReady: false,
      backend: "two-independent-disposable-local-Supabase-stacks", hostedProof: false,
      personas: 5, schemaGeneration: GENERATION, processRestart: true, success: true,
      screenshots, steps, network: { total: calls.length, normalDuringMock: calls.filter((r) => r.realm === "normal" && r.mode === "mock").length, forbiddenNormalProductCalls: 0, families: [...new Set(calls.map((r) => `${r.realm}:${r.family}`))], operations: [...new Set(calls.filter((r) => r.operation).map((r) => `${r.realm}:${r.operation}`))] } };
    await writeFile(path.join(output, "native-result.json"), JSON.stringify(evidence, null, 2) + "\n");
    await writeFile(path.join(directory, "native-complete.json"), JSON.stringify({ success: true }));
  } finally {
    process.removeListener("SIGTERM", cancelled);
    clearTimeout(timer);
    for (const socket of sockets) socket.destroy();
    await Promise.all(servers.map((s) => new Promise((resolve) => s.close(resolve))));
  }
}
