import assert from "node:assert/strict";
import test from "node:test";
import {
  demoAdmissionActionId,
  demoRpc,
} from "./demo-participant-invitations.mjs";

test("seed admission identity binds account, Project, generation and deliberate episode", () => {
  const parts = ["project-a", "account-a", "generation-a", "first-leave"];
  const action = demoAdmissionActionId(...parts);
  assert.match(
    action,
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-8[0-9a-f]{3}-[0-9a-f]{12}$/u,
  );
  assert.equal(demoAdmissionActionId(...parts), action);
  for (let i = 0; i < parts.length; i++) {
    const changed = [...parts];
    changed[i] += "-changed";
    assert.notEqual(demoAdmissionActionId(...changed), action);
  }
  assert.notEqual(
    demoAdmissionActionId("a:b", "c", "d", "e"),
    demoAdmissionActionId("a", "b:c", "d", "e"),
  );
  assert.throws(
    () => demoAdmissionActionId("a", "b", "c", ""),
    /explicit step/u,
  );
});

test("demo RPC errors cannot echo a capability or provider request detail", async () => {
  const user = {
    client: {
      rpc: async () => ({
        error: { code: "PT409", message: "private-token /join/project/secret" },
      }),
    },
  };
  await assert.rejects(
    demoRpc(user, "accept_project_participant_invitation", {}),
    {
      message:
        "Demo accept_project_participant_invitation failed (code PT409).",
    },
  );
});
