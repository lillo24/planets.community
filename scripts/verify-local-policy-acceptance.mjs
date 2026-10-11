import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";

import { readLocalSupabaseStatus } from "./lib/local-supabase-status.mjs";
import { signInLocalOtpUser } from "./lib/local-authenticated-user.mjs";

const version = "POLICY01-2026-10-08-v1";
const { apiUrl, publishableKey, databaseUrl } = readLocalSupabaseStatus(
  process.cwd(),
);
const mailpitUrl = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";
for (const target of [apiUrl, databaseUrl, mailpitUrl]) {
  assert.ok(
    target,
    "Local policy verification requires all three local endpoints.",
  );
  assert.ok(
    ["localhost", "127.0.0.1", "[::1]"].includes(new URL(target).hostname),
    "Policy verification refuses non-loopback targets.",
  );
}
const sql = postgres(databaseUrl, { max: 2 });
const email = `policy-a-${randomUUID()}@planets.invalid`;
const login = (email, shouldCreateUser = true) =>
  signInLocalOtpUser({
    apiUrl,
    publishableKey,
    mailpitUrl,
    email,
    shouldCreateUser,
    verifierName: "policy-acceptance",
  });
const params = (id, bundle = version) => ({
  p_expected_account_id: id,
  p_bundle_version: bundle,
});
const rpc = async (client, operation, args) => {
  const { data, error } = await client.rpc(operation, args);
  assert.equal(
    error?.code ?? null,
    null,
    `Policy RPC ${operation} failed (${error?.code ?? "unknown"}).`,
  );
  return data;
};
const denied = async (client, operation, args, code) => {
  const { error } = await client.rpc(operation, args);
  assert.equal(error?.code, code, `Policy RPC ${operation} must fail closed.`);
};

try {
  const [alice, bob] = await Promise.all([
    login(email),
    login(`policy-b-${randomUUID()}@planets.invalid`),
  ]);
  const [anchor] =
    await sql`select count(*)::integer as total from public.profiles where id = ${alice.id}::uuid`;
  assert.equal(
    anchor.total,
    0,
    "Policy acceptance must work before a profile anchor exists.",
  );
  assert.deepEqual(
    await rpc(alice.client, "get_policy_acceptance", params(alice.id)),
    [],
  );
  const before = Date.now();
  const results = await Promise.all(
    Array.from({ length: 8 }, () =>
      rpc(alice.client, "accept_policy_bundle", params(alice.id)),
    ),
  );
  const first = results[0];
  assert.equal(first.length, 1);
  assert.equal(first[0].account_id, alice.id);
  assert.equal(first[0].bundle_version, version);
  const accepted = Date.parse(first[0].accepted_at);
  assert.ok(
    accepted >= before - 1000 && accepted <= Date.now() + 1000,
    "Acceptance uses server time.",
  );
  for (const result of results)
    assert.deepEqual(
      result,
      first,
      "Concurrent taps preserve the first record.",
    );
  const [count] =
    await sql`select count(*)::integer as total from private.policy_acceptances where account_id = ${alice.id}::uuid`;
  assert.equal(count.total, 1);
  // A second real OTP session has independent client memory and persistence disabled.
  // The local Auth configuration permits another email after one second.
  await new Promise((resolve) => setTimeout(resolve, 1100));
  const second = await login(email, false);
  assert.equal(second.id, alice.id);
  assert.deepEqual(
    await rpc(second.client, "get_policy_acceptance", params(second.id)),
    first,
  );
  assert.deepEqual(
    await rpc(second.client, "accept_policy_bundle", params(second.id)),
    first,
  );
  assert.deepEqual(
    await rpc(bob.client, "get_policy_acceptance", params(bob.id)),
    [],
  );
  for (const operation of ["get_policy_acceptance", "accept_policy_bundle"]) {
    await denied(bob.client, operation, params(alice.id), "42501");
    await denied(
      alice.client,
      operation,
      params(alice.id, "unregistered"),
      "22023",
    );
    const anonymous = createClient(apiUrl, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    await denied(anonymous, operation, params(alice.id), "42501");
  }
  await denied(
    alice.client,
    "accept_policy_bundle",
    { ...params(alice.id), accepted_at: "2000-01-01T00:00:00Z" },
    "PGRST202",
  );
  const direct = await alice.client
    .schema("private")
    .from("policy_acceptances")
    .select("*");
  assert.ok(
    direct.error,
    "Private acceptance records cannot be read through the Data API.",
  );
  const [afterAnchor] =
    await sql`select count(*)::integer as total from public.profiles where id = ${alice.id}::uuid`;
  assert.equal(afterAnchor.total, 0);
  console.log(
    "Policy acceptance passed: real OTP sessions without profiles, eight concurrent explicit acceptances, original server timestamp, second-session restoration, identity/version/anonymous denial and private Data API isolation.",
  );
} finally {
  await sql.end();
}
