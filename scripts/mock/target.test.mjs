import assert from "node:assert/strict";
import test from "node:test";
import {
  assertTarget,
  MOCK_REF,
  MOCK_ORIGIN,
  NORMAL_ORIGIN,
  GENERATION,
  publicKey,
} from "./target.mjs";
const hash = "a".repeat(64);
const config = {
  projectRef: MOCK_REF,
  apiUrl: MOCK_ORIGIN,
  normalOrigin: NORMAL_ORIGIN,
};
const marker = {
  project_ref: MOCK_REF,
  generation: GENERATION,
  schema_fingerprint: hash,
  operator_confirmed: true,
};
test("requires exact independent target, acknowledged marker and schema", () => {
  assert.equal(assertTarget(config, marker, hash), true);
  for (const change of [
    { projectRef: "cllpvruvrrvxczjitlqd" },
    { projectRef: "my-test" },
    { apiUrl: NORMAL_ORIGIN },
    { apiUrl: MOCK_ORIGIN + "/" },
    { normalOrigin: MOCK_ORIGIN },
    { apiUrl: MOCK_ORIGIN + "@evil.invalid" },
  ]) {
    assert.throws(() => assertTarget({ ...config, ...change }, marker, hash));
  }
  for (const change of [
    { project_ref: "cllpvruvrrvxczjitlqd" },
    { operator_confirmed: false },
    { schema_fingerprint: "b".repeat(64) },
    { generation: "old" },
  ]) {
    assert.throws(() => assertTarget(config, { ...marker, ...change }, hash));
  }
  assert.throws(() => assertTarget(config, null, hash));
});
test("client credentials reject privileged and legacy JWT inputs", () => {
  for (const key of [
    "service_role",
    "sb_secret_" + "a".repeat(30),
    "eyJhbGciOiJIUzI1NiJ9.payload.signature",
    "",
  ])
    assert.throws(() => publicKey(key));
  assert.equal(
    publicKey("sb_publishable_" + "a".repeat(30)),
    "sb_publishable_" + "a".repeat(30),
  );
});
