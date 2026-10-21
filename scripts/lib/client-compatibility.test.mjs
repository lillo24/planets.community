import assert from "node:assert/strict";
import { test } from "node:test";
import {
  createHandler,
  parsePolicy,
} from "../../supabase/functions/client-compatibility/handler.mjs";

const policy = () => ({
  schema_version: 1,
  android: {
    application_id: "community.planets.app",
    minimum_version: "0.0.0",
    minimum_build: "0",
  },
  ios: {
    application_id: "community.planets.bootstrap.planetsMobile",
    minimum_version: "0.0.0",
    minimum_build: "0",
    app_store_id: null,
  },
});
const request = (
  platform = "android",
  applicationId = "community.planets.app",
) =>
  new Request("https://example.invalid/client-compatibility", {
    method: "POST",
    body: JSON.stringify({ platform, application_id: applicationId }),
  });
const handler = (value = policy()) =>
  createHandler({ policySource: JSON.stringify(value) });

test("public inactive floors are explicit, uncached and contain no product data", async () => {
  const response = await handler()(request());
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.deepEqual(await response.json(), {
    schema_version: 1,
    platform: "android",
    application_id: "community.planets.app",
    minimum_version: "0.0.0",
    minimum_build: "0",
    update_url:
      "https://play.google.com/store/apps/details?id=community.planets.app",
  });
});
test("iOS uses a numeric App Store listing, never a guessed name or bundle URL", async () => {
  const value = policy();
  const input = () => request("ios", value.ios.application_id);
  assert.equal((await (await handler(value)(input())).json()).update_url, null);
  value.ios.minimum_version = "1.2.0";
  assert.equal((await handler(value)(input())).status, 503);
  value.ios.app_store_id = "123456789"; // Synthetic test identifier only.
  assert.equal(
    (await (await handler(value)(input())).json()).update_url,
    "https://apps.apple.com/app/id123456789",
  );
});
test("missing or invalid configuration cannot become a permissive policy", async () => {
  for (const source of [
    "",
    "null",
    "{}",
    "{invalid",
    JSON.stringify({ ...policy(), extra: "unexpected" }),
  ]) {
    const response = await createHandler({ policySource: source })(request());
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), {
      error: "compatibility_policy_unavailable",
    });
  }
});
test("policy validates numeric releases/builds and exact platform identities", async () => {
  for (const [key, invalid] of [
    ["minimum_version", "1.2"],
    ["minimum_version", "1.2.3-beta"],
    ["minimum_build", "3.2"],
    ["minimum_build", 10],
    ["application_id", "../../other"],
  ]) {
    const value = policy();
    value.android[key] = invalid;
    assert.throws(() => parsePolicy(JSON.stringify(value)));
  }
  const value = policy();
  value.android.minimum_build = "2100000000";
  assert.doesNotThrow(() => parsePolicy(JSON.stringify(value)));
});
test("request does not choose policy floors or another application", async () => {
  assert.equal(
    (await handler()(request("android", "other.application"))).status,
    409,
  );
  assert.equal((await handler()(request("web"))).status, 400);
  assert.equal(
    (
      await handler()(
        new Request("https://example.invalid", {
          method: "POST",
          body: JSON.stringify({
            platform: "android",
            application_id: "community.planets.app",
            minimum_build: "0",
          }),
        }),
      )
    ).status,
    400,
  );
});
test("method, preflight and actual body size are bounded", async () => {
  assert.equal(
    (await handler()(new Request("https://example.invalid"))).status,
    405,
  );
  assert.equal(
    (
      await handler()(
        new Request("https://example.invalid", { method: "OPTIONS" }),
      )
    ).status,
    204,
  );
  assert.equal(
    (
      await handler()(
        new Request("https://example.invalid", {
          method: "POST",
          body: "a".repeat(1025),
        }),
      )
    ).status,
    413,
  );
  assert.equal(
    (
      await handler()(
        new Request("https://example.invalid", {
          method: "POST",
          body: "invalid",
        }),
      )
    ).status,
    400,
  );
});
