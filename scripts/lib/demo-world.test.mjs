import assert from "node:assert/strict";
import test from "node:test";

import {
  DEMO_PERSONAS,
  DEMO_SCENARIO_KEYS,
  assertSafeLocalDemoTarget,
  buildDemoTimes,
  classifyDemoScenarioCounts,
  demoReadyMessage,
  safeDatabaseFailure,
} from "./demo-world.mjs";

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
});

test("keeps persona and scenario definitions stable and unique", () => {
  assert.deepEqual(
    Object.values(DEMO_PERSONAS).map((persona) => persona.email),
    [
      "demo-alice@planets.invalid",
      "demo-bob@planets.invalid",
      "demo-carla@planets.invalid",
    ],
  );
  const titles = [
    ...Object.values(DEMO_SCENARIO_KEYS.proposals),
    ...Object.values(DEMO_SCENARIO_KEYS.tavoli),
    ...Object.values(DEMO_SCENARIO_KEYS.listings),
  ];
  assert.equal(new Set(titles).size, titles.length);
  assert.ok(titles.every((title) => title.startsWith("DEMO · ")));
  assert.ok(Object.isFrozen(DEMO_PERSONAS.alice.skillSlugs));
  assert.equal(new Set(DEMO_SCENARIO_KEYS.chatBodies).size, 3);
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
