import assert from "node:assert/strict";
import test from "node:test";
import { classifyAccountRpc } from "./account-suspension-audit.mjs";

const rpc = {
  schema: "public",
  name: "read_private",
  signature: "read_private(uuid)",
  auth: true,
  anon: false,
  source: "select private.require_identity()",
};
test("a private RPC must reach an account gate, including through identity helpers", () => {
  const helper = {
    schema: "private",
    name: "require_identity",
    signature: "private.require_identity()",
    source: "perform private.assert_profile_account_active(auth.uid());",
  };
  assert.equal(
    classifyAccountRpc([rpc, helper], rpc).classification,
    "DENY_WHILE_SUSPENDED",
  );
  assert.throws(() => classifyAccountRpc([rpc], rpc), /Account gate missing/u);
});
test("recursive compatibility wrappers cannot prove coverage by themselves", () => {
  const cyclic = { ...rpc, source: "select public.read_private()" };
  assert.throws(
    () => classifyAccountRpc([cyclic], cyclic),
    /Account gate missing/u,
  );
});
test("only the dedicated bootstrap exception is allowlisted", () => {
  assert.equal(
    classifyAccountRpc([], {
      ...rpc,
      name: "get_own_account_suspension_status",
    }).classification,
    "ALLOW_WHILE_SUSPENDED",
  );
  assert.equal(
    classifyAccountRpc([], { ...rpc, anon: true }).classification,
    "PUBLIC/ANONYMOUS_DATA",
  );
  assert.equal(
    classifyAccountRpc([], { ...rpc, auth: false }).classification,
    "SERVICE/WORKER_ONLY",
  );
  assert.throws(
    () => classifyAccountRpc([], { ...rpc, name: "get_own_preferences" }),
    /Account gate missing/u,
  );
});
