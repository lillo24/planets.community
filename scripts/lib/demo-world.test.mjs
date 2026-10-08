import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  DEMO_PERSONAS,
  DEMO_SCENARIOS,
  assertSafeLocalDemoTarget,
  buildDemoTimes,
  classifyDemoScenarioCounts,
  demoReadyMessage,
  readDemoDiscoveryPages,
  safeDatabaseFailure,
} from "./demo-world.mjs";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
);
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/u;

test("accepts only explicit loopback demo targets", () => {
  assert.deepEqual(
    assertSafeLocalDemoTarget({
      environment: "local",
      apiUrl: "http://127.0.0.1:54321",
      databaseUrl: "postgresql://postgres:local-only@localhost:54322/postgres",
      mailpitUrl: "http://[::1]:54324",
    }),
    {
      apiUrl: "http://127.0.0.1:54321",
      databaseUrl: "postgresql://postgres:local-only@localhost:54322/postgres",
      mailpitUrl: "http://[::1]:54324",
    },
  );
});

test("refuses staging, production, and remote targets", () => {
  const localValues = {
    apiUrl: "http://127.0.0.1:54321",
    databaseUrl: "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
    mailpitUrl: "http://127.0.0.1:54324",
  };
  assert.throws(
    () =>
      assertSafeLocalDemoTarget({
        ...localValues,
        environment: "production",
      }),
    /only the explicit local target/u,
  );
  assert.throws(
    () =>
      assertSafeLocalDemoTarget({
        ...localValues,
        apiUrl: "https://project.supabase.co",
      }),
    /non-loopback target/u,
  );
  assert.throws(
    () =>
      assertSafeLocalDemoTarget({
        ...localValues,
        databaseUrl:
          "postgresql://postgres:secret@database.example.com:5432/postgres",
      }),
    /non-loopback target/u,
  );
  assert.throws(
    () =>
      assertSafeLocalDemoTarget({
        ...localValues,
        mailpitUrl: "https://mail.example.com",
      }),
    /non-loopback target/u,
  );
});

test("demo target requires all URLs and refuses remote Mailpit before mutation", () => {
  const values = {
    apiUrl: "http://127.0.0.1:54821",
    databaseUrl: "postgresql://postgres:local-only@127.0.0.1:54822/postgres",
    mailpitUrl: "http://127.0.0.1:54824",
  };
  for (const key of ["apiUrl", "databaseUrl", "mailpitUrl"])
    assert.throws(
      () => assertSafeLocalDemoTarget({ ...values, [key]: undefined }),
      /required/,
    );
  assert.throws(
    () =>
      assertSafeLocalDemoTarget({
        ...values,
        mailpitUrl: "https://mailpit.example.test",
      }),
    /non-loopback/,
  );
});

test("keeps persona and scenario definitions stable and unique", () => {
  assert.deepEqual(
    Object.values(DEMO_PERSONAS).map((persona) => persona.email),
    [
      "demo-alice@planets.invalid",
      "demo-bob@planets.invalid",
      "demo-carla@planets.invalid",
      "demo-dario@planets.invalid",
      "demo-elena@planets.invalid",
      "demo-planets@planets.invalid",
      "demo-reviewer@planets.invalid",
    ],
  );
  assert.deepEqual(
    Object.values(DEMO_PERSONAS).map((persona) => persona.displayName),
    [
      "Giulia",
      "Marco",
      "Sara",
      "Dario",
      "Elena",
      "PLANETS — demo locale",
      "Revisore — demo locale",
    ],
  );

  const entries = [
    ...Object.entries(DEMO_SCENARIOS.proposals),
    ...Object.entries(DEMO_SCENARIOS.tavoli),
    ...Object.entries(DEMO_SCENARIOS.listings),
  ];
  const definitions = entries.map(([, definition]) => definition);
  const titles = definitions.map((definition) => definition.title);
  const legacyTitles = definitions
    .map((definition) => definition.legacyTitle)
    .filter(Boolean);
  const coverAssets = definitions.map((definition) => definition.coverAsset);
  const coverVersions = definitions.map(
    (definition) => definition.coverVersion,
  );

  assert.equal(entries.length, 13);
  assert.equal(legacyTitles.length, 9);
  assert.ok(entries.every(([key, definition]) => definition.key === key));
  assert.ok(
    definitions.every((definition) => definition.ownerKey in DEMO_PERSONAS),
  );
  assert.equal(new Set(titles).size, titles.length);
  assert.ok(titles.every((title) => !title.startsWith("DEMO ·")));
  assert.equal(new Set(legacyTitles).size, legacyTitles.length);
  assert.ok(legacyTitles.every((title) => title.startsWith("DEMO · ")));
  assert.equal(new Set(coverAssets).size, 9);
  assert.deepEqual(
    definitions.filter((d) => !d.legacyTitle).map((d) => d.coverAsset),
    [
      "repair-cafe.webp",
      "repair-cafe.webp",
      "weekly-community-table.webp",
      "weekly-community-table.webp",
    ],
  );
  assert.equal(new Set(coverVersions).size, coverVersions.length);
  assert.ok(coverVersions.every((version) => uuidPattern.test(version)));
  assert.ok(Object.isFrozen(DEMO_PERSONAS.alice.skillSlugs));
  assert.equal(new Set(DEMO_SCENARIOS.chatBodies).size, 3);
  assert.ok(
    DEMO_SCENARIOS.chatBodies.every((body) =>
      /\b(?:Ho|Io|Perfetto)\b/u.test(body),
    ),
  );

  const photographed = Object.values(DEMO_PERSONAS).filter(
    (p) => p.photoState !== "absent",
  );
  assert.deepEqual(
    Object.values(DEMO_PERSONAS)
      .filter((p) => p.photoState === "absent")
      .map((p) => p.email),
    ["demo-dario@planets.invalid", "demo-elena@planets.invalid"],
  );
  assert.ok(
    Object.values(DEMO_PERSONAS)
      .filter((p) => p.photoState === "absent")
      .every((p) => !p.profileAsset && !p.profileVersion),
  );
  const profileAssets = photographed.map((persona) => persona.profileAsset);
  const profileVersions = photographed.map((persona) => persona.profileVersion);
  assert.equal(new Set(profileAssets).size, profileAssets.length);
  assert.equal(new Set(profileVersions).size, profileVersions.length);
  assert.ok(profileVersions.every((version) => uuidPattern.test(version)));
});

test("demo asset manifest matches deterministic local WebP fixtures", async () => {
  const assetRoot = path.join(repositoryRoot, "scripts", "demo-assets");
  const manifest = JSON.parse(
    await readFile(path.join(assetRoot, "assets.json"), "utf8"),
  );
  const expectedCovers = new Set(
    [
      ...Object.values(DEMO_SCENARIOS.proposals),
      ...Object.values(DEMO_SCENARIOS.tavoli),
      ...Object.values(DEMO_SCENARIOS.listings),
    ].map((definition) => `covers/${definition.coverAsset}`),
  );
  const expectedProfiles = new Set(
    Object.values(DEMO_PERSONAS)
      .filter((p) => p.photoState !== "absent")
      .map((persona) => `profiles/${persona.profileAsset}`),
  );

  assert.equal(manifest.licenseUrl, "https://www.pexels.com/license/");
  assert.deepEqual(
    new Set(manifest.covers.map((asset) => asset.file)),
    expectedCovers,
  );
  assert.deepEqual(
    new Set(manifest.profiles.map((asset) => asset.file)),
    expectedProfiles,
  );

  for (const asset of [...manifest.covers, ...manifest.profiles]) {
    const bytes = await readFile(path.join(assetRoot, asset.file));
    assert.equal(bytes.subarray(0, 4).toString("ascii"), "RIFF");
    assert.equal(bytes.subarray(8, 12).toString("ascii"), "WEBP");
    assert.equal(bytes.length, asset.bytes);
    assert.equal(
      createHash("sha256").update(bytes).digest("hex"),
      asset.sha256,
    );
    assert.ok(bytes.length <= 512 * 1024);
  }
  for (const asset of manifest.covers) {
    assert.equal(asset.width, 1280);
    assert.equal(asset.height, 720);
    assert.ok(asset.bytes <= 280 * 1024);
    assert.match(asset.sourcePageUrl, /^https:\/\/www\.pexels\.com\/photo\//u);
    assert.ok(asset.photographer.length > 0);
  }
  for (const asset of manifest.profiles) {
    assert.equal(asset.width, 512);
    assert.equal(asset.height, 512);
    assert.match(asset.origin, /not a stock identity/u);
  }
});

test("classifies rerun state without treating partial or duplicate data as complete", () => {
  assert.equal(classifyDemoScenarioCounts({ a: 0, b: 0 }), "empty");
  assert.equal(classifyDemoScenarioCounts({ a: 1, b: 1 }), "complete");
  assert.equal(classifyDemoScenarioCounts({ a: 1, b: 0 }), "partial");
  assert.equal(classifyDemoScenarioCounts({ a: 2, b: 1 }), "duplicate");
  assert.throws(
    () => classifyDemoScenarioCounts({ a: -1 }),
    /non-negative integers/u,
  );
});

test("derives useful scenario times from a rounded clock", () => {
  const times = buildDemoTimes(new Date("2032-03-20T10:42:37.999Z"));
  assert.equal(times.anchor, "2032-03-20T10:42:00.000Z");
  assert.equal(times.muralStartsAt, "2032-03-21T22:42:00.000Z");
  assert.equal(times.muralEndsAt, "2032-03-22T02:42:00.000Z");
  assert.equal(times.concertStartsAt, "2032-03-20T02:42:00.000Z");
  assert.equal(times.concertEndsAt, "2032-03-20T08:42:00.000Z");
  assert.match(times.recurringEffectiveFrom, /^2032-03-06$/u);
});

test("safe output never echoes secret-bearing failure content or OTP labels", () => {
  const failure = safeDatabaseFailure("seed demo data", {
    code: "42501",
    message:
      "otp=123456 access_token=secret Authorization=Bearer restricted-place",
  });
  assert.equal(failure.message, "Failed to seed demo data (code 42501).");

  const output = demoReadyMessage();
  assert.doesNotMatch(
    output,
    /\b(?:otp|password|access[_ -]?token|refresh[_ -]?token|authorization|bearer)\b/iu,
  );
  assert.doesNotMatch(output, /\b\d{6}\b/u);
});

for (const [rpcName, timeField, timeParameter, idField] of [
  ["list_public_proposals", "starts_at", "p_cursor_starts_at", "proposal_id"],
  [
    "list_public_recurring_activities",
    "next_starts_at",
    "p_cursor_next_starts_at",
    "recurring_activity_id",
  ],
  [
    "list_public_resource_listings",
    "published_at",
    "p_cursor_published_at",
    "listing_id",
  ],
]) {
  test(`demo discovery traverses all ${rpcName} pages without changing filters`, async () => {
    const calls = [];
    const expected = Array.from({ length: 45 }, (_, index) => ({
      [idField]: `synthetic-${index}`,
      [timeField]: `time-${index}`,
    }));
    const client = {
      async rpc(name, args) {
        assert.equal(name, rpcName);
        calls.push(args);
        const offset =
          args.p_cursor_id === null
            ? 0
            : Number(args.p_cursor_id.split("-")[1]) + 1;
        return { data: expected.slice(offset, offset + 20), error: null };
      },
    };
    const args = {
      p_limit: 20,
      p_locality: "Trento",
      p_cursor_id: null,
      [timeParameter]: null,
    };
    const result = await readDemoDiscoveryPages(client, rpcName, args, {
      p_cursor_id: idField,
      [timeParameter]: timeField,
    });
    assert.deepEqual(result, { data: expected, error: null });
    assert.deepEqual(
      calls.map((call) => call.p_cursor_id),
      [null, "synthetic-19", "synthetic-39"],
    );
    assert.deepEqual(
      calls.map((call) => call[timeParameter]),
      [null, "time-19", "time-39"],
    );
    assert.ok(
      calls.every(
        (call) => call.p_limit === 20 && call.p_locality === "Trento",
      ),
    );
    assert.equal(args.p_cursor_id, null);
  });
}

test("demo discovery accepts a legitimate empty page", async () => {
  assert.deepEqual(
    await readDemoDiscoveryPages(
      { rpc: async () => ({ data: [], error: null }) },
      "public_read",
      { p_limit: 20 },
      { p_cursor_id: "id" },
    ),
    { data: [], error: null },
  );
});

test("demo discovery fails explicitly on backend errors without private payloads", async () => {
  await assert.rejects(
    readDemoDiscoveryPages(
      {
        rpc: async () => ({
          data: null,
          error: { code: "42501", message: "access_token=private" },
        }),
      },
      "public_read",
      { p_limit: 20 },
      { p_cursor_id: "id" },
    ),
    { message: "Failed to read demo discovery public_read (code 42501)." },
  );
});

test("demo discovery rejects non-array pages", async () => {
  await assert.rejects(
    readDemoDiscoveryPages(
      { rpc: async () => ({ data: null, error: null }) },
      "public_read",
      { p_limit: 20 },
      { p_cursor_id: "id" },
    ),
    /non-array page/u,
  );
});

test("demo discovery rejects a full page missing a cursor", async () => {
  await assert.rejects(
    readDemoDiscoveryPages(
      { rpc: async () => ({ data: [{ id: "one" }], error: null }) },
      "public_read",
      { p_limit: 1 },
      { p_cursor_id: "id", p_cursor_time: "time" },
    ),
    /has no time cursor/u,
  );
});

test("demo discovery rejects repeated pages instead of looping or concealing duplicates", async () => {
  await assert.rejects(
    readDemoDiscoveryPages(
      { rpc: async () => ({ data: [{ id: "one" }], error: null }) },
      "public_read",
      { p_limit: 1 },
      { p_cursor_id: "id" },
    ),
    /invalid\/repeated ID/u,
  );
});
