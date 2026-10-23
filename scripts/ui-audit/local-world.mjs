// UIAUDIT01 only: two new disposable realms, the canonical Mock seed, and the
// reviewed persona broker. No hosted credentials, existing stack or reset.
import assert from "node:assert/strict";
import { randomBytes, randomUUID, generateKeyPairSync } from "node:crypto";
import { spawnSync } from "node:child_process";
import { cp, mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import postgres from "postgres";
import { createClient } from "@supabase/supabase-js";
import { parseLocalSupabaseStatus } from "../lib/local-supabase-status.mjs";
import {
  migrationInventory,
  MOCK_REF,
  MOCK_ORIGIN,
  GENERATION,
} from "../mock/target.mjs";
import { seed } from "../mock/world.mjs";
import { verify } from "../mock/verify.mjs";
import { createRuntime } from "../../supabase/functions/mock-personas/runtime.mjs";

assert.equal(
  process.env.PLANETS_DISPOSABLE_QA,
  "1",
  "Explicit disposable QA required",
);
const root = process.cwd();
const directory = await mkdtemp(path.join(os.tmpdir(), "planets-uiaudit01-"));
const stacks = [];
const cli = path.join(root, "node_modules/supabase/dist/supabase.js");
async function run(stack, args) {
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: stack.directory,
    env: { ...process.env, ...stack.environment },
    encoding: "utf8",
    shell: false,
    timeout: 900000,
    maxBuffer: 32 * 1024 * 1024,
  });
  await writeFile(
    path.join(stack.directory, `private-${args[0]}.log`),
    `${result.stdout ?? ""}\n${result.stderr ?? ""}`,
  );
  assert.equal(
    result.status,
    0,
    `Owned ${stack.name} ${args[0]} failed; private log: ${stack.directory}`,
  );
  return result.stdout;
}
async function stack(name, offset) {
  const owned = {
    name,
    directory: path.join(directory, name),
    environment: {
      UIAUDIT_PUBLIC: "sb_publishable_" + randomBytes(24).toString("base64url"),
      UIAUDIT_SECRET: "sb_secret_" + randomBytes(32).toString("base64url"),
      UIAUDIT_JWT: randomBytes(48).toString("base64url"),
    },
  };
  await mkdir(path.join(owned.directory, "supabase"), { recursive: true });
  for (const entry of ["migrations", "templates", "seed.sql"])
    await cp(
      path.join(root, "supabase", entry),
      path.join(owned.directory, "supabase", entry),
      { recursive: true },
    );
  let config = await readFile(path.join(root, "supabase/config.toml"), "utf8");
  config = config
    .replace(
      'project_id = "planets-community"',
      `project_id = "uiaudit01-${name}-${path.basename(directory)}"`,
    )
    .replace(/\b543(\d\d)\b/g, (_, port) =>
      String(54300 + Number(port) + offset),
    )
    .replace(
      /(\[auth\]\r?\n)/,
      '$1publishable_key = "env(UIAUDIT_PUBLIC)"\nsecret_key = "env(UIAUDIT_SECRET)"\njwt_secret = "env(UIAUDIT_JWT)"\n',
    )
    .replace(
      '# signing_keys_path = "./signing_keys.json"',
      'signing_keys_path = "./signing_keys.json"',
    );
  if (name === "mock")
    config = config.replaceAll("enable_signup = true", "enable_signup = false");
  const { privateKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  });
  await writeFile(
    path.join(owned.directory, "supabase/signing_keys.json"),
    JSON.stringify([
      {
        ...privateKey.export({ format: "jwk" }),
        kid: randomUUID(),
        alg: "ES256",
        use: "sig",
        key_ops: ["sign", "verify"],
      },
    ]),
  );
  await writeFile(path.join(owned.directory, "supabase/config.toml"), config);
  stacks.push(owned);
  await writeFile(
    path.join(directory, "private-stacks.json"),
    JSON.stringify(stacks),
  );
  console.log(
    `Starting owned ${name} realm; project config ${owned.directory}`,
  );
  await run(owned, [
    "start",
    "-x",
    "studio,logflare,vector,imgproxy,supavisor,edge-runtime",
  ]);
  const status = parseLocalSupabaseStatus(
    await run(owned, ["status", "--output", "json"]),
  );
  for (const url of [status.apiUrl, status.databaseUrl])
    assert.ok(
      ["127.0.0.1", "localhost", "[::1]"].includes(new URL(url).hostname),
    );
  return { ...owned, ...status };
}
let sql, server;
async function stop() {
  server?.close();
  if (sql) await sql.end({ timeout: 5 });
  for (const owned of stacks.toReversed())
    await run(owned, ["stop", "--no-backup"]);
  console.log(
    "Stopped only UIAUDIT01 owned realms. Remove their private temp directory after evidence export.",
  );
}
try {
  const normal = await stack("normal", 4000);
  const mock = await stack("mock", 5000);
  sql = postgres(mock.databaseUrl, { max: 4, onnotice: () => {} });
  const inventory = await migrationInventory(root);
  await sql.unsafe(await readFile("supabase/mock/marker.sql", "utf8"));
  await sql`insert into mock_control.environment(project_ref,generation,schema_fingerprint,operator_confirmed)
    values(${MOCK_REF},${GENERATION},${inventory.fingerprint},true)`;
  await sql.unsafe(await readFile("supabase/mock/control.sql", "utf8"));
  const options = {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  };
  const context = {
    sql,
    guard: async (tx = sql) => {
      const [marker] =
        await tx`select project_ref,generation,schema_fingerprint from mock_control.environment`;
      assert.deepEqual(marker, {
        project_ref: MOCK_REF,
        generation: GENERATION,
        schema_fingerprint: inventory.fingerprint,
      });
    },
    client: () => createClient(mock.apiUrl, mock.publishableKey, options),
    admin: () => createClient(mock.apiUrl, mock.serviceRoleKey, options),
  };
  console.log("Seeding original ten personas through canonical RPCs.");
  const first = await seed(context);
  const verification = await verify(context);
  await sql`update mock_control.environment set enabled=true`;
  const runtime = createRuntime({
    enabled: true,
    mockOrigin: MOCK_ORIGIN,
    service: mock.serviceRoleKey,
    deliveryKey: randomBytes(32).toString("base64"),
    fetcher: (url, init) => {
      assert.equal(new URL(url).origin, MOCK_ORIGIN);
      return fetch(url.replace(MOCK_ORIGIN, mock.apiUrl), init);
    },
  });
  server = http.createServer(async (req, res) => {
    try {
      if (req.url === "/functions/v1/mock-personas") {
        const chunks = [];
        for await (const chunk of req) chunks.push(chunk);
        const response = await runtime(
          new Request(`http://localhost${req.url}`, {
            method: req.method,
            headers: req.headers,
            ...(req.method !== "GET" ? { body: Buffer.concat(chunks) } : {}),
          }),
        );
        res.writeHead(response.status, Object.fromEntries(response.headers));
        res.end(Buffer.from(await response.arrayBuffer()));
      } else {
        const forward = http.request(
          new URL(req.url, mock.apiUrl),
          { method: req.method, headers: req.headers },
          (incoming) => {
            res.writeHead(incoming.statusCode, incoming.headers);
            incoming.pipe(res);
          },
        );
        forward.on("error", () => {
          res.writeHead(502);
          res.end("Local realm unavailable");
        });
        req.pipe(forward);
      }
    } catch {
      res.writeHead(500);
      res.end("Local broker failed");
    }
  });
  server.on("upgrade", (req, socket, head) => {
    const forward = http.request(new URL(req.url, mock.apiUrl), {
      headers: req.headers,
    });
    forward.on("upgrade", (response, upstream, upstreamHead) => {
      socket.write(
        `HTTP/1.1 ${response.statusCode} Switching Protocols\r\n` +
          Object.entries(response.headers)
            .map(([k, v]) => `${k}: ${v}\r\n`)
            .join("") +
          "\r\n",
      );
      if (head.length) upstream.write(head);
      if (upstreamHead.length) socket.write(upstreamHead);
      socket.pipe(upstream).pipe(socket);
      socket.on("error", () => upstream.destroy());
      upstream.on("error", () => socket.destroy());
    });
    forward.on("error", () => socket.destroy());
    forward.end();
  });
  await new Promise((resolve) => server.listen(59421, "127.0.0.1", resolve));
  const defines = {
    APP_ENV: "local",
    ENABLE_DEMO_TOOLS: "false",
    ENABLE_CLOSED_TEST_MOCK: "true",
    SUPABASE_URL: normal.apiUrl,
    SUPABASE_PUBLISHABLE_KEY: normal.publishableKey,
    MOCK_SUPABASE_URL: "http://127.0.0.1:59421",
    MOCK_SUPABASE_PUBLISHABLE_KEY: mock.publishableKey,
    MOCK_PERSONA_BROKER_URL:
      "http://127.0.0.1:59421/functions/v1/mock-personas",
    MOCK_FIXTURE_GENERATION: GENERATION,
  };
  await writeFile(
    path.join(directory, "private-defines.json"),
    JSON.stringify(defines),
  );
  const receipts =
    await sql`select fixture_key, receipt from mock_control.fixtures order by fixture_key`;
  await writeFile(
    path.join(directory, "fixtures.json"),
    JSON.stringify({ first, receipts }, null, 2),
  );
  await writeFile(
    path.join(directory, "provenance.json"),
    JSON.stringify(
      {
        generation: GENERATION,
        inventory,
        verification,
        realms: {
          normal: normal.apiUrl,
          mock: mock.apiUrl,
          broker: "http://127.0.0.1:59421",
        },
        seededAt: new Date().toISOString(),
      },
      null,
      2,
    ),
  );
  console.log(
    `UIAUDIT01 READY: ${directory} (${verification.checks} seed checks). Ctrl+C stops owned resources.`,
  );
  await new Promise((resolve) => {
    process.once("SIGINT", resolve);
    process.once("SIGTERM", resolve);
  });
} finally {
  await stop();
}
