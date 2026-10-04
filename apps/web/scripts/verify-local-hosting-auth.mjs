import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import postgres from "postgres";
import {
  combineChunks,
  createChunks,
  createServerClient,
  serializeCookieHeader,
  stringFromBase64URL,
  stringToBase64URL,
} from "@supabase/ssr";
import { readHostingBackend } from "./local-hosting-backend.mjs";
import { parseProbeOrigin } from "./probe-local-hosting.mjs";
import {
  assertPrivateFixtureResponse,
  privateFixtureMarkers,
} from "./hosting-private-fixture.mjs";

assert.equal(
  process.argv.length,
  7,
  "Usage: node apps/web/scripts/verify-local-hosting-auth.mjs ORIGIN PROFILE_CASE ADMIN_SELF_CASE CORROBORATION_CASE COUNTERSTATEMENT_CASE",
);
const origin = parseProbeOrigin(process.argv[2]);
const [profileCase, selfCase, corroborationCase, counterstatementCase] =
  process.argv.slice(3);
for (const id of [
  profileCase,
  selfCase,
  corroborationCase,
  counterstatementCase,
])
  assert.match(
    id,
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    "Use IDs printed by the disposable seed.",
  );
const backend = await readHostingBackend();
const sql = postgres(backend.databaseUrl, { max: 1, onnotice: () => {} });
const privateCases = [
  { id: profileCase, markers: privateFixtureMarkers.notes },
  { id: corroborationCase, markers: [privateFixtureMarkers.witness] },
  {
    id: counterstatementCase,
    markers: [privateFixtureMarkers.counterstatement],
  },
];
const allMarkers = privateCases.flatMap(({ markers }) => [...markers]);
const mailpit = "http://127.0.0.1:54364";
let stage = "initialization";

async function json(url) {
  const response = await fetch(url, { signal: AbortSignal.timeout(15_000) });
  assert.ok(response.ok, `Local Mailpit failed (${response.status}).`);
  return response.json();
}

async function signIn(role, padded = false) {
  stage = `synthetic OTP sign-in: ${role}`;
  const email = `webhost01-${role}@planets.invalid`;
  const search = `${mailpit}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}&limit=20`;
  const existing = new Set(
    (await json(search)).messages.map((message) => message.ID),
  );
  const jar = new Map();
  const client = createServerClient(backend.apiUrl, backend.publishableKey, {
    cookies: {
      getAll: () => [...jar].map(([name, value]) => ({ name, value })),
      setAll: (cookies) => {
        for (const { name, value } of cookies) {
          if (value) jar.set(name, value);
          else jar.delete(name);
        }
      },
    },
  });
  const request = await client.auth.signInWithOtp({ email });
  assert.ok(!request.error, "Synthetic OTP request failed.");
  let message;
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    message = (await json(search)).messages.find(
      (item) => !existing.has(item.ID),
    );
    if (message) break;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  assert.ok(message, "No new synthetic OTP email arrived.");
  const content = await json(
    `${mailpit}/api/v1/message/${encodeURIComponent(message.ID)}`,
  );
  const token = `${content.Text ?? ""} ${content.HTML ?? ""}`.match(
    /(?:^|\D)(\d{6})(?:\D|$)/,
  )?.[1];
  assert.ok(token, "Missing synthetic six-digit OTP.");
  const verified = await client.auth.verifyOtp({ email, token, type: "email" });
  assert.ok(!verified.error, "Synthetic OTP verification failed.");
  assert.ok(verified.data.user?.id, "Missing verified identity.");
  if (padded) {
    // Synthetic Auth metadata only, to exercise real cookie chunking/refresh.
    const updated = await client.auth.updateUser({
      data: { webhost_qa_padding: "x".repeat(2000) },
    });
    assert.ok(!updated.error, "Synthetic cookie-padding update failed.");
    // Metadata occurs in both the user and a newly issued JWT. Rotate once so
    // repeat runs use the bounded current fixture instead of an older padded
    // token; 2,000 characters still exercises chunks below Node's 16 KiB
    // default request-header limit. The later envelope expiry tests Proxy refresh.
    const refreshed = await client.auth.refreshSession();
    assert.ok(!refreshed.error, "Synthetic metadata refresh failed.");
  }
  return { jar, client, id: verified.data.user.id, role };
}

async function rpc(actor, name, params) {
  stage = `canonical RPC: ${actor.role}/${name}`;
  const result = await actor.client.rpc(name, params);
  assert.ok(!result.error, `Local hosting RPC ${name} failed.`);
  return result.data;
}

async function request(actor, path, init = {}) {
  stage = `${actor.role}: ${init.method ?? "GET"} ${path}`;
  const start = performance.now();
  const response = await fetch(`${origin}${path}`, {
    ...init,
    headers: {
      ...init.headers,
      Cookie: [...actor.jar]
        .map(([name, value]) => serializeCookieHeader(name, value, {}))
        .join("; "),
    },
    redirect: "manual",
    signal: AbortSignal.timeout(15_000),
  });
  const body = await response.text();
  const cookies = response.headers.getSetCookie();
  // Emit only boundary metadata before assertions, so failed redirects/cache
  // contracts remain diagnosable without printing private bodies or cookies.
  console.log(
    JSON.stringify({
      role: actor.role,
      path,
      method: init.method ?? "GET",
      status: response.status,
      wallMs: Math.round(performance.now() - start),
      bytes: Buffer.byteLength(body),
      setCookieCount: cookies.length,
      cacheControl: response.headers.get("cache-control"),
    }),
  );
  assert.match(
    response.headers.get("cache-control") ?? "",
    /no-store/,
    "Private response lost no-store.",
  );
  for (const cookie of cookies) {
    // Preserve values in memory, never in stdout or an evidence file.
    const pair = cookie.split(";", 1)[0];
    const separator = pair.indexOf("=");
    const name = pair.slice(0, separator);
    const value = pair.slice(separator + 1);
    if (value) actor.jar.set(name, value);
    else actor.jar.delete(name);
    assert.ok(!/;\s*Domain=/i.test(cookie), "Unexpected broad cookie domain.");
    assert.match(cookie, /;\s*SameSite=Lax/i, "Unexpected cookie SameSite.");
  }
  return { response, body, cookies };
}

async function forceRefresh(actor) {
  stage = `real chunked session refresh: ${actor.role}`;
  const key = [...actor.jar.keys()]
    .find((name) => /-auth-token(?:\.0)?$/.test(name))
    ?.replace(/\.0$/, "");
  assert.ok(key, "Missing synthetic session cookie.");
  const encoded = await combineChunks(key, (name) => actor.jar.get(name));
  assert.ok(encoded?.startsWith("base64-"), "Unexpected SSR cookie encoding.");
  const session = JSON.parse(stringFromBase64URL(encoded.slice(7)));
  // Do not forge identity/JWT claims: retain real valid tokens, expire only the
  // client session envelope so the server must use its genuine refresh token.
  session.expires_at = 1;
  for (const name of [...actor.jar.keys()])
    if (name === key || name.startsWith(`${key}.`)) actor.jar.delete(name);
  for (const chunk of createChunks(
    key,
    `base64-${stringToBase64URL(JSON.stringify(session))}`,
  ))
    actor.jar.set(chunk.name, chunk.value);
  const result = await request(actor, "/profile");
  stage = `verify refreshed identity: ${actor.role}`;
  assert.equal(result.response.status, 200);
  assert.ok(
    result.body.includes(`WEBHOST QA ${actor.role}`),
    "Wrong identity after Proxy refresh.",
  );
  stage = `verify multiple refreshed cookies: ${actor.role}`;
  assert.ok(
    result.cookies.length >= 2,
    "Did not exercise multiple Set-Cookie headers.",
  );
}

async function main() {
  const moderator = await signIn("moderator", true);
  const admin = await signIn("admin", true);
  const ordinary = await signIn("unrelated");
  for (const actor of [moderator, admin]) await forceRefresh(actor);
  for (let index = 0; index < 3; index++) {
    for (const actor of [moderator, admin]) {
      const profile = await request(actor, "/profile");
      assert.equal(profile.response.status, 200);
      assert.ok(profile.body.includes(`WEBHOST QA ${actor.role}`));
      const other = actor.role === "admin" ? "moderator" : "admin";
      assert.ok(
        !profile.body.includes(`WEBHOST QA ${other}`),
        "Cross-session profile response.",
      );
      const queue = await request(actor, "/admin");
      assert.equal(queue.response.status, 200);
      const text = queue.body
        .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "")
        .replace(/<[^>]*>/g, " ")
        .replace(/\s+/g, " ");
      assert.ok(
        text.includes(`Signed in as ${actor.role}`),
        "Cross-session staff role.",
      );
      const flight = await request(actor, "/admin?_rsc", {
        headers: { RSC: "1" },
      });
      assert.equal(flight.response.status, 200);
      assert.ok(
        flight.body.includes(`"Signed in as ","${actor.role}"`),
        "Wrong staff role in Flight response.",
      );
      for (const { id, markers } of index === 0
        ? privateCases
        : privateCases.slice(0, 1)) {
        for (const format of ["html", "flight"]) {
          const detail = await request(
            actor,
            `/admin/cases/${id}${format === "flight" ? "?_rsc" : ""}`,
            {
              headers: format === "flight" ? { RSC: "1" } : {},
            },
          );
          assertPrivateFixtureResponse(detail.response, detail.body, {
            format,
            authorized: true,
            markers,
          });
        }
      }
    }
  }
  // Authorized reads above must establish every marker before these checks run.
  const anonymous = { role: "anonymous", jar: new Map() };
  for (const actor of [anonymous, ordinary]) {
    for (const path of [
      "/admin",
      ...privateCases.map(({ id }) => `/admin/cases/${id}`),
    ]) {
      for (const format of ["html", "flight"]) {
        const result = await request(
          actor,
          `${path}${format === "flight" ? "?_rsc" : ""}`,
          {
            headers: format === "flight" ? { RSC: "1" } : {},
          },
        );
        assertPrivateFixtureResponse(result.response, result.body, {
          format,
          authorized: false,
          markers: allMarkers,
        });
      }
    }
  }

  const manifest = JSON.parse(
    await readFile(
      new URL(
        "../.next/server/server-reference-manifest.json",
        import.meta.url,
      ),
      "utf8",
    ),
  );
  const action = Object.entries(manifest.node).find(
    ([, value]) => value.exportedName === "moderationConsequenceAction",
  )?.[0];
  assert.ok(action, "Missing built consequence action.");
  const { encodeReply } = createRequire(import.meta.url)(
    "next/dist/compiled/react-server-dom-turbopack/client.browser",
  );
  stage = "temporary disposable moderator role deactivation";
  const roles =
    await sql`update private.moderation_staff_roles set is_active = false, deactivated_at = statement_timestamp()
    where profile_id = ${moderator.id}::uuid and is_active = true returning profile_id`;
  assert.equal(roles.length, 1, "Missing active synthetic moderator role.");
  try {
    for (const format of ["html", "flight"]) {
      const result = await request(
        moderator,
        `/admin/cases/${profileCase}${format === "flight" ? "?_rsc" : ""}`,
        {
          headers: format === "flight" ? { RSC: "1" } : {},
        },
      );
      assertPrivateFixtureResponse(result.response, result.body, {
        format,
        authorized: false,
        markers: allMarkers,
      });
    }
    const form = new FormData();
    for (const [key, value] of Object.entries({
      mode: "apply",
      type: "safety_notice",
      caseId: profileCase,
      userReason: "Synthetic stale-role probe reason",
      internalNote: "Synthetic stale-role PRIVATE probe note",
    }))
      form.set(key, value);
    const result = await request(moderator, `/admin/cases/${profileCase}`, {
      method: "POST",
      headers: { "Next-Action": action, Origin: origin },
      body: await encodeReply([{ status: "idle" }, form]),
    });
    assert.equal(result.response.status, 200);
    assert.ok(result.body.includes('"kind":"unauthorized"'));
    assert.ok(!result.body.includes('"status":"success"'));
    const [notes] =
      await sql`select count(*)::integer as count from private.moderation_case_notes
      where case_id = ${profileCase}::uuid and body = 'Synthetic stale-role PRIVATE probe note'`;
    assert.equal(notes.count, 0, "Stale role persisted a private note.");
  } finally {
    await sql`update private.moderation_staff_roles set is_active = true, deactivated_at = null
      where profile_id = ${moderator.id}::uuid`;
  }
  for (const [actor, id, kind] of [
    [ordinary, profileCase, "unauthorized"],
    [moderator, profileCase, "unauthorized"],
    [admin, selfCase, "self_suspension"],
  ]) {
    const form = new FormData();
    for (const [key, value] of Object.entries({
      mode: "apply",
      type: "account_suspension",
      caseId: id,
      userReason: "Synthetic unauthorized probe reason",
      internalNote: "Synthetic unauthorized PRIVATE probe note",
    }))
      form.set(key, value);
    const result = await request(actor, `/admin/cases/${id}`, {
      method: "POST",
      headers: { "Next-Action": action, Origin: origin },
      body: await encodeReply([{ status: "idle" }, form]),
    });
    assert.equal(result.response.status, 200);
    assert.ok(
      result.body.includes(`"kind":"${kind}"`),
      "Unexpected action authorization result.",
    );
    assert.ok(!result.body.includes('"status":"success"'));
  }

  const [receipt] = await rpc(ordinary, "submit_moderation_report", {
    p_expected_reporter_profile_id: ordinary.id,
    p_client_submission_id: randomUUID(),
    p_category: "other",
    p_explanation: "Synthetic hosting suspended-staff reauthorization probe.",
    p_target_kind: "profile",
    p_target_id: moderator.id,
    p_context_kind: null,
    p_context_id: null,
  });
  await rpc(admin, "transition_moderation_case", {
    p_expected_staff_profile_id: admin.id,
    p_case_id: receipt.case_id,
    p_expected_state_version: 0,
    p_target_state: "under_review",
  });
  const episode = await rpc(admin, "apply_account_suspension", {
    p_expected_staff_profile_id: admin.id,
    p_case_id: receipt.case_id,
    p_user_reason: "Synthetic local staff suspension reason",
    p_internal_note: "Synthetic PRIVATE staff suspension note",
  });
  try {
    const result = await request(moderator, "/admin");
    assert.equal(
      result.response.status,
      404,
      "Suspended staff retained web authority.",
    );
  } finally {
    await rpc(admin, "revoke_account_suspension", {
      p_expected_staff_profile_id: admin.id,
      p_consequence_id: episode,
      p_user_reason: "Synthetic local staff recovery reason",
      p_internal_note: "Synthetic PRIVATE staff recovery note",
    });
  }
  const restored = await request(moderator, "/admin");
  assert.equal(
    restored.response.status,
    200,
    "Restored staff did not recover.",
  );
  stage = "moderator independent local sign-out";
  assert.ok(!(await moderator.client.auth.signOut({ scope: "local" })).error);
  assert.equal((await request(moderator, "/admin")).response.status, 404);
  assert.equal(
    (await request(admin, "/admin")).response.status,
    200,
    "Signing out one jar affected another session.",
  );
  stage = "remaining synthetic local sign-out";
  assert.ok(!(await admin.client.auth.signOut({ scope: "local" })).error);
  assert.ok(!(await ordinary.client.auth.signOut({ scope: "local" })).error);
  console.log(
    "Real OTP, chunked Proxy refresh, interleaved HTML/Flight session isolation, actual private note/evidence denial, forged moderator/admin-self suspension denial, stale-role/suspended-staff reauthorization and independent sign-out passed locally. No cloud CPU/CDN certification.",
  );
}

main()
  .catch(() => {
    // No raw errors/payloads: Auth/PostgREST error objects can contain private data.
    console.error(
      `Authenticated hosting verification FAILED at ${stage}. Check the disposable fixture and expected boundary; never publish tokens, cookie jars or manifests.`,
    );
    process.exitCode = 1;
  })
  .finally(() => sql.end({ timeout: 2 }));
